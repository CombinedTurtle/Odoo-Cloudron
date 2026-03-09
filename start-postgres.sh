#!/bin/bash
set -e

PGDATA="/app/data/postgresql"

if [ ! -d "$PGDATA" ]; then
    echo "Initializing PostgreSQL data directory..."
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"
    gosu postgres /usr/lib/postgresql/16/bin/initdb -D "$PGDATA"
    
    # Ensure we can connect from 127.0.0.1 without prompting for a password
    echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"
fi

echo "Starting PostgreSQL..."
exec gosu postgres /usr/lib/postgresql/16/bin/postgres -D "$PGDATA" -c listen_addresses='localhost'
