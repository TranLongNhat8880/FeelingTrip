-- Migration 008: Itinerary item snapshot coordinates and trip destination geocoding
-- Supports CATALOG (from places), GEOAPIFY (from search), and MANUAL (freeform/dropped pins).
SET LOCAL lock_timeout = '10s';

-- 1. Extend itinerary_items table
ALTER TABLE itinerary_items ADD COLUMN IF NOT EXISTS location_source VARCHAR(20) NOT NULL DEFAULT 'MANUAL';
ALTER TABLE itinerary_items ADD COLUMN IF NOT EXISTS external_provider VARCHAR(30);
ALTER TABLE itinerary_items ADD COLUMN IF NOT EXISTS external_place_id VARCHAR(255);
ALTER TABLE itinerary_items ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE itinerary_items ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 2. Backfill existing data: Link catalog places to snapshot coordinates
UPDATE itinerary_items ii
SET
  location_source = 'CATALOG',
  latitude = p.latitude,
  longitude = p.longitude
FROM places p
WHERE ii.place_id = p.id;

-- 3. Add constraints to itinerary_items
ALTER TABLE itinerary_items DROP CONSTRAINT IF EXISTS chk_itinerary_items_location_source;
ALTER TABLE itinerary_items ADD CONSTRAINT chk_itinerary_items_location_source
  CHECK (location_source IN ('CATALOG', 'GEOAPIFY', 'MANUAL'));

ALTER TABLE itinerary_items DROP CONSTRAINT IF EXISTS chk_itinerary_items_latitude_range;
ALTER TABLE itinerary_items ADD CONSTRAINT chk_itinerary_items_latitude_range
  CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90);

ALTER TABLE itinerary_items DROP CONSTRAINT IF EXISTS chk_itinerary_items_longitude_range;
ALTER TABLE itinerary_items ADD CONSTRAINT chk_itinerary_items_longitude_range
  CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);

ALTER TABLE itinerary_items DROP CONSTRAINT IF EXISTS chk_itinerary_items_coordinates_paired;
ALTER TABLE itinerary_items ADD CONSTRAINT chk_itinerary_items_coordinates_paired
  CHECK (
    (latitude IS NULL AND longitude IS NULL)
    OR
    (latitude IS NOT NULL AND longitude IS NOT NULL)
  );

ALTER TABLE itinerary_items DROP CONSTRAINT IF EXISTS chk_itinerary_items_place_id_source;
ALTER TABLE itinerary_items ADD CONSTRAINT chk_itinerary_items_place_id_source
  CHECK (
    place_id IS NULL
    OR location_source = 'CATALOG'
  );

ALTER TABLE itinerary_items DROP CONSTRAINT IF EXISTS chk_itinerary_items_geoapify_complete;
ALTER TABLE itinerary_items ADD CONSTRAINT chk_itinerary_items_geoapify_complete
  CHECK (
    location_source <> 'GEOAPIFY'
    OR (
      external_provider = 'GEOAPIFY'
      AND external_place_id IS NOT NULL
      AND latitude IS NOT NULL
      AND longitude IS NOT NULL
    )
  );

-- 4. Extend trips table with destination geocoding
ALTER TABLE trips ADD COLUMN IF NOT EXISTS destination_provider VARCHAR(30);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS destination_external_id VARCHAR(255);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS destination_latitude DOUBLE PRECISION;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS destination_longitude DOUBLE PRECISION;

ALTER TABLE trips DROP CONSTRAINT IF EXISTS chk_trips_destination_coordinates;
ALTER TABLE trips ADD CONSTRAINT chk_trips_destination_coordinates
  CHECK (
    (destination_latitude IS NULL AND destination_longitude IS NULL)
    OR (
      destination_latitude BETWEEN -90 AND 90
      AND destination_longitude BETWEEN -180 AND 180
    )
  );

-- 5. Create index for external place lookups
CREATE INDEX IF NOT EXISTS idx_itinerary_items_external_place
  ON itinerary_items(external_provider, external_place_id)
  WHERE external_place_id IS NOT NULL;
