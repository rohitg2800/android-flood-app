-- Module 7: Analytics Dashboard & Admin Panel
-- Neon PostgreSQL Schema

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  metadata JSONB DEFAULT '{}',
  ip_address TEXT,
  performed_at TIMESTAMPTZ DEFAULT now()
);

-- Aggregated analytics view
CREATE OR REPLACE VIEW alert_summary AS
SELECT
  severity,
  COUNT(*) AS total_alerts,
  COUNT(*) FILTER (WHERE is_active = true) AS active_alerts,
  MAX(issued_at) AS latest_issued
FROM flood_alerts
GROUP BY severity;

CREATE OR REPLACE VIEW incident_summary AS
SELECT
  status,
  priority,
  COUNT(*) AS total,
  DATE_TRUNC('day', created_at) AS date
FROM incidents
GROUP BY status, priority, DATE_TRUNC('day', created_at)
ORDER BY date DESC;

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_performed ON audit_logs(performed_at DESC);
