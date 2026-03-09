FROM ubuntu:24.04

# Cloudron baseline
ENV DEBIAN_FRONTEND=noninteractive

# Prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    nano \
    git \
    sudo \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    nodejs \
    npm \
    build-essential \
    libxml2-dev \
    libxslt1-dev \
    libldap2-dev \
    libsasl2-dev \
    libtiff5-dev \
    libjpeg8-dev \
    libopenjp2-7-dev \
    zlib1g-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libxcb1-dev \
    libpq-dev \
    xz-utils \
    fonts-noto-cjk \
    gettext-base \
    supervisor \
    postgresql-16 \
    postgresql-client-16 \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install wkhtmltopdf from apt repository (avoids deb dependency hell)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wkhtmltopdf \
    && rm -rf /var/lib/apt/lists/*

# Less CSS
RUN npm install -g rtlcss

# Create Cloudron user and directories
RUN useradd -m -s /bin/bash cloudron \
    && mkdir -p /app/code /app/data /app/pkg \
    && chown -R cloudron:cloudron /app

WORKDIR /app/code

# Setup Python Virtual Environment
RUN python3 -m venv /app/code/venv \
    && /app/code/venv/bin/pip install --upgrade pip setuptools wheel

# Add Odoo Community Code
COPY odoo-19.0.post20260307 /app/code/odoo

# Install Odoo Python Requirements + Odoo itself (creates 'odoo' entry point in venv/bin/)
RUN /app/code/venv/bin/pip install -r /app/code/odoo/requirements.txt \
    && /app/code/venv/bin/pip install psycopg2-binary passlib \
    && cd /app/code/odoo && /app/code/venv/bin/pip install .

# Setup Supervisor and Startup Scripts
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-postgres.sh /app/pkg/start-postgres.sh
COPY start.sh /app/pkg/start-odoo.sh
COPY odoo.conf.template /app/code/
RUN chmod +x /app/pkg/start-postgres.sh /app/pkg/start-odoo.sh

# Create directories for postgresql runtime
RUN mkdir -p /var/run/postgresql \
    && chown -R postgres:postgres /var/run/postgresql

# Cloudron runs as root first to map permissions
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
