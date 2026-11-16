CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  conference_id TEXT NOT NULL REFERENCES conferences(id) ON DELETE CASCADE,
  venue_id TEXT REFERENCES venues(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_conference ON sessions(conference_id);
CREATE INDEX IF NOT EXISTS idx_sessions_venue ON sessions(venue_id);
