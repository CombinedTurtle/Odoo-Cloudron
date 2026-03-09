# Odoo 19 Community for Cloudron

This image is a custom-packaged version of Odoo 19 Community Edition specifically optimized to run as a native [Cloudron](https://cloudron.io) application.

## Features
* **Isolated Environment**: Runs completely self-contained within a Cloudron app container.
* **Internal PostgreSQL**: Uses `supervisord` to run an internal PostgreSQL 16 database instance, resolving complex configuration and permission issues while integrating seamlessly with Cloudron's read-only file system.
* **Custom Addons Support**: Maps Odoo's `addons_path` to Cloudron's persistent `/app/data/addons` directory. You can easily drag-and-drop custom Odoo modules using Cloudron's File Manager and they will survive app updates and backups.
* **Auto-Restore Sentinel**: A built-in feature to easily migrate existing Odoo databases. Upload a `pg_dump` file to `/app/data/restore/database.dump`, restart the app, and the startup scripts will automatically wipe the internal database, restore your SQL dump, and clean up.
* **Non-Destructive Core Overrides**: Allows developers to safely override core Odoo module code by copying the module folder into the custom addons directory.

## Installation via App Store

You do not need to pull this Docker image manually! You can install it directly onto your Cloudron server using the Custom App Store feature out-of-the-box.

1. Open your Cloudron Dashboard.
2. Navigate to the **App Store**.
3. Click the gear icon in the top right and select **Add Custom App**.
4. Paste the following URL:
   `https://raw.githubusercontent.com/CombinedTurtle/Odoo-Cloudron/main/CloudronVersions.json`
5. Click **Install**. Cloudron will take care of the rest!

## Source Code & Documentation

The GitHub repository containing the complete Cloudron build scripts, manifests, setup documentation, and usage instructions can be found here:

**[https://github.com/CombinedTurtle/Odoo-Cloudron](https://github.com/CombinedTurtle/Odoo-Cloudron)**
