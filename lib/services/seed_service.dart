import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/seed_data.dart';
import '../utils/password_util.dart';
import 'database_service.dart';
import 'file_service.dart';

class SeedService {
  SeedService._();
  static final SeedService instance = SeedService._();

  Future<void> seedIfEmpty() async {
    final db = await DatabaseService.instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users'),
    );
    if ((count ?? 0) > 0) return;
    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    // ---- Users ----
    for (final u in SeedData.users) {
      final email = u['email'] as String;

      // Prefer a hash copied verbatim from the web database; otherwise
      // bcrypt-hash the plaintext we know about. bcrypt generates its own
      // salt internally, so PasswordUtil.randomHex() is no longer needed.
      final preHashed = SeedData.preHashedPasswords[email];
      final password = preHashed ??
          PasswordUtil.hash(SeedData.plainPasswords[email] ?? 'password123');

      await db.insert('users', {
        'full_name': u['full_name'],
        'username': u['username'],
        'email': email,
        'password': password,
        'bio': u['bio'],
        'avatar_path': u['avatar_path'],
        'banner_path': u['banner_path'],
        'gender': u['gender'],
        'gender_custom': u['gender_custom'],
        'birthdate': u['birthdate'],
        'role': u['role'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // ---- Tutorials + steps ----
    for (final t in SeedData.tutorials) {
      final tutId = await db.insert('tutorials', {
        'user_id': t['user_id'],
        'title': t['title'],
        'description': t['description'],
        'category': t['category'],
        'thumbnail_path': t['thumbnail_path'],
        'guide_video_url': t['guide_video_url'],
        'guide_video_file': t['guide_video_file'],
        'result_video_url': t['result_video_url'],
        'result_video_file': t['result_video_file'],
        'views': t['views'] ?? 0,
        'created_at': t['created_at'] ?? DateTime.now().toIso8601String(),
      });

      final steps = (t['steps'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < steps.length; i++) {
        await db.insert('tutorial_steps', {
          'tutorial_id': tutId,
          'step_number': i + 1,
          'step_title': steps[i]['title'],
          'step_description': steps[i]['desc'],
        });
      }

      // ---- Copy thumbnail into app documents (WebP) ----
      final thumb = t['thumbnail_path'] as String?;
      if (thumb != null && thumb.isNotEmpty) {
        final fileName = thumb.split('/').last;
        try {
          await FileService.instance.copySeedAsset(
            assetPath: 'assets/seed/thumbnails/keep/$fileName',
            relativeDest: thumb,
          );
        } catch (e) {
          debugPrint('[Seed] thumbnail copy failed for $fileName: $e');
        }
      }

      // ---- Copy guide video (if file-based) ----
      final guideFile = t['guide_video_file'] as String?;
      if (guideFile != null && guideFile.isNotEmpty) {
        final fileName = guideFile.split('/').last;
        try {
          await FileService.instance.copySeedAsset(
            assetPath: 'assets/seed/videos/$fileName',
            relativeDest: guideFile,
          );
        } catch (e) {
          debugPrint('[Seed] guide video copy failed for $fileName: $e');
        }
      }

      // ---- Copy result video (if file-based) ----
      final resultFile = t['result_video_file'] as String?;
      if (resultFile != null && resultFile.isNotEmpty) {
        final fileName = resultFile.split('/').last;
        try {
          await FileService.instance.copySeedAsset(
            assetPath: 'assets/seed/videos/$fileName',
            relativeDest: resultFile,
          );
        } catch (e) {
          debugPrint('[Seed] result video copy failed for $fileName: $e');
        }
      }
    }

    // ---- Ratings ----
    final now = DateTime.now().toIso8601String();
    for (final r in SeedData.ratings) {
      await db.insert('tutorial_ratings', {
        'tutorial_id': r[0],
        'user_id': r[1],
        'quality_rating': r[2],
        'clarity_rating': r[3],
        'updated_at': now,
      });
    }

    // ---- Views ----
    for (final v in SeedData.views) {
      await db.insert('tutorial_views', {
        'tutorial_id': v[0],
        'user_id': v[1],
        'viewed_at': now,
      });
    }

    // ---- Loves ----
    for (final l in SeedData.loves) {
      await db.insert('user_loves', {
        'lover_id': l[0],
        'loved_id': l[1],
        'created_at': now,
      });
    }
  }
}