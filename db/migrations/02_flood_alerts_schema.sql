-- Module 2: Flood Alerts Schema
-- Neon DB Migration: 02_flood_alerts_schema.sql
-- Branch: feature/alert-module

CREATE TABLE IF NOT EXISTS flood_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'low' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  area_name TEXT NOT NULL,
  description TEXT,
  issued_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  issued_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  notification_sent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alerts_severity ON flood_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON flood_alerts(is_active);
CREATE INDEX IF NOT EXISTS idx_alerts_area ON flood_alerts(area_name);
CREATE INDEX IF NOT EXISTS idx_alerts_issued_at ON flood_alerts(issued_at DESC);

-- FCM push notification log
CREATE TABLE IF NOT EXISTS notification_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id UUID REFERENCES flood_alerts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  sent_at TIMESTAMPTZ DEFAULT now(),
  status TEXT DEFAULT 'sent'
);

DROP TRIGGER IF EXISTS update_flood_alerts_updated_at ON flood_alerts;
CREATE TRIGGER update_flood_alerts_updated_at
  BEFORE UPDATE ON flood_alerts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
