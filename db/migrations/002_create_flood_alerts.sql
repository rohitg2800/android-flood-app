-- Module 3: Alert System
CREATE TABLE IF NOT EXISTS flood_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  severity TEXT CHECK (severity IN ('low','medium','high','critical')) NOT NULL,
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  area_name TEXT NOT NULL,
  description TEXT,
  issued_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  issued_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alerts_severity ON flood_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON flood_alerts(is_active);
CREATE INDEX IF NOT EXISTS idx_alerts_area ON flood_alerts(area_name);
