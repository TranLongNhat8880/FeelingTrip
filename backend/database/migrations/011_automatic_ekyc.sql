-- No existing user data or verification decisions are changed.
CREATE TABLE IF NOT EXISTS ekyc_sessions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  actions JSONB NOT NULL CHECK (jsonb_typeof(actions) = 'array'),
  status VARCHAR(20) NOT NULL DEFAULT 'CREATED'
    CHECK (status IN ('CREATED', 'PROCESSING', 'VERIFIED', 'FAILED', 'ERROR')),
  result JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '5 minutes',
  consumed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_ekyc_sessions_user_created ON ekyc_sessions(user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ekyc_sessions_processing ON ekyc_sessions(user_id) WHERE status = 'PROCESSING';
-- The backend connects with a privileged server role. No client policies.
ALTER TABLE ekyc_sessions ENABLE ROW LEVEL SECURITY;
