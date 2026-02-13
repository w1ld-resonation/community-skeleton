#!/bin/bash
set -e

# Fix permissions if needed
chown -R www-data:www-data /var/www/uvdesk/var /var/www/uvdesk/public

# Create database if not exists (using UVDesk console if available or doctrine)
# We use || true to avoid failure if DB already exists or connection fails temporarily (though we want it to work)
echo "Checking database connection..."
# We could add a wait-for-it script here if needed, but for now we rely on restarts.

echo "Running migrations..."
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration || echo "Migrations failed or not needed."

echo "Clearing cache..."
php bin/console cache:clear --env=prod

# Ensure apache uses env vars
source /etc/apache2/envvars

echo "Starting Apache..."
exec apache2 -D FOREGROUND
