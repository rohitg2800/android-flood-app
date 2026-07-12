-- Module 6: Resource & Relief Management
-- Neon PostgreSQL Schema

CREATE TABLE IF NOT EXISTS relief_camps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  district TEXT,
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  capacity INTEGER NOT NULL DEFAULT 0,
  current_occupancy INTEGER DEFAULT 0,
  has_medical BOOLEAN DEFAULT false,
  has_food BOOLEAN DEFAULT false,
  has_drinking_water BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  contact_phone TEXT,
  managed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  camp_id UUID REFERENCES relief_camps(id) ON DELETE CASCADE,
  resource_type TEXT NOT NULL,
  unit TEXT,
  quantity INTEGER NOT NULL DEFAULT 0,
  min_threshold INTEGER DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS evacuation_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_name TEXT NOT NULL,
  from_area TEXT,
  to_camp_id UUID REFERENCES relief_camps(id) ON DELETE SET NULL,
  route_coordinates JSONB,  -- Array of lat/lng
  distance_km DECIMAL(6,2),
  is_safe BOOLEAN DEFAULT true,
  last_verified TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_camps_active ON relief_camps(is_active);
CREATE INDEX IF NOT EXISTS idx_camps_district ON relief_camps(district);
CREATE INDEX IF NOT EXISTS idx_resources_camp ON resources(camp_id);
