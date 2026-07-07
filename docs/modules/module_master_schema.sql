-- ============================================
-- FLOOD APP DB - MASTER SCHEMA
-- Project: flood-app-db (muddy-sunset-31125820)
-- Generated: 2026-07-07
-- All modules combined
-- ============================================

-- MODULE 2: Users
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  role TEXT CHECK (role IN ('admin','field_agent','citizen')) NOT NULL DEFAULT 'citizen',
  name TEXT,
  phone TEXT,
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- MODULE 3: Alerts
CREATE TABLE IF NOT EXISTS flood_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  severity TEXT CHECK (severity IN ('low','medium','high','critical')) NOT NULL,
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  area_name TEXT,
  state TEXT DEFAULT 'Bihar',
  district TEXT,
  description TEXT,
  issued_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  issued_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON flood_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON flood_alerts(is_active);
CREATE INDEX IF NOT EXISTS idx_alerts_issued_at ON flood_alerts(issued_at DESC);

CREATE TABLE IF NOT EXISTS alert_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  area_name TEXT,
  fcm_token TEXT,
  min_severity TEXT DEFAULT 'medium',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- MODULE 4: Map
CREATE TABLE IF NOT EXISTS flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  risk_level TEXT CHECK (risk_level IN ('safe','low','medium','high','critical')),
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  polygon_coordinates JSONB NOT NULL,
  area_sq_km DECIMAL(10,2),
  affected_population INTEGER DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id TEXT NOT NULL,
  station_name TEXT NOT NULL,
  river_name TEXT,
  location_lat DECIMAL(9,6) NOT NULL,
  location_lng DECIMAL(9,6) NOT NULL,
  level_meters DECIMAL(5,2) NOT NULL,
  danger_level_meters DECIMAL(5,2),
  warning_level_meters DECIMAL(5,2),
  is_above_danger BOOLEAN GENERATED ALWAYS AS (level_meters >= danger_level_meters) STORED,
  recorded_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_water_station ON water_level_readings(station_id);
CREATE INDEX IF NOT EXISTS idx_water_recorded ON water_level_readings(recorded_at DESC);

-- MODULE 5: Incidents
CREATE TABLE IF NOT EXISTS incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  incident_type TEXT CHECK (incident_type IN ('flooding','rescue_needed','infrastructure_damage','medical_emergency','other')),
  status TEXT CHECK (status IN ('open','assigned','in_progress','resolved','closed')) DEFAULT 'open',
  priority TEXT CHECK (priority IN ('low','medium','high','critical')) DEFAULT 'medium',
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  address TEXT,
  district TEXT,
  image_urls JSONB DEFAULT '[]',
  notes TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_assigned ON incidents(assigned_to);
CREATE INDEX IF NOT EXISTS idx_incidents_priority ON incidents(priority);

CREATE TABLE IF NOT EXISTS incident_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID REFERENCES incidents(id) ON DELETE CASCADE,
  changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  old_status TEXT,
  new_status TEXT,
  note TEXT,
  changed_at TIMESTAMPTZ DEFAULT now()
);

-- MODULE 6: Resources
CREATE TABLE IF NOT EXISTS relief_camps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  latitude DECIMAL(9,6) NOT NULL,
  longitude DECIMAL(9,6) NOT NULL,
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  capacity INTEGER NOT NULL DEFAULT 0,
  current_occupancy INTEGER DEFAULT 0,
  available_capacity INTEGER GENERATED ALWAYS AS (capacity - current_occupancy) STORED,
  has_medical BOOLEAN DEFAULT false,
  has_food BOOLEAN DEFAULT true,
  has_water BOOLEAN DEFAULT true,
  has_electricity BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  contact_phone TEXT,
  managed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_camps_district ON relief_camps(district);
CREATE INDEX IF NOT EXISTS idx_camps_active ON relief_camps(is_active);

CREATE TABLE IF NOT EXISTS resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  camp_id UUID REFERENCES relief_camps(id) ON DELETE CASCADE,
  resource_type TEXT CHECK (resource_type IN ('food','water','medicine','clothing','blankets','boats','rescue_equipment','other')),
  quantity INTEGER NOT NULL DEFAULT 0,
  unit TEXT DEFAULT 'units',
  last_updated TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS evacuation_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  from_area TEXT,
  to_camp_id UUID REFERENCES relief_camps(id) ON DELETE SET NULL,
  route_coordinates JSONB,
  distance_km DECIMAL(6,2),
  is_safe BOOLEAN DEFAULT true,
  last_verified TIMESTAMPTZ DEFAULT now()
);

-- MODULE 7: Admin / Audit
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  old_value JSONB,
  new_value JSONB,
  ip_address INET,
  performed_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_performed ON audit_logs(performed_at DESC);

-- ANALYTICS VIEWS
CREATE OR REPLACE VIEW v_active_alerts_by_severity AS
  SELECT severity, COUNT(*) as count
  FROM flood_alerts WHERE is_active = true
  GROUP BY severity;

CREATE OR REPLACE VIEW v_incidents_by_district AS
  SELECT district, status, COUNT(*) as count
  FROM incidents
  WHERE created_at >= NOW() - INTERVAL '30 days'
  GROUP BY district, status
  ORDER BY count DESC;

CREATE OR REPLACE VIEW v_camp_occupancy AS
  SELECT name, district, capacity, current_occupancy, available_capacity,
    ROUND((current_occupancy::DECIMAL / NULLIF(capacity,0)) * 100, 1) AS occupancy_pct
  FROM relief_camps WHERE is_active = true
  ORDER BY occupancy_pct DESC;
