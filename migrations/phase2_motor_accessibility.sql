-- ============================================================
-- PHASE 2 MIGRATION: Motor Control + Accessibility Enhancements
-- Applied to Neon main branch on 2026-06-29
-- ============================================================

-- MODULE 1A: pump_stations
CREATE TABLE IF NOT EXISTS public.pump_stations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  district         TEXT,
  state            TEXT NOT NULL DEFAULT 'Bihar',
  location_lat     DOUBLE PRECISION,
  location_lng     DOUBLE PRECISION,
  status           TEXT NOT NULL DEFAULT 'inactive'
                     CHECK (status IN ('active', 'inactive', 'fault')),
  capacity_lps     NUMERIC(10,2),
  installed_at     TIMESTAMP WITH TIME ZONE,
  created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pump_stations_district ON public.pump_stations (district);
CREATE INDEX IF NOT EXISTS idx_pump_stations_status   ON public.pump_stations (status);

-- MODULE 1B: motor_logs
-- triggered_by = neon_auth user ID (TEXT, no cross-schema FK enforced at DB level)
CREATE TABLE IF NOT EXISTS public.motor_logs (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pump_station_id     UUID NOT NULL REFERENCES public.pump_stations (id) ON DELETE CASCADE,
  triggered_by        TEXT,
  action              TEXT NOT NULL CHECK (action IN ('start', 'stop', 'auto-trigger', 'fault-reset')),
  reason              TEXT,
  water_level_ref_id  BIGINT,
  logged_at           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_motor_logs_pump_station ON public.motor_logs (pump_station_id);
CREATE INDEX IF NOT EXISTS idx_motor_logs_triggered_by ON public.motor_logs (triggered_by);
CREATE INDEX IF NOT EXISTS idx_motor_logs_logged_at    ON public.motor_logs (logged_at DESC);

-- MODULE 2A: user_accessibility_settings enhancements
ALTER TABLE public.user_accessibility_settings
  ADD COLUMN IF NOT EXISTS font_family      TEXT    NOT NULL DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS line_spacing     NUMERIC NOT NULL DEFAULT 1.5,
  ADD COLUMN IF NOT EXISTS focus_highlight  BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS captions_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS haptic_feedback  BOOLEAN NOT NULL DEFAULT false;

-- MODULE 2B: user_preferences sync
ALTER TABLE public.user_preferences
  ADD COLUMN IF NOT EXISTS font_family      TEXT    NOT NULL DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS line_spacing     NUMERIC NOT NULL DEFAULT 1.5,
  ADD COLUMN IF NOT EXISTS focus_highlight  BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS captions_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS haptic_feedback  BOOLEAN NOT NULL DEFAULT false;
