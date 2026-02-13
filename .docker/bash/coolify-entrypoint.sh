#!/bin/bash
# Remove set -e to allow container to stay up even if migrations fail initially
# set -e

# Fix permissions if needed
chown -R www-data:www-data /var/www/uvdesk/var /var/www/uvdesk/public

# Handle persistent .env
# STRATEGY: Configuration as Code via UV_ENV_FILE_CONTENT
if [ ! -z "$UV_ENV_FILE_CONTENT" ]; then
    echo "Found UV_ENV_FILE_CONTENT environment variable. Overwriting persistent .env file."
    echo "$UV_ENV_FILE_CONTENT" > /data/uvdesk-config/.env
    chown www-data:www-data /data/uvdesk-config/.env
    chmod 666 /data/uvdesk-config/.env
fi

# Fallback: Initialize if missing or empty
if [ ! -f /data/uvdesk-config/.env ] || [ ! -s /data/uvdesk-config/.env ]; then
    echo "Initializing persistent .env from image default (file missing or empty)"
    if [ -f /var/www/uvdesk/.env ]; then
        cp /var/www/uvdesk/.env /data/uvdesk-config/.env
    else
        touch /data/uvdesk-config/.env
    fi
    chown www-data:www-data /data/uvdesk-config/.env
    chmod 666 /data/uvdesk-config/.env
fi

# Force APP_ENV=prod and APP_DEBUG=0 in persistent .env if it exists AND env var is not set (to avoid overwriting user provided config)
if [ -f /data/uvdesk-config/.env ] && [ -z "$UV_ENV_FILE_CONTENT" ]; then
    sed -i 's/APP_ENV=dev/APP_ENV=prod/g' /data/uvdesk-config/.env
    sed -i 's/APP_DEBUG=1/APP_DEBUG=0/g' /data/uvdesk-config/.env
fi

# Link the app .env to the persistent one
if [ ! -L /var/www/uvdesk/.env ]; then
    echo "Linking .env to persistent storage"
    # Force remove .env whether it is a file or a directory
    rm -rf /var/www/uvdesk/.env
    ln -s /data/uvdesk-config/.env /var/www/uvdesk/.env
fi

# Ensure web server can write to it
chown -h www-data:www-data /var/www/uvdesk/.env
chown www-data:www-data /data/uvdesk-config/.env

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
