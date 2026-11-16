CREATE TABLE IF NOT EXISTS conference_attendees (
  id TEXT PRIMARY KEY,
  attendee_id TEXT NOT NULL REFERENCES attendees(id) ON DELETE CASCADE,
  conference_id TEXT NOT NULL REFERENCES conferences(id) ON DELETE CASCADE,
  registration_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  UNIQUE (attendee_id, conference_id)
);

CREATE INDEX IF NOT EXISTS idx_conference_attendees_attendee ON conference_attendees(attendee_id);
CREATE INDEX IF NOT EXISTS idx_conference_attendees_conference ON conference_attendees(conference_id);
