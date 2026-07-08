-- Module 5: Incident Reporting & Field Agent Tools
-- Neon PostgreSQL Schema

CREATE TABLE IF NOT EXISTS incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT CHECK (status IN ('open', 'assigned', 'in_progress', 'resolved')) NOT NULL DEFAULT 'open',
  priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  address TEXT,
  image_urls JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_assigned ON incidents(assigned_to);
CREATE INDEX IF NOT EXISTS idx_incidents_reported ON incidents(reported_by);
CREATE INDEX IF NOT EXISTS idx_incidents_created ON incidents(created_at DESC);
