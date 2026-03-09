<p align="center">
  <img src="https://odoocdn.com/openerp_website/static/src/img/assets/svg/odoo_logo.svg" width="200" alt="Odoo Logo">
</p>

# Cloudron Odoo Community App

This repository contains the necessary files to build and deploy the Odoo 19 Community Edition as a native Cloudron application.

## Repository Contents

*   **`Dockerfile`**: The multi-stage Dockerfile that builds the Ubuntu 24.04 environment, installs PostgreSQL 16, Python dependencies, and Odoo itself.
*   **`CloudronManifest.json`**: The Cloudron application manifest defining addons (ldap, sendmail, localstorage), memory limits, and post-installation instructions.
*   **`start.sh`**: The main entrypoint script for Odoo. It handles waiting for PostgreSQL, initial database creation, directory permissions, and launching the Odoo server.
*   **`start-postgres.sh`**: The initialization and startup script for the internal PostgreSQL 16 instance.
*   **`supervisord.conf`**: Supervisor configuration to manage both the Odoo and PostgreSQL processes within the single Cloudron container.
*   **`odoo.conf.template`**: The base Odoo configuration file, pre-configured to point to the local database and persistent `/app/data` directories.

## Prerequisites for Building

1.  **Odoo Source Code**: You need the Odoo 19 Community source code.
    *   [Download the source](https://www.odoo.com/page/download) and extract it.
    *   Place the extracted directory (e.g., `odoo-19.0.post20260307`) in the same directory as these files.
    *   **Important**: Update the `COPY` command in the `Dockerfile` to match your exact Odoo source folder name:
        ```dockerfile
        # Change this line in Dockerfile:
        COPY odoo-19.0.post20260307 /app/code/odoo
        ```
2.  **Cloudron CLI**: Install the Cloudron command-line tool.
    ```bash
    npm install -g cloudron
    cloudron login
    ```
3.  **Docker Registry**: You need access to a Docker registry to push your built image (e.g., Docker Hub, GitLab Registry, or a private registry).

## Quick Install (Cloudron App Store)

You can install this app directly onto your Cloudron server without touching the command line.

1. Open your Cloudron Dashboard.
2. Navigate to the **App Store**.
3. Click the gear icon in the top right and select **Add Custom App**.
4. Paste the following URL:
   ```text
   https://raw.githubusercontent.com/CombinedTurtle/Odoo-Cloudron/main/CloudronVersions.json
   ```
5. Click **Install**. Cloudron will automatically download the pre-built image and configure the app.

## How to Build and Deploy (Manual)

1.  **Build the Docker Image**:
    Ensure you specify the `linux/amd64` platform, as Cloudron requires it. Replace `sentientlemon/odoocommunity:1.0.0` with your actual registry path.
    ```bash
    DOCKER_DEFAULT_PLATFORM=linux/amd64 docker build -t sentientlemon/odoocommunity:1.0.0 .
    ```

2.  **Push the Image**:
    ```bash
    docker push sentientlemon/odoocommunity:1.0.0
    ```

3.  **Install on Cloudron**:
    Use the Cloudron CLI to install the app on your server. Replace `odoo.yourcloudrondomain.com` with your desired subdomain.
    ```bash
    cloudron install --image sentientlemon/odoocommunity:1.0.0 --location odoo.yourcloudrondomain.com
    ```

## Post-Installation Usage

### Default Login
Upon successful installation, Odoo will complete its initialization on the first web request.
*   **URL**: `https://odoo.yourcloudrondomain.com`
*   **Email**: `admin`
*   **Password**: `changeme`

**Please change the admin password immediately after your first login via Settings > Users & Companies > Users.**

### Custom Addons
This package supports persistent custom Odoo modules using Cloudron's File Manager.
1.  Open the Cloudron dashboard, select your Odoo app, and open the inside **File Manager** (or connect via SFTP on port 222).
2.  Navigate to `/app/data/addons/`.
3.  Upload your custom module directories here.
4.  Restart the application from the Cloudron dashboard.
5.  Log into Odoo, enable Developer Mode (Settings -> "Activate the developer mode"), navigate to **Apps**, and click **Update Apps List**.

**Overriding Core Addons**
Cloudron mounts the core application code (`/app/code`) as **read-only** to ensure stability during updates. If you need to edit a core Odoo module (like `sale` or `mail`), you should NOT edit the source directly. Instead, copy it into your writable addons folder! Because `addons_path` is configured to prioritize `/app/data/addons`, your modified copy will override the core module.
```bash
# Example: Copying the 'mail' module so you can edit it with nano
cloudron exec --app odoo.yourcloudrondomain.com -- cp -r /app/code/venv/lib/python3.12/site-packages/odoo/addons/mail /app/data/addons/
cloudron exec --app odoo.yourcloudrondomain.com -- nano /app/data/addons/mail/models/mail_mail.py
```

### Database Migration / Restore
You can migrate an existing Odoo 19 database into this Cloudron app using a built-in automated restore process.
1.  Generate a `pg_dump` backup of your source Odoo database in the custom format (`-Fc`).
2.  Using the Cloudron File Manager or SFTP, upload your dump file exactly to:
    `/app/data/restore/database.dump`
    *(Note: You must create the `restore` folder if it doesn't exist)*
3.  If you have a filestore backup, upload its contents to:
    `/app/data/restore/filestore/`
4.  Restart the application from the Cloudron dashboard.
5.  The `start.sh` script will detect the `database.dump` file, drop the current database, restore your dump, copy the filestore, and then automatically delete the restore files to prevent re-restoring on subsequent boots.

### Performance Tuning
To handle more users or scheduled operations, you can modify the following parameters inside the `odoo.conf.template` file before deploying or updating the app.
*   **`workers`**: Controls the number of web workers processing concurrent HTTP requests. As a rule of thumb, set this to `(CPU Cores * 2) + 1`. Increase this value if you assign the Cloudron app more RAM / CPU limits (default is `2`).
*   **`max_cron_threads`**: Governs the number of background workers handling scheduled system operations, such as automated emails or invoice calculation (default is `1`).

### Updating the App (Pushing Changes)
Cloudron manages updates non-destructively. Because all database files and custom configuration live in the persistent `/app/data` directory, you can push updates to the Docker container without breaking existing installations.

To automate the update process, we have included a **`deploy.sh`** script. When you make changes to the source code (like modifying `start.sh` or the `Dockerfile`):

1. Run the deployment script from this directory:
   ```bash
   ./deploy.sh
   ```
2. The script will automatically:
   * Bump the patch version number in `CloudronManifest.json` (e.g., from `1.0.0` to `1.0.1`).
   * Build the new Docker image (`docker build`).
   * Push the new image to your configured registry (`docker push`).
   * Instruct Cloudron to pull the new image, take a backup, and swap the application container (`cloudron update --image`).

### Configuring Cloudron Integrations (LDAP/SMTP)
Currently, configuring Cloudron's built-in LDAP and SMTP requires manual setup within the Odoo admin interface.
*   **LDAP**: Go to Settings -> General Settings -> Integrations -> LDAP Server. Use the environment variables provided in the Cloudron app's "Terminal" view (e.g., `CLOUDRON_LDAP_SERVER`, `CLOUDRON_LDAP_BIND_DN`) to configure the connection.
*   **SMTP**: Go to Settings -> Technical -> Outgoing Mail Servers. Use `CLOUDRON_MAIL_SMTP_SERVER`, `CLOUDRON_MAIL_SMTP_PORT`, `CLOUDRON_MAIL_SMTP_USERNAME`, and `CLOUDRON_MAIL_SMTP_PASSWORD`.
