-- Shared Trips contract: retained memberships and named invitations.
-- No expiry policy, schedule restrictions, or lifecycle triggers are imposed.
-- The migration runner executes this file and its ledger entry in one transaction.
SET LOCAL lock_timeout = '10s';

ALTER TABLE trip_members
  ADD COLUMN IF NOT EXISTS membership_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS removed_by UUID REFERENCES users(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'trip_members'::regclass
      AND conname = 'trip_members_membership_status_check'
  ) THEN
    ALTER TABLE trip_members ADD CONSTRAINT trip_members_membership_status_check
      CHECK (membership_status IN ('ACTIVE', 'LEFT', 'REMOVED'));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_trip_members_trip_status
  ON trip_members(trip_id, membership_status);

CREATE TABLE IF NOT EXISTS trip_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES users(id),
  invitee_id UUID NOT NULL REFERENCES users(id),
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
    CONSTRAINT trip_invitations_status_check
    CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'REVOKED', 'EXPIRED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  CONSTRAINT trip_invitations_not_self_check CHECK (inviter_id <> invitee_id),
  CONSTRAINT trip_invitations_expiry_check
    CHECK (expires_at IS NULL OR expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS idx_trip_invitations_invitee_status
  ON trip_invitations(invitee_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trip_invitations_trip_status
  ON trip_invitations(trip_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_invitations_one_pending
  ON trip_invitations(trip_id, invitee_id) WHERE status = 'PENDING';

-- Access is through the backend's authenticated API, not public Supabase REST.
-- Owner/backend connections still need the service's user and trip permission checks.
ALTER TABLE trip_invitations ENABLE ROW LEVEL SECURITY;
