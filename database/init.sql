-- ===========================================================================
-- Data Tier - Schema for the 3-Tier Notes app
-- Run this AFTER you have created the database and the app user (see README).
-- ===========================================================================

CREATE TABLE IF NOT EXISTS notes (
    id          SERIAL       PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    body        TEXT         NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes (created_at DESC);

-- A couple of sample rows so the UI isn't empty on first load
INSERT INTO notes (title, body) VALUES
    ('Welcome', 'This note is served from PostgreSQL on the Data tier.'),
    ('3-Tier check', 'If you can see this, all three tiers are talking to each other.')
ON CONFLICT DO NOTHING;
