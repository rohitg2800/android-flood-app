-- Phase 1: Accessibility Settings
-- Applied: 2026-06-29

CREATE TABLE IF NOT EXISTS user_accessibility_settings (
  id            uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       text          NOT NULL UNIQUE,
  text_scale    numeric(4,2)  NOT NULL DEFAULT 1.0 CHECK (text_scale >= 0.5 AND text_scale <= 2.5),
  high_contrast boolean       NOT NULL DEFAULT false,
  bold_text     boolean       NOT NULL DEFAULT false,
  locale        text          NOT NULL DEFAULT 'en',
  created_at    timestamptz   NOT NULL DEFAULT now(),
  updated_at    timestamptz   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS accessibility_audit_log (
  id            bigserial     PRIMARY KEY,
  user_id       text          NOT NULL,
  changed_at    timestamptz   NOT NULL DEFAULT now(),
  field_changed text          NOT NULL,
  old_value     text,
  new_value     text,
  source        text          NOT NULL DEFAULT 'ui',
  session_id    text
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $func$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$func$;

DROP TRIGGER IF EXISTS trg_user_accessibility_settings_updated_at ON user_accessibility_settings;
CREATE TRIGGER trg_user_accessibility_settings_updated_at
  BEFORE UPDATE ON user_accessibility_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();