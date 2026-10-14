-- One current invitation per trip. Keep consumed codes for inspection until replaced.
ALTER TABLE trips ADD COLUMN IF NOT EXISTS invite_code_status VARCHAR(10);

UPDATE trips SET invite_code_status = CASE WHEN invite_code IS NULL THEN 'NONE' ELSE 'ACTIVE' END
WHERE invite_code_status IS NULL;

ALTER TABLE trips ALTER COLUMN invite_code_status SET DEFAULT 'NONE';
ALTER TABLE trips ALTER COLUMN invite_code_status SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'trips'::regclass AND conname = 'trips_invite_code_state_check'
  ) THEN
    ALTER TABLE trips ADD CONSTRAINT trips_invite_code_state_check CHECK (
      (invite_code IS NULL AND invite_code_status = 'NONE') OR
      (invite_code IS NOT NULL AND invite_code_status IN ('ACTIVE', 'USED', 'REVOKED'))
    );
  END IF;
END $$;

-- Compatibility with existing writers that only set invite_code:
-- a newly issued/replaced code is ACTIVE; clearing a code resets its state.
CREATE OR REPLACE FUNCTION sync_trip_invite_code_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.invite_code IS NULL THEN
    NEW.invite_code_status := 'NONE';
  ELSIF TG_OP = 'INSERT' THEN
    NEW.invite_code_status := 'ACTIVE';
  ELSIF NEW.invite_code IS DISTINCT FROM OLD.invite_code THEN
    NEW.invite_code_status := 'ACTIVE';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trips_sync_invite_code_status ON trips;
CREATE TRIGGER trips_sync_invite_code_status
BEFORE INSERT OR UPDATE OF invite_code, invite_code_status ON trips
FOR EACH ROW EXECUTE FUNCTION sync_trip_invite_code_status();
