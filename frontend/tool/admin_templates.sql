-- Run once on each environment. Nhat can integrate this into shared migrations.
-- Does not change existing trips/reviews/itineraries tables.
CREATE TABLE IF NOT EXISTS admin_itinerary_templates (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 name VARCHAR(255) NOT NULL,
 destination VARCHAR(100) NOT NULL,
 duration_days INT NOT NULL CHECK (duration_days BETWEEN 1 AND 30),
 estimated_budget NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (estimated_budget>=0),
 description TEXT,
 cover_image_url TEXT,
 days JSONB NOT NULL CHECK (jsonb_typeof(days)='array'),
 is_active BOOLEAN NOT NULL DEFAULT TRUE,
 created_by UUID NOT NULL REFERENCES users(id),
 source_trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS admin_template_uses (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 template_id UUID NOT NULL REFERENCES admin_itinerary_templates(id) ON DELETE RESTRICT,
 trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 UNIQUE(template_id,trip_id)
);
