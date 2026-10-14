-- Record free activities as actual expenses without creating zero-value settlements.
-- Existing expenses and splits remain unchanged.
SET LOCAL lock_timeout = '10s';
ALTER TABLE expenses DROP CONSTRAINT IF EXISTS expenses_amount_check;
ALTER TABLE expenses ADD CONSTRAINT expenses_amount_check CHECK (amount >= 0);
