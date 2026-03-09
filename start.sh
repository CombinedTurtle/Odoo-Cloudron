#!/bin/bash
set -eu

echo "Starting Odoo Setup for Cloudron"
CONFIG_FILE="/app/data/odoo.conf"
INIT_FLAG_FILE="/app/data/.odoo_initialized"
RESTORE_DIR="/app/data/restore"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to start..."
until gosu postgres pg_isready -h 127.0.0.1 -p 5432 -U postgres
do
    echo "Waiting for postgres..."
    sleep 2
done
echo "PostgreSQL is up."

# 1. Setup Data Directories
mkdir -p /app/data/filestore /app/data/sessions /app/data/addons /app/data/restore
chown -R cloudron:cloudron /app/data/filestore /app/data/sessions /app/data/addons /app/data/restore

# 2. Setup Internal DB Password
DB_PASS_FILE="/app/data/.db_pass"
if [ ! -f "${DB_PASS_FILE}" ]; then
    echo "Generating secure internal database password..."
    head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24 > "${DB_PASS_FILE}"
fi
DB_PASSWORD=$(cat "${DB_PASS_FILE}")

# 3. Generate configuration from template (always regenerate to pick up config changes)
echo "Generating Odoo configuration from template..."
sed "s/__DB_PASSWORD__/${DB_PASSWORD}/g" /app/code/odoo.conf.template > ${CONFIG_FILE}
chown cloudron:cloudron ${CONFIG_FILE}
chmod 600 ${CONFIG_FILE}

# 3. Handle First-time Database Initialization
if [ ! -f "${INIT_FLAG_FILE}" ]; then
    echo "First run: Creating Odoo database and user..."
    
    # Check if user 'odoo' exists
    if ! gosu postgres psql -h 127.0.0.1 -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
        echo "Creating 'odoo' user..."
        gosu postgres psql -h 127.0.0.1 -U postgres -c "CREATE USER odoo WITH PASSWORD '${DB_PASSWORD}';"
    else
        echo "'odoo' user already exists. Enforcing current internal password..."
        gosu postgres psql -h 127.0.0.1 -U postgres -c "ALTER USER odoo WITH PASSWORD '${DB_PASSWORD}';"
    fi
    
    # Check if database 'odoo_prod' exists
    if ! gosu postgres psql -h 127.0.0.1 -U postgres -lqt | cut -d\| -f 1 | grep -qw odoo_prod; then
        echo "Creating 'odoo_prod' database..."
        gosu postgres psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE odoo_prod OWNER odoo;"
    else
        echo "'odoo_prod' database already exists."
    fi
    
    echo "Database setup complete."
    
    # Initialize Odoo database (first boot may take a while)
    echo "Initializing Odoo database (this may take a minute)..."
    su - cloudron -c "/app/code/venv/bin/odoo -c /app/data/odoo.conf -d odoo_prod -i base --stop-after-init --without-demo=all"
    
    # Set admin password to 'changeme'
    echo "Setting default admin password..."
    gosu postgres psql -h 127.0.0.1 -U odoo -d odoo_prod -c "UPDATE res_users SET password='changeme' WHERE login='admin';"
    
    touch ${INIT_FLAG_FILE}
    echo "Initialization complete."
fi

# 4. Database Restore (sentinel file pattern)
# To restore a database:
#   1. Upload a pg_dump file to /app/data/restore/database.dump
#   2. Optionally upload filestore to /app/data/restore/filestore/ 
#   3. Restart the app — the restore will run automatically
#   4. The sentinel files are removed after restore completes
if [ -f "${RESTORE_DIR}/database.dump" ]; then
    echo "=== DATABASE RESTORE DETECTED ==="
    echo "Restoring database from ${RESTORE_DIR}/database.dump ..."
    
    # Drop and recreate the database
    gosu postgres psql -h 127.0.0.1 -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='odoo_prod' AND pid <> pg_backend_pid();" || true
    gosu postgres psql -h 127.0.0.1 -U postgres -c "DROP DATABASE IF EXISTS odoo_prod;"
    gosu postgres psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE odoo_prod OWNER odoo;"
    
    # Restore the dump
    gosu postgres pg_restore -h 127.0.0.1 -U postgres -d odoo_prod --no-owner --role=odoo "${RESTORE_DIR}/database.dump" || true
    
    echo "Database restored successfully."
    
    # Restore filestore if provided
    if [ -d "${RESTORE_DIR}/filestore" ]; then
        echo "Restoring filestore..."
        rm -rf /app/data/filestore/odoo_prod
        mkdir -p /app/data/filestore/odoo_prod
        cp -r ${RESTORE_DIR}/filestore/* /app/data/filestore/odoo_prod/
        chown -R cloudron:cloudron /app/data/filestore/
        echo "Filestore restored."
    fi
    
    # Clean up sentinel files
    rm -f "${RESTORE_DIR}/database.dump"
    rm -rf "${RESTORE_DIR}/filestore"
    echo "=== RESTORE COMPLETE ==="
fi

# 5. Start Odoo
echo "Starting Odoo server..."
exec su - cloudron -c "/app/code/venv/bin/odoo -c /app/data/odoo.conf"
