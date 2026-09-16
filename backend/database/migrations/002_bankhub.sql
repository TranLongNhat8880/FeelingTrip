CREATE TABLE IF NOT EXISTS bankhub_companies (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  company_xid UUID NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS bankhub_links (
  xid UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS bankhub_accounts (
  xid UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bank_bin VARCHAR(6) NOT NULL,
  brand_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_holder_name TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  event_timestamp BIGINT NOT NULL DEFAULT 0,
  UNIQUE (bank_bin, account_number)
);
CREATE INDEX IF NOT EXISTS bankhub_accounts_user ON bankhub_accounts(user_id);
CREATE TABLE IF NOT EXISTS bankhub_events (
  xid UUID PRIMARY KEY,
  payload JSONB NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  retry_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  attempts INTEGER NOT NULL DEFAULT 0
);
-- Persist every authenticated payment notification before applying it. Failures can
-- be replayed locally: Bank Hub does not promise to retry HTTP error responses.
CREATE TABLE IF NOT EXISTS bankhub_ipn (
  transaction_id TEXT PRIMARY KEY,
  payload JSONB NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  result TEXT,
  retry_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  attempts INTEGER NOT NULL DEFAULT 0
);
