ALTER TABLE sessions ADD COLUMN capacity INTEGER;

CREATE INDEX IF NOT EXISTS idx_sessions_capacity ON sessions(capacity);
