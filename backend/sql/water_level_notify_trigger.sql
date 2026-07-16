CREATE OR REPLACE FUNCTION notify_water_level_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_notify(
    'water_level_channel',
    row_to_json(NEW)::text
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_water_level_insert ON water_level_readings;

CREATE TRIGGER trg_notify_water_level_insert
AFTER INSERT ON water_level_readings
FOR EACH ROW
EXECUTE FUNCTION notify_water_level_insert();
