-- Shared storage for users/admin eKYC, places, reviews and SOS.
-- Apply with npm run db:migrate; its transaction rolls back on any failure.
-- Feature owners wire validation, permissions, API mapping and state transitions.
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_rejection_reason VARCHAR(500);
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE sos_alerts ADD COLUMN IF NOT EXISTS message VARCHAR(500);
ALTER TABLE user_reports ADD COLUMN IF NOT EXISTS evidence_image_url TEXT;

ALTER TABLE sos_alerts DROP CONSTRAINT IF EXISTS sos_alerts_status_check;
ALTER TABLE sos_alerts ADD CONSTRAINT sos_alerts_status_check
  CHECK (status IN ('ACTIVE', 'RESOLVED', 'FALSE_ALARM'));

-- Block concurrent writes between duplicate inspection and unique-index creation.
LOCK TABLE trip_reviews IN SHARE ROW EXCLUSIVE MODE;
DO $$
DECLARE
  duplicate_trip_groups BIGINT;
  duplicate_member_groups BIGINT;
BEGIN
  SELECT COUNT(*) INTO duplicate_trip_groups FROM (
    SELECT trip_id, reviewer_id FROM trip_reviews WHERE reviewee_id IS NULL
    GROUP BY trip_id, reviewer_id HAVING COUNT(*) > 1
  ) duplicates;
  SELECT COUNT(*) INTO duplicate_member_groups FROM (
    SELECT trip_id, reviewer_id, reviewee_id FROM trip_reviews WHERE reviewee_id IS NOT NULL
    GROUP BY trip_id, reviewer_id, reviewee_id HAVING COUNT(*) > 1
  ) duplicates;
  IF duplicate_trip_groups > 0 OR duplicate_member_groups > 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = '23505',
      MESSAGE = format('004_member_feature_contracts: duplicate review groups (trip=%s, member=%s). No reviews were deleted.',
        duplicate_trip_groups, duplicate_member_groups),
      HINT = 'Inspect trip_reviews grouped by trip_id, reviewer_id, reviewee_id with HAVING COUNT(*) > 1. Resolve duplicates deliberately, then rerun npm run db:migrate.';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_reviews_member_unique
  ON trip_reviews (trip_id, reviewer_id, reviewee_id) WHERE reviewee_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_reviews_trip_unique
  ON trip_reviews (trip_id, reviewer_id) WHERE reviewee_id IS NULL;
