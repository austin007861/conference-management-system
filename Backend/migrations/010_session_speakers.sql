CREATE TABLE IF NOT EXISTS session_speakers (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  speaker_id TEXT NOT NULL REFERENCES speakers(id) ON DELETE CASCADE,
  speaker_role TEXT NOT NULL DEFAULT 'speaker'
    CHECK (speaker_role IN ('keynote', 'speaker', 'panelist', 'moderator')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (session_id, speaker_id)
);

CREATE INDEX IF NOT EXISTS idx_session_speakers_session ON session_speakers(session_id);
CREATE INDEX IF NOT EXISTS idx_session_speakers_speaker ON session_speakers(speaker_id);
