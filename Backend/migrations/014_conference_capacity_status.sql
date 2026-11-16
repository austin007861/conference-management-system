ALTER TABLE conferences ADD COLUMN capacity INTEGER;

ALTER TABLE conferences ADD COLUMN status TEXT NOT NULL DEFAULT 'upcoming'
    CHECK (status IN ('draft', 'upcoming', 'ongoing', 'completed', 'cancelled'));

CREATE INDEX IF NOT EXISTS idx_conferences_status ON conferences(status);
