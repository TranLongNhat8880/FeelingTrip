-- Existing accounts remain NULL: do not invent historical consent.
ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_version VARCHAR(32);
ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ;
