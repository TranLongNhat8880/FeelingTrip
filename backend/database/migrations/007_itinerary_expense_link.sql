-- Link an activity's estimate to its actual shared expense without changing old data.
SET LOCAL lock_timeout = '10s';
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS itinerary_item_id UUID
  REFERENCES itinerary_items(id) ON DELETE SET NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_itinerary_item
  ON expenses(itinerary_item_id) WHERE itinerary_item_id IS NOT NULL;
