-- Module 3: Flood Alert & Notification System Schema
-- Branch: feature/alert-module
-- Created: 2026-07-07

CREATE TABLE IF NOT EXISTS flood_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  area_name TEXT,
  description TEXT,
  issued_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  issued_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alerts_severity ON flood_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_is_active ON flood_alerts(is_active);
CREATE INDEX IF NOT EXISTS idx_alerts_issued_at ON flood_alerts(issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_location ON flood_alerts(location_lat, location_lng);

-- Notification queue for FCM push
CREATE TABLE IF NOT EXISTS notification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id UUID REFERENCES flood_alerts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER alerts_updated_at
  BEFORE UPDATE ON flood_alerts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
