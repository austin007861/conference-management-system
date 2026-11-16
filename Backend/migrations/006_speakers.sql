CREATE TABLE IF NOT EXISTS speakers (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  bio TEXT NOT NULL DEFAULT '',
  photo_url TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_speakers_user ON speakers(user_id);
