import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  /// Cache the *Future*, not the resolved Database. This prevents two
  /// concurrent callers from both calling `openDatabase()` when `_db` is
  /// still null (which is the case while the first open is in progress).
  static Future<Database>? _dbFuture;

  Future<Database> get database {
    _dbFuture ??= _init();
    return _dbFuture!;
  }

  Future<Database> _init() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'alight_creators.db');

    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        user_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name     TEXT,
        username      TEXT NOT NULL UNIQUE,
        email         TEXT NOT NULL UNIQUE,
        password      TEXT NOT NULL,
        bio           TEXT,
        avatar_path   TEXT,
        banner_path   TEXT,
        gender        TEXT,
        gender_custom TEXT,
        birthdate     TEXT,
        role          TEXT DEFAULT 'user',
        created_at    TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tutorials (
        tutorial_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id           INTEGER,
        title             TEXT NOT NULL,
        description       TEXT,
        category          TEXT NOT NULL,
        thumbnail_path    TEXT,
        guide_video_url   TEXT,
        guide_video_file  TEXT,
        result_video_url  TEXT,
        result_video_file TEXT,
        views             INTEGER NOT NULL DEFAULT 0,
        created_at        TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tutorial_steps (
        step_id          INTEGER PRIMARY KEY AUTOINCREMENT,
        tutorial_id      INTEGER NOT NULL,
        step_number      INTEGER NOT NULL,
        step_title       TEXT NOT NULL,
        step_description TEXT NOT NULL,
        FOREIGN KEY (tutorial_id) REFERENCES tutorials(tutorial_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tutorial_resources (
        resource_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        tutorial_id    INTEGER NOT NULL,
        resource_type  TEXT NOT NULL,
        resource_name  TEXT NOT NULL,
        resource_url   TEXT NOT NULL,
        FOREIGN KEY (tutorial_id) REFERENCES tutorials(tutorial_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tutorial_views (
        view_id     INTEGER PRIMARY KEY AUTOINCREMENT,
        tutorial_id INTEGER NOT NULL,
        user_id     INTEGER NOT NULL,
        viewed_at   TEXT,
        UNIQUE (tutorial_id, user_id),
        FOREIGN KEY (tutorial_id) REFERENCES tutorials(tutorial_id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tutorial_ratings (
        rating_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        tutorial_id     INTEGER NOT NULL,
        user_id         INTEGER NOT NULL,
        quality_rating  INTEGER NOT NULL,
        clarity_rating  INTEGER NOT NULL,
        updated_at      TEXT,
        UNIQUE (tutorial_id, user_id),
        FOREIGN KEY (tutorial_id) REFERENCES tutorials(tutorial_id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_loves (
        love_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        lover_id   INTEGER NOT NULL,
        loved_id   INTEGER NOT NULL,
        created_at TEXT,
        UNIQUE (lover_id, loved_id),
        FOREIGN KEY (lover_id) REFERENCES users(user_id) ON DELETE CASCADE,
        FOREIGN KEY (loved_id) REFERENCES users(user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE contact_messages (
        message_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        email      TEXT NOT NULL,
        message    TEXT NOT NULL,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE password_resets (
        reset_id   INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        token_hash TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        used_at    TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      for (final col in [
        ['avatar_path', 'TEXT'],
        ['banner_path', 'TEXT'],
        ['gender_custom', 'TEXT'],
        ['role', "TEXT DEFAULT 'user'"],
        ['created_at', 'TEXT'],
      ]) {
        try {
          await db.execute('ALTER TABLE users ADD COLUMN ${col[0]} ${col[1]}');
        } catch (_) {}
      }

      for (final col in [
        ['thumbnail_path', 'TEXT'],
        ['guide_video_url', 'TEXT'],
        ['guide_video_file', 'TEXT'],
        ['result_video_url', 'TEXT'],
        ['result_video_file', 'TEXT'],
        ['created_at', 'TEXT'],
      ]) {
        try {
          await db.execute('ALTER TABLE tutorials ADD COLUMN ${col[0]} ${col[1]}');
        } catch (_) {}
      }
    }

    if (oldV < 3) {
      await _rebuildTable(
        db,
        name: 'tutorial_views',
        createSql: '''
          CREATE TABLE tutorial_views (
            view_id     INTEGER PRIMARY KEY AUTOINCREMENT,
            tutorial_id INTEGER NOT NULL,
            user_id     INTEGER NOT NULL,
            viewed_at   TEXT,
            UNIQUE (tutorial_id, user_id),
            FOREIGN KEY (tutorial_id) REFERENCES tutorials(tutorial_id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
          )
        ''',
      );

      await _rebuildTable(
        db,
        name: 'tutorial_ratings',
        createSql: '''
          CREATE TABLE tutorial_ratings (
            rating_id       INTEGER PRIMARY KEY AUTOINCREMENT,
            tutorial_id     INTEGER NOT NULL,
            user_id         INTEGER NOT NULL,
            quality_rating  INTEGER NOT NULL,
            clarity_rating  INTEGER NOT NULL,
            updated_at      TEXT,
            UNIQUE (tutorial_id, user_id),
            FOREIGN KEY (tutorial_id) REFERENCES tutorials(tutorial_id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
          )
        ''',
      );

      await _rebuildTable(
        db,
        name: 'user_loves',
        createSql: '''
          CREATE TABLE user_loves (
            love_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            lover_id   INTEGER NOT NULL,
            loved_id   INTEGER NOT NULL,
            created_at TEXT,
            UNIQUE (lover_id, loved_id),
            FOREIGN KEY (lover_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (loved_id) REFERENCES users(user_id) ON DELETE CASCADE
          )
        ''',
      );

      await _ensureTable(db, 'contact_messages', '''
        CREATE TABLE IF NOT EXISTS contact_messages (
          message_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT NOT NULL,
          email      TEXT NOT NULL,
          message    TEXT NOT NULL,
          created_at TEXT
        )
      ''');

      await _rebuildTable(
        db,
        name: 'password_resets',
        createSql: '''
          CREATE TABLE password_resets (
            reset_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id    INTEGER NOT NULL,
            token_hash TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            used_at    TEXT,
            created_at TEXT,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
          )
        ''',
      );
    }
  }

  Future<void> _rebuildTable(
    Database db, {
    required String name,
    required String createSql,
  }) async {
    final existing = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [name],
    );
    if (existing.isEmpty) {
      await db.execute(createSql);
      return;
    }

    final tmpName = '${name}__tmp_rebuild';
    await db.execute(
      createSql.replaceFirst('CREATE TABLE $name',
          'CREATE TABLE $tmpName'),
    );
    final cols = await db.rawQuery('PRAGMA table_info($name)');
    final colNames = cols.map((r) => r['name'] as String).toList().join(', ');
    await db.execute(
      'INSERT INTO $tmpName ($colNames) SELECT $colNames FROM $name',
    );
    await db.execute('DROP TABLE $name');
    await db.execute('ALTER TABLE $tmpName RENAME TO $name');
  }

  Future<void> _ensureTable(Database db, String name, String sql) async {
    final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", [name]);
    if (rows.isEmpty) await db.execute(sql);
  }
}