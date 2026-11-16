CREATE TABLE IF NOT EXISTS venues (
  id TEXT PRIMARY KEY,
  conference_id TEXT NOT NULL REFERENCES conferences(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  building TEXT NOT NULL DEFAULT '',
  room TEXT NOT NULL DEFAULT '',
  capacity INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_venues_conference ON venues(conference_id);
