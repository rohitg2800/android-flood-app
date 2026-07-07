-- ============================================================
-- Flood App — Complete Neon DB Schema
-- Apply to: Neon project `flood-app-db`, branch `main`
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- MODULE 2: Users & Authentication
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK (role IN ('admin','field_agent','citizen')) DEFAULT 'citizen',
  name TEXT,
  phone TEXT,
  fcm_token TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  device_info TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions(user_id);

-- ============================================================
-- MODULE 3: Flood Alerts & Notifications
-- ============================================================
CREATE TABLE IF NOT EXISTS flood_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  severity TEXT CHECK (severity IN ('low','medium','high','critical')),
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  area_name TEXT,
  description TEXT,
  issued_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  issued_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  affected_population INTEGER,
  source TEXT
);

CREATE TABLE IF NOT EXISTS alert_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id UUID REFERENCES flood_alerts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  sent_at TIMESTAMPTZ DEFAULT now(),
  read_at TIMESTAMPTZ,
  delivery_status TEXT CHECK (delivery_status IN ('sent','delivered','failed'))
);

CREATE INDEX IF NOT EXISTS idx_alerts_severity ON flood_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON flood_alerts(is_active, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_location ON flood_alerts(location_lat, location_lng);

-- ============================================================
-- MODULE 4: Flood Map & Water Levels
-- ============================================================
CREATE TABLE IF NOT EXISTS flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  risk_level TEXT CHECK (risk_level IN ('safe','watch','warning','danger')),
  polygon_coordinates JSONB NOT NULL,
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  population_at_risk INTEGER,
  last_updated TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS water_level_stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_name TEXT NOT NULL,
  river_name TEXT,
  location_lat DECIMAL(9,6) NOT NULL,
  location_lng DECIMAL(9,6) NOT NULL,
  danger_level_meters DECIMAL(5,2),
  warning_level_meters DECIMAL(5,2),
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id UUID REFERENCES water_level_stations(id),
  level_meters DECIMAL(5,2) NOT NULL,
  trend TEXT CHECK (trend IN ('rising','falling','stable')),
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_readings_station_time ON water_level_readings(station_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_zones_risk ON flood_zones(risk_level);

-- ============================================================
-- MODULE 5: Incidents
-- ============================================================
CREATE TABLE IF NOT EXISTS incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by UUID REFERENCES users(id),
  assigned_to UUID REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  category TEXT CHECK (category IN ('flood','landslide','infrastructure','medical','rescue')),
  status TEXT CHECK (status IN ('open','assigned','in_progress','resolved','closed')),
  priority TEXT CHECK (priority IN ('low','medium','high','critical')) DEFAULT 'medium',
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  address TEXT,
  image_urls JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS incident_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID REFERENCES incidents(id) ON DELETE CASCADE,
  updated_by UUID REFERENCES users(id),
  old_status TEXT,
  new_status TEXT,
  note TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_incidents_assigned ON incidents(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_incidents_location ON incidents(latitude, longitude);

-- ============================================================
-- MODULE 6: Relief Camps & Resources
-- ============================================================
CREATE TABLE IF NOT EXISTS relief_camps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  district TEXT,
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  capacity INTEGER NOT NULL,
  current_occupancy INTEGER DEFAULT 0,
  has_medical BOOLEAN DEFAULT false,
  has_food BOOLEAN DEFAULT false,
  has_water BOOLEAN DEFAULT false,
  contact_phone TEXT,
  managed_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  opened_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  camp_id UUID REFERENCES relief_camps(id) ON DELETE CASCADE,
  resource_type TEXT CHECK (resource_type IN ('food','water','medicine','blankets','boats','rescue_kit')),
  quantity INTEGER NOT NULL DEFAULT 0,
  unit TEXT,
  last_updated TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS evacuation_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_name TEXT,
  from_area TEXT,
  to_camp_id UUID REFERENCES relief_camps(id),
  route_polyline JSONB,
  distance_km DECIMAL(6,2),
  is_accessible BOOLEAN DEFAULT true,
  last_verified TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_camps_active ON relief_camps(is_active, district);
CREATE INDEX IF NOT EXISTS idx_camps_location ON relief_camps(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_resources_camp ON resources(camp_id, resource_type);

-- ============================================================
-- MODULE 7: Admin Analytics & Audit
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  action TEXT NOT NULL,
  entity_type TEXT CHECK (entity_type IN ('alert','incident','user','camp','resource')),
  entity_id UUID,
  metadata JSONB DEFAULT '{}',
  ip_address TEXT,
  performed_at TIMESTAMPTZ DEFAULT now()
);

CREATE VIEW daily_alert_stats AS
SELECT
  DATE_TRUNC('day', issued_at) AS day,
  severity,
  COUNT(*) AS alert_count
FROM flood_alerts
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

CREATE VIEW incident_resolution_stats AS
SELECT
  category,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE status = 'resolved') AS resolved,
  AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))/3600) AS avg_hours_to_resolve
FROM incidents
GROUP BY category;

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
