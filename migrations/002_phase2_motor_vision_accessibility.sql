-- Phase 2: Motor & Vision Accessibility (Week 3–4)
ALTER TABLE user_accessibility_settings
  ADD COLUMN IF NOT EXISTS reduce_motion      BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS large_tap_targets  BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS screen_reader_mode BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS color_blind_mode   VARCHAR(20) DEFAULT 'none';
  -- color_blind_mode values: 'none' | 'deuteranopia' | 'protanopia' | 'tritanopia'
