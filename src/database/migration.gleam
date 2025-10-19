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

    CREATE TABLE IF NOT EXISTS posts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      feed_id INTEGER NOT NULL,
      guid TEXT NOT NULL,
      title TEXT NOT NULL,
      link TEXT NOT NULL,
      description TEXT,
      content TEXT,
      published_at TEXT,
      fetched_at TEXT NOT NULL DEFAULT (datetime('now')),

      FOREIGN KEY (feed_id) REFERENCES feeds(id) ON DELETE CASCADE,
      UNIQUE(feed_id, guid)
    );

    CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds(url);
    CREATE INDEX IF NOT EXISTS idx_feeds_added_at ON feeds(added_at);
    CREATE INDEX IF NOT EXISTS idx_posts_feed_id ON posts(feed_id);
    CREATE INDEX IF NOT EXISTS idx_posts_published_at ON posts(published_at);
    CREATE INDEX IF NOT EXISTS idx_posts_guid ON posts(guid);
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
