-- Run via npm run db:migrate on an existing database. No application data is deleted.
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS auth_otps (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose TEXT NOT NULL CHECK (purpose IN ('VERIFY_EMAIL','FORGOT_PASSWORD')),
  otp_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  PRIMARY KEY (user_id, purpose)
);
CREATE TABLE IF NOT EXISTS request_limits (
  key TEXT PRIMARY KEY, hits INTEGER NOT NULL, expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_request_limits_expiry ON request_limits(expires_at);
CREATE OR REPLACE FUNCTION revoke_tokens_on_status_change() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN NEW.token_version := OLD.token_version + 1; END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_users_revoke_tokens ON users;
CREATE TRIGGER trg_users_revoke_tokens BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION revoke_tokens_on_status_change();

ALTER TABLE settlements DROP CONSTRAINT IF EXISTS settlements_status_check;
ALTER TABLE settlements ADD CONSTRAINT settlements_status_check
  CHECK (status IN ('PENDING','REPORTED','PAID','CANCELLED'));
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS reported_at TIMESTAMPTZ;
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS bank_bin VARCHAR(20);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(50);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS bank_account_name VARCHAR(100);
UPDATE settlements s SET bank_bin = u.bank_bin, bank_account_number = u.bank_account_number,
  bank_account_name = u.bank_account_name
  FROM users u WHERE u.id = s.to_user_id AND s.bank_bin IS NULL AND s.bank_account_number IS NULL;
CREATE TABLE IF NOT EXISTS sepay_events (
  transaction_id TEXT PRIMARY KEY,
  settlement_id UUID NOT NULL REFERENCES settlements(id),
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE places DROP CONSTRAINT IF EXISTS places_category_check;
ALTER TABLE places ADD CONSTRAINT places_category_check CHECK (category IN (
  'ATTRACTION','RESTAURANT','CAFE','HOTEL','ENTERTAINMENT','NATURE','CULTURE','SHOPPING','OTHER'
));

-- Shared storage contract for Thanh's reviews/SOS feature; routes stay with its owner.
CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);
CREATE TABLE IF NOT EXISTS emergency_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  full_name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  relationship VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS sos_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
  latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','RESOLVED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON emergency_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_sos_alerts_user ON sos_alerts(user_id);

ALTER TABLE itinerary_items ADD COLUMN IF NOT EXISTS category VARCHAR(50) NOT NULL DEFAULT 'OTHER';

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email));
