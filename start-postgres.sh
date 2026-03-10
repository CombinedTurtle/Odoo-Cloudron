#!/bin/bash
set -e

PGDATA="/app/data/postgresql"
PG_BIN="/usr/lib/postgresql/17/bin"
OLD_PG_BIN="/usr/lib/postgresql/16/bin"

# Handle upgrade from PG 16 to PG 17
if [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ]; then
    CURRENT_PG_VERSION=$(cat "$PGDATA/PG_VERSION")
    if [ "$CURRENT_PG_VERSION" = "16" ]; then
        echo "=== POSTGRESQL UPGRADE: 16 -> 17 ==="
        echo "Existing PG 16 data directory detected. Performing pg_upgrade..."
        
        NEW_PGDATA="/app/data/postgresql_17"
        mkdir -p "$NEW_PGDATA"
        chown -R postgres:postgres "$NEW_PGDATA"
        chmod 700 "$NEW_PGDATA"
        
        # Initialize a new PG 17 cluster
        gosu postgres $PG_BIN/initdb -D "$NEW_PGDATA"
        
        # Ensure trust auth for local connections in both clusters
        echo "host all all 127.0.0.1/32 trust" >> "$NEW_PGDATA/pg_hba.conf"
        
        # Run pg_upgrade
        cd /tmp
        gosu postgres $PG_BIN/pg_upgrade \
            --old-datadir="$PGDATA" \
            --new-datadir="$NEW_PGDATA" \
            --old-bindir="$OLD_PG_BIN" \
            --new-bindir="$PG_BIN" \
            --link 2>&1 || {
            echo "ERROR: pg_upgrade failed! Falling back to PG 16 data directory."
            rm -rf "$NEW_PGDATA"
            # Fall through to start with whatever we have
            exec gosu postgres $PG_BIN/postgres -D "$PGDATA" -c listen_addresses='localhost'
        }
        
        # Swap directories
        mv "$PGDATA" "/app/data/postgresql_16_backup"
        mv "$NEW_PGDATA" "$PGDATA"
        
        echo "=== POSTGRESQL UPGRADE COMPLETE ==="
        echo "Old data directory backed up to /app/data/postgresql_16_backup"
    fi
fi

# Fresh install: initialize new PG 17 data directory
if [ ! -d "$PGDATA" ]; then
    echo "Initializing PostgreSQL 17 data directory..."
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"
    gosu postgres $PG_BIN/initdb -D "$PGDATA"
    
    # Ensure we can connect from 127.0.0.1 without prompting for a password
    echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"
fi

echo "Starting PostgreSQL 17..."
exec gosu postgres $PG_BIN/postgres -D "$PGDATA" -c listen_addresses='localhost'
