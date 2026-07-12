#!/bin/bash
# Run all Neon DB migrations in order
# Usage: NEON_DATABASE_URL=<your-url> ./db/migrate.sh

set -e

if [ -z "$NEON_DATABASE_URL" ]; then
  echo "Error: NEON_DATABASE_URL environment variable is not set"
  exit 1
fi

echo "Running migrations against Neon DB..."

for file in db/schemas/*.sql; do
  echo "Applying: $file"
  psql "$NEON_DATABASE_URL" -f "$file"
  echo "Done: $file"
done

echo "All migrations applied successfully!"
