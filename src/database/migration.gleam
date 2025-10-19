import gleam/io
import gleam/string
import sqlight.{type Connection}

pub fn run(db: Connection) {
  let sql =
    "
    CREATE TABLE IF NOT EXISTS feeds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      description TEXT,
      added_at TEXT NOT NULL DEFAULT (datetime('now')),
      last_checked TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,

      CHECK (is_active IN (0, 1))
    );

    CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds(url);
    CREATE INDEX IF NOT EXISTS idx_feeds_added_at ON feeds(added_at);
    "

  case sqlight.exec(sql, db) {
    Ok(_) -> {
      io.println("Database migration completed successfully")
      Nil
    }
    Error(e) -> {
      io.println("Migration failed: " <> string.inspect(e))
      panic as "Failed to run migration"
    }
  }
}
