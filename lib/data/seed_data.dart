/// Seed content for a fresh install.
///
/// THE DEMO TUTORIAL CATALOGUE HAS BEEN REMOVED ON PURPOSE. This app now starts
/// with no tutorials, no steps, no resources and no engagement rows — every post
/// is created in-app through the Add Post screen, which is the path that actually
/// exercises `TutorialService.createTutorial` + `FileService.saveUpload`.
///
/// The class itself (and its field shapes) is kept rather than deleted, because
/// `SeedService` still reads every member and a `SharedPreferences`-free
/// codebase needs one obvious place to switch demo content back on:
///
///   1. set [enabled] to true;
///   2. restore `users` / `tutorials` / `views` / `ratings` / `loves` from the
///      web export (any git history before this change has them verbatim);
///   3. put the matching media in `assets/seed/{thumbnails/keep,videos}/` and
///      re-declare those two folders in `pubspec.yaml` — the filenames referenced
///      by a tutorial row are looked up by name, and `SeedService` drops the
///      column to null when a file is missing (it never stores a dangling path).
///
/// While [enabled] is false, `SeedService.seedIfEmpty()` returns before touching
/// the database or the asset bundle, so there is no per-launch cost and no
/// "missing seed asset" noise in the debug log.
class SeedData {
  /// Master switch for seeding. `false` = user-created content only.
  static const bool enabled = false;

  /// Plaintext passwords for [users], bcrypt-hashed at seed time (cost 10 — the
  /// password itself is never stored, only its hash).
  ///
  /// EMPTY, because there are no seeded accounts: the first administrator now
  /// chooses their own password at runtime in `SetupScreen`. Leaving a demo
  /// credential in here was the point of concern for this repo — it is gone.
  static const Map<String, String> plainPasswords = {};

  /// If an email appears here, the seeder stores this exact bcrypt hash
  /// verbatim instead of hashing the plaintext in [plainPasswords]. Used to
  /// preserve hashes copied from the web database so both apps accept the same
  /// credentials. Empty now that there is no imported content.
  static const Map<String, String> preHashedPasswords = {};

  /// Accounts created on first launch.
  ///
  /// EMPTY ON PURPOSE, in two ways. There is no hardcoded admin row any more —
  /// the first administrator is now created at runtime by `SetupScreen`
  /// (`AuthService.createFirstAdmin`), which is the only path that may set
  /// `role = 'admin'`, and it refuses to run once any account exists. And with
  /// this list empty while `SeedService` is gated off, a fresh install has zero
  /// rows, so `_Bootstrap` shows the setup form on first launch.
  ///
  /// Put rows back here only if you specifically want a *pre-made* admin (e.g.
  /// for a QA build): the seeder's gate re-opens when [enabled] is true and this
  /// list is non-empty, and it will then write the account *before* the setup
  /// screen can appear — so the runtime gate never fires and the password below
  /// is the only credential that works.
  static const List<Map<String, dynamic>> users = [];

  /// Tutorial rows. Kept empty — see the class doc-comment for the restore path.
  ///
  /// Row shape, for reference:
  ///   'user_id'          1-based index into [users] (NOT a raw DB id)
  ///   'title'            <= 282 chars, matching the web form
  ///   'description'
  ///   'category'         'Beginner' | 'Intermediate' | 'Advanced' | 'Tips & Tricks'
  ///   'thumbnail_path'   'uploads/thumbnails/<file>.webp'
  ///   'guide_video_file' 'uploads/videos/<file>.mp4'   (or a URL in 'guide_video_url')
  ///   'result_video_url' / 'result_video_file'
  ///   'views'            int — the counter column on the tutorial row
  ///   'created_at'       'yyyy-MM-dd HH:mm:ss' (MySQL format; `SeedService`
  ///                      converts it to ISO so ORDER BY sorts correctly)
  ///   'steps'            List<Map>{'title','desc'}
  ///   'resources'        List<Map>{'type','name','url'}
  static const List<Map<String, dynamic>> tutorials = [];

  /// `tutorial_ratings` rows: `[tutorialIndex, userIndex, quality, clarity]`.
  /// Indexes are 1-based positions in [tutorials] / [users] — NOT raw DB ids;
  /// `SeedService` resolves them against what was actually inserted. quality
  /// and clarity are clamped to 1..5, and the table's
  /// UNIQUE(tutorial_id, user_id) means a second row for the same pair is
  /// ignored rather than crashing the whole seed run.
  static const List<List<int>> ratings = [];

  /// `tutorial_views` rows: `[tutorialIndex, userIndex]`. Same UNIQUE
  /// constraint as above, so repeated pairs are safe (they were not before).
  static const List<List<int>> views = [];

  /// `user_loves` rows: `[loverIndex, lovedIndex]` — both 1-based positions in
  /// [users]. A row where the two indexes match is dropped by the seeder.
  static const List<List<int>> loves = [];
}