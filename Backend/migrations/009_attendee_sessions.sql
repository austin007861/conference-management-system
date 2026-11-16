CREATE TABLE IF NOT EXISTS attendee_sessions (
  id TEXT PRIMARY KEY,
  attendee_id TEXT NOT NULL REFERENCES attendees(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  registered_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  checked_in_at TEXT,
  status TEXT NOT NULL DEFAULT 'registered'
    CHECK (status IN ('registered', 'attended', 'cancelled', 'no_show')),
  UNIQUE (attendee_id, session_id)
);

CREATE INDEX IF NOT EXISTS idx_attendee_sessions_attendee ON attendee_sessions(attendee_id);
CREATE INDEX IF NOT EXISTS idx_attendee_sessions_session ON attendee_sessions(session_id);
