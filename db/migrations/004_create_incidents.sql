-- Module 5: Incident Reporting
CREATE TABLE IF NOT EXISTS incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by UUID REFERENCES users(id) NOT NULL,
  assigned_to UUID REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  status TEXT CHECK (status IN ('open','assigned','in_progress','resolved')) DEFAULT 'open',
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  image_urls JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_reporter ON incidents(reported_by);
CREATE INDEX IF NOT EXISTS idx_incidents_assignee ON incidents(assigned_to);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER incidents_updated_at
BEFORE UPDATE ON incidents
FOR EACH ROW EXECUTE FUNCTION update_updated_at();
