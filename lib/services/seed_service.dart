import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/seed_data.dart';
import '../utils/password_util.dart';
import 'database_service.dart';
import 'file_service.dart';

/// What the last seed run could not find on disk. Surfaced in debug logs (and
/// queryable from the admin screen) so a checkout without the large seed media
/// reads as "assets not bundled" rather than "the app is broken".
class SeedReport {
  SeedReport();
  final List<String> missingAssets = [];
  int tutorials = 0;
  int users = 0;
  bool skipped = false;

  bool get hasProblems => missingAssets.isNotEmpty;

  @override
  String toString() => skipped
      ? 'Seed skipped (disabled or already populated)'
      : '$users users, $tutorials tutorials, '
          '${missingAssets.length} missing asset(s)';
}

/// Seeds the demo content mirrored from the web app's MySQL export.
///
/// DEMO CONTENT IS OFF BY DEFAULT. `SeedData.enabled == false` short-circuits
/// `seedIfEmpty()` before any filesystem or DB work, so a fresh install starts
/// with exactly the accounts in `SeedData.users` (currently one admin) and zero
/// tutorials — everything else is created through the Add Post screen. Flip the
/// flag back to `true` to restore the whole catalogue.
///
/// FIXES vs. the previous version:
///  1. **Gate could never settle.** It bailed out only when *both* `users` and
///     `tutorials` were non-empty, so an install that intentionally has accounts
///     but no tutorials — exactly the shape of this build — re-ran the entire
///     seeder on every single launch. It also had the mirror-image bug in the
///     original: a half-finished seed left the DB permanently short, because
///     "users exist" was treated as "already seeded". Both readings are now
///     explicit: empty seed data is a terminal state, a partial seed is repairable.
///  2. **Atomicity.** Every insert ran on the bare database, so a throw on
///     tutorial 7 of 11 left 6 behind and — worse — recorded a state where the
///     gate then said "already seeded".
///  3. **Dangling media.** Rows were written for 30 asset paths while only the
///     4 bundled thumbnails existed, so thumbnails/videos resolved to null and
///     fell back silently. Paths are now only stored when the asset actually
///     landed (or is already on disk from a previous run).
///  4. **Id assumptions.** `ratings`/`views`/`loves` referenced `user_id` 1..5
///     and `tutorial_id` 1..11 positionally. Any `AUTOINCREMENT` drift (a deleted
///     demo row, a re-seed after `clearAllData` without resetting
///     `sqlite_sequence`) pointed those rows at the wrong account. Ids are now
///     resolved from what was actually inserted.
///  5. **Duplicate views.** `tutorial_views` has `UNIQUE(tutorial_id, user_id)`
///     and the export contains repeated pairs; the unguarded insert aborted the
///     whole run on the first repeat (this is what made #2 bite).
///
/// `lastReport` exposes what was skipped and which files were missing, so a
/// checkout without the large seed media reads as "assets not bundled" rather
/// than "the app is broken".
class SeedService {
  SeedService._();
  static final SeedService instance = SeedService._();

  SeedReport? _lastReport;
  SeedReport? get lastReport => _lastReport;

  /// relativeDest → the file is present in the app documents dir.
  Set<String> _staged = const {};

  /// email → real row id (seed users are referenced by list position).
  final Map<String, int> _userIdByEmail = {};

  /// 1-based position in `SeedData.tutorials` → real row id. Keyed by int?
  /// because a malformed seed row can yield a null index, and `Map<int,int>`'s
  /// `[]` would then be a compile error rather than a lookup miss.
  final Map<int?, int> _tutorialIdBySeedIndex = {};

  Future<void> seedIfEmpty() async {
    // Nothing to seed: skip before touching the DB or the asset bundle, so a
    // user-only install is never re-processed on every launch.
    if (!SeedData.enabled ||
        (SeedData.users.isEmpty && SeedData.tutorials.isEmpty)) {
      _lastReport = SeedReport()..skipped = true;
      return;
    }

    final db = await DatabaseService.instance.database;

    final userCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;
    final tutorialCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tutorials'),
        ) ??
        0;
    if (userCount > 0 && tutorialCount > 0) {
      _lastReport = SeedReport()..skipped = true;
      return;
    }

    final report = SeedReport();
    _lastReport = report;

    // Filesystem first: we need to know which assets actually exist before we
    // decide what to write into the DB. Avatar/banner media only matters if the
    // rows can still reference it; a tutorials-less seed has nothing to stage.
    _staged = await _stageAssets(report);

    await db.transaction((txn) async {
      await _seedUsers(txn, report);
      await _seedTutorials(txn, report);
      await _seedEngagement(txn);
    });

    if (report.hasProblems) {
      debugPrint('[Seed] ${report.missingAssets.length} seed asset(s) not '
          'bundled with this build:\n  '
          '${report.missingAssets.take(12).join('\n  ')}');
    }
    debugPrint('[Seed] $report');
  }

  /// Copies every bundled seed asset into the documents dir and returns the
  /// relative paths that are now readable.
  Future<Set<String>> _stageAssets(SeedReport report) async {
    final service = FileService.instance;
    final staged = <String>{};

    // Every seed media reference — users' avatars/banners and tutorials'
    // thumbnail/two videos — is resolved the same way:
    //   'uploads/<kind>/<file>'  ->  'assets/seed/<kind>s/<file>'
    // (thumbnails are the one odd name: they live in `keep/` to mirror the
    // web export's folder). Files are matched by *filename*, so you can drop
    // the real exports straight into the asset folder with their original
    // names and nothing else has to change.
    const assetDirFor = {
      'avatars':     'assets/seed/avatars/',
      'banners':     'assets/seed/banners/',
      'thumbnails':  'assets/seed/thumbnails/keep/',
      'videos':      'assets/seed/videos/',
    };

    Future<void> stage(String? rel) async {
      if (rel == null || rel.isEmpty) return;
      if (staged.contains(rel)) return;
      final parts = rel.split('/');
      // Already on disk from an earlier run? Don't re-copy, and don't report
      // it as missing just because the asset bundle doesn't ship it.
      if (await service.resolveFile(rel) != null) {
        staged.add(rel);
        return;
      }
      // uploads/<kind>/<file> -> assets/seed/<kind>s/... is already plural in
      // the DB path, so map the singular segment back for the lookup.
      final kind = parts.length >= 3 ? parts[1] : '';
      final dir = assetDirFor[kind];
      if (dir == null) {
        report.missingAssets.add(rel);
        return;
      }
      final assetPath = '$dir${parts.last}';
      // `copySeedAsset` returns bool in the current FileService, but the
      // original returned void and did NOT guard `rootBundle.load`, so a missing
      // asset threw straight out of seedIfEmpty() and took the whole boot down.
      // Tolerate both shapes: swallow the throw, then trust the filesystem.
      try {
        await service.copySeedAsset(
            assetPath: assetPath, relativeDest: rel);
      } catch (e) {
        debugPrint('[Seed] copy failed for $assetPath: $e');
      }
      if (await service.resolveFile(rel) != null) {
        staged.add(rel);
      } else {
        report.missingAssets.add(assetPath);
      }
    }

    for (final u in SeedData.users) {
      await stage(u['avatar_path'] as String?);
      await stage(u['banner_path'] as String?);
    }
    for (final t in SeedData.tutorials) {
      await stage(t['thumbnail_path'] as String?);
      await stage(t['guide_video_file'] as String?);
      await stage(t['result_video_file'] as String?);
    }
    return staged;
  }

  Future<void> _seedUsers(Transaction txn, SeedReport report) async {
    for (final u in SeedData.users) {
      final email = (u['email'] as String).trim().toLowerCase();

      // Prefer a hash copied verbatim from the web database; otherwise
      // bcrypt-hash the plaintext we know about. bcrypt generates its own
      // salt internally, so no salt argument is needed.
      final preHashed = SeedData.preHashedPasswords[email];
      final password = preHashed ??
          PasswordUtil.hash(SeedData.plainPasswords[email] ?? 'password123');

      final id = await txn.insert(
        'users',
        {
          'full_name': u['full_name'],
          'username': u['username'],
          'email': email,
          'password': password,
          'bio': u['bio'],
          'avatar_path': _keep(u['avatar_path'] as String?),
          'banner_path': _keep(u['banner_path'] as String?),
          'gender': u['gender'],
          'gender_custom': u['gender_custom'],
          'birthdate': u['birthdate'],
          'role': u['role'],
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (id > 0) {
        _userIdByEmail[email] = id;
        report.users++;
      } else {
        // Handle/email already present (partial seed): look the id up so the
        // engagement rows still resolve to a real account.
        final rows = await txn.query('users',
            where: 'email = ?', whereArgs: [email], limit: 1);
        if (rows.isNotEmpty) {
          _userIdByEmail[email] = rows.first['user_id'] as int;
        }
      }
    }
  }

  Future<void> _seedTutorials(Transaction txn, SeedReport report) async {
    var index = 0;
    for (final t in SeedData.tutorials) {
      index++;
      final authorEmail = _emailAtSeedIndex(t['user_id'] as int?);
      final authorId =
          authorEmail == null ? null : _userIdByEmail[authorEmail];

      final tutId = await txn.insert('tutorials', {
        'user_id': authorId,
        'title': t['title'],
        'description': t['description'],
        'category': t['category'],
        // Only advertise media that is actually on disk.
        'thumbnail_path': _keep(t['thumbnail_path'] as String?),
        'guide_video_url': t['guide_video_url'],
        'guide_video_file': _keep(t['guide_video_file'] as String?),
        'result_video_url': t['result_video_url'],
        'result_video_file': _keep(t['result_video_file'] as String?),
        'views': t['views'] ?? 0,
        // Normalized to ISO so `ORDER BY created_at DESC` compares like with
        // like. The export uses MySQL's `'2026-10-04 03:19:09'` (space
        // separator) while new rows write `'…T…'`, and since `'T' > ' '` two
        // same-day rows sort into the wrong order.
        'created_at': _iso(t['created_at'] as String?),
      });
      _tutorialIdBySeedIndex[index] = tutId;

      final steps = (t['steps'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < steps.length; i++) {
        await txn.insert('tutorial_steps', {
          'tutorial_id': tutId,
          'step_number': i + 1,
          'step_title': steps[i]['title'],
          'step_description': steps[i]['desc'],
        });
      }
      report.tutorials++;
    }
  }

  /// Reads field [i] from a seed row written either as a positional list
  /// (`List<int>`, the web-export shape) or as a named map
  /// (`Map<String, dynamic>`). Accepting both is deliberate: every earlier
  /// version of this file indexed positionally, so *any* seed data written with
  /// keys — or vice-versa — failed to compile rather than failing soft, and a
  /// `[]`-vs-`{}` slip is the single most likely edit to make while restoring
  /// demo content.
  static int? _at(Object? row, int i, String key) {
    if (row is List) return i < row.length ? (row[i] as num?)?.toInt() : null;
    if (row is Map) return (row[key] as num?)?.toInt();
    return null;
  }

  Future<void> _seedEngagement(Transaction txn) async {
    final now = DateTime.now().toIso8601String();
    var inserted = 0;

    // Field order matches the web export: [tutorialIndex, userIndex, quality,
    // clarity] / [tutorialIndex, userIndex] / [loverIndex, lovedIndex]. The
    // named keys are the alternative spelling of the same thing.
    for (final rating in SeedData.ratings) {
      final tutId = _tutorialIdBySeedIndex[_at(rating, 0, 'tutorial_index')];
      final userId = _userIdAtSeedIndex(_at(rating, 1, 'user_index'));
      if (tutId == null || userId == null) continue;
      inserted += await txn.insert(
        'tutorial_ratings',
        {
          'tutorial_id': tutId,
          'user_id': userId,
          'quality_rating': (_at(rating, 2, 'quality') ?? 5).clamp(1, 5),
          'clarity_rating': (_at(rating, 3, 'clarity') ?? 5).clamp(1, 5),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final view in SeedData.views) {
      final tutId = _tutorialIdBySeedIndex[_at(view, 0, 'tutorial_index')];
      final userId = _userIdAtSeedIndex(_at(view, 1, 'user_index'));
      if (tutId == null || userId == null) continue;
      inserted += await txn.insert(
        'tutorial_views',
        {
          'tutorial_id': tutId,
          'user_id': userId,
          'viewed_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final love in SeedData.loves) {
      final loverId = _userIdAtSeedIndex(_at(love, 0, 'lover_index'));
      final lovedId = _userIdAtSeedIndex(_at(love, 1, 'loved_index'));
      if (loverId == null || lovedId == null || loverId == lovedId) continue;
      inserted += await txn.insert(
        'user_loves',
        {
          'lover_id': loverId,
          'loved_id': lovedId,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    if (inserted == 0 && SeedData.ratings.isNotEmpty &&
        SeedData.tutorials.isNotEmpty) {
      debugPrint('[Seed] no engagement rows could be attached — check that '
          'SeedData.users/SeedData.tutorials indices still line up, and that '
          'the row shape matches one of the two accepted spellings.');
    }
  }

  /// Keeps [rel] only if that asset ended up on disk.
  String? _keep(String? rel) {
    if (rel == null || rel.isEmpty) return null;
    return _staged.contains(rel) ? rel : null;
  }

  String? _emailAtSeedIndex(int? index) {
    if (index == null || index < 1 || index > SeedData.users.length) return null;
    return (SeedData.users[index - 1]['email'] as String)
        .trim()
        .toLowerCase();
  }

  int? _userIdAtSeedIndex(int? index) {
    final email = _emailAtSeedIndex(index);
    if (email == null) return null;
    return _userIdByEmail[email];
  }

  static String _iso(String? mysqlFormatted) {
    if (mysqlFormatted == null || mysqlFormatted.isEmpty) {
      return DateTime.now().toIso8601String();
    }
    final parsed = DateTime.tryParse(mysqlFormatted.replaceFirst(' ', 'T'));
    if (parsed == null) return DateTime.now().toIso8601String();
    return parsed.toIso8601String();
  }
}