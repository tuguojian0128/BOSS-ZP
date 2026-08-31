import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// 本地开发数据库。
///
/// 生产部署时可把同一套迁移转换到 PostgreSQL；业务层不直接依赖 SQL 文件。
class AppDatabase {
  AppDatabase({String? path}) {
    final databasePath =
        path ?? Platform.environment['APP_DATABASE_PATH'] ?? 'data/boss.db';
    final file = File(databasePath);
    file.parent.createSync(recursive: true);
    db = sqlite3.open(databasePath);
    _migrate();
  }

  late final Database db;

  void _migrate() {
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL
      );
    ''');
    final applied = db.select(
        'SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1');
    final version = applied.isEmpty ? 0 : (applied.first['version'] as int);
    if (version < 1) {
      db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          phone TEXT UNIQUE,
          email TEXT UNIQUE,
          display_name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        CREATE TABLE resumes (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          file_name TEXT NOT NULL,
          object_key TEXT,
          parse_status TEXT NOT NULL,
          completeness INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        CREATE TABLE resume_profiles (
          resume_id TEXT PRIMARY KEY REFERENCES resumes(id) ON DELETE CASCADE,
          payload_json TEXT NOT NULL,
          version INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        CREATE TABLE platform_accounts (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          platform TEXT NOT NULL,
          external_user_id TEXT,
          display_name TEXT,
          access_token_encrypted TEXT,
          refresh_token_encrypted TEXT,
          expires_at TEXT,
          status TEXT NOT NULL DEFAULT 'disconnected',
          last_synced_at TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(user_id, platform)
        );
        CREATE TABLE jobs (
          id TEXT PRIMARY KEY,
          platform TEXT NOT NULL,
          external_job_id TEXT,
          title TEXT NOT NULL,
          company TEXT NOT NULL,
          location TEXT,
          salary TEXT,
          match_score INTEGER,
          payload_json TEXT NOT NULL,
          first_seen_at TEXT NOT NULL,
          last_seen_at TEXT NOT NULL,
          UNIQUE(platform, external_job_id)
        );
        CREATE TABLE application_tasks (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          resume_id TEXT NOT NULL REFERENCES resumes(id),
          status TEXT NOT NULL,
          total INTEGER NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0,
          failed INTEGER NOT NULL DEFAULT 0,
          message TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        CREATE TABLE application_records (
          id TEXT PRIMARY KEY,
          task_id TEXT REFERENCES application_tasks(id) ON DELETE SET NULL,
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          job_id TEXT NOT NULL REFERENCES jobs(id),
          resume_id TEXT NOT NULL REFERENCES resumes(id),
          platform TEXT NOT NULL,
          status TEXT NOT NULL,
          external_application_id TEXT,
          failure_reason TEXT,
          submitted_at TEXT,
          viewed_at TEXT,
          replied_at TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        CREATE TABLE daily_application_stats (
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          stat_date TEXT NOT NULL,
          platform TEXT NOT NULL,
          submitted_count INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY(user_id, stat_date, platform)
        );
        CREATE TABLE audit_logs (
          id TEXT PRIMARY KEY,
          user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
          action TEXT NOT NULL,
          resource_type TEXT NOT NULL,
          resource_id TEXT,
          metadata_json TEXT,
          created_at TEXT NOT NULL
        );
        CREATE INDEX idx_jobs_platform_seen ON jobs(platform, last_seen_at);
        CREATE INDEX idx_applications_user_date ON application_records(user_id, submitted_at);
        CREATE INDEX idx_daily_stats_user_date ON daily_application_stats(user_id, stat_date);
      ''');
      db.execute(
          'INSERT INTO schema_migrations(version, applied_at) VALUES (1, ?)',
          [DateTime.now().toIso8601String()]);
    }
    final current = db.select(
        'SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1');
    final currentVersion = current.isEmpty ? 0 : (current.first['version'] as int);
    if (currentVersion < 2) {
      db.execute('ALTER TABLE users ADD COLUMN password_hash TEXT');
      db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT');
      db.execute("ALTER TABLE users ADD COLUMN status TEXT NOT NULL DEFAULT 'active'");
      db.execute('ALTER TABLE users ADD COLUMN last_login_at TEXT');
      db.execute('''
        CREATE TABLE IF NOT EXISTS refresh_tokens (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          token_hash TEXT NOT NULL UNIQUE,
          expires_at TEXT NOT NULL,
          revoked_at TEXT,
          created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user
          ON refresh_tokens(user_id, expires_at);
      ''');
      db.execute(
          'INSERT INTO schema_migrations(version, applied_at) VALUES (2, ?)',
          [DateTime.now().toIso8601String()]);
    }
    final latest = db.select(
        'SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1');
    final latestVersion = latest.isEmpty ? 0 : (latest.first['version'] as int);
    if (latestVersion < 3) {
      db.execute("ALTER TABLE resumes ADD COLUMN content_type TEXT NOT NULL DEFAULT 'application/octet-stream'");
      db.execute("ALTER TABLE application_tasks ADD COLUMN jobs_json TEXT NOT NULL DEFAULT '[]'");
      db.execute(
          'INSERT INTO schema_migrations(version, applied_at) VALUES (3, ?)',
          [DateTime.now().toIso8601String()]);
    }
  }

  void close() => db.dispose();
}
