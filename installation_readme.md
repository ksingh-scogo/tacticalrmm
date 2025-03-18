# TacticalRMM Installation Guide with External PostgreSQL Database

This guide walks you through installing TacticalRMM using the `install_ext_pgdb.sh` script, which configures TacticalRMM with an external Neon PostgreSQL database instead of a local database.

## System Requirements

- **Operating System**: Debian 11, Debian 12, or Ubuntu 22.04 LTS
- **Memory**: Minimum 4GB RAM
- **CPU Architecture**: x86_64 (amd64) or aarch64 (arm64)
- **Clean Server**: Must be a fresh installation with no existing TacticalRMM components

## Domain Information

The following domains will be used for this installation:
- **API Domain**: nexus-api.icebrg.ai
- **Frontend Domain**: nexus.icebrg.ai
- **MeshCentral Domain**: nexus-mesh.icebrg.ai
- **Root Domain**: icebrg.ai

## Prerequisites

1. **Domain Name**: You need the icebrg.ai domain with the appropriate subdomains
2. **DNS Records**: Create 3 A records pointing to your server's public IP:
   - `nexus-api.icebrg.ai` (backend)
   - `nexus.icebrg.ai` (frontend)
   - `nexus-mesh.icebrg.ai` (MeshCentral)
3. **Email Address**: Required for Let's Encrypt certificates
4. **Port Forwarding**: Ensure port 443 (HTTPS) is forwarded to your server if behind NAT

## Setting Up External PostgreSQL Database

This section guides you through setting up an external PostgreSQL database before running the TacticalRMM installation script. This is intended for users who want to use a remote PostgreSQL server instead of a local installation.

### Prerequisites

- An existing PostgreSQL server (version 12 or higher) accessible via network
- PostgreSQL client tools installed on your local machine: `sudo apt install -y postgresql-client`
- Network connectivity between your TacticalRMM server and PostgreSQL server

### 1. Connect to Your External PostgreSQL Server

```bash
psql -h your-postgres-host.example.com -U postgres -p 5432
```

If your PostgreSQL server requires SSL:

```bash
psql "host=c-mycluster.12345678901234.postgres.cosmos.azure.com port=5432 dbname=citus user=NAME_pgdb_admin password=mypassword"

```

For cloud-hosted PostgreSQL services (like AWS RDS, Azure Database, GCP Cloud SQL, or Neon):
- Use the connection string provided by your cloud provider
- Ensure you have the correct username, password, and host information

### 2. Create Databases and User

Once connected to the PostgreSQL server, run these SQL commands to set up both databases with a single user:

#### Develoment Environment:

```
User : scogo_nexus_dev
Database Names 
- nexusrmm_dev
- nexusmesh_dev
```

```sql
-- Create both databases
CREATE DATABASE nexusrmm_dev;
CREATE DATABASE nexusmesh_dev;

-- Create a single user with password (use a strong password)
CREATE USER scogo_nexus_dev WITH PASSWORD 'SUPER_SECRET_PASSWORD';

-- Set appropriate parameters for the user
ALTER ROLE scogo_nexus_dev SET client_encoding TO 'utf8';
ALTER ROLE scogo_nexus_dev SET default_transaction_isolation TO 'read committed';
ALTER ROLE scogo_nexus_dev SET timezone TO 'UTC';

-- Grant necessary privileges to both databases
GRANT ALL PRIVILEGES ON DATABASE nexusrmm_dev TO scogo_nexus_dev;
GRANT ALL PRIVILEGES ON DATABASE nexusmesh_dev TO scogo_nexus_dev;

-- Grant membership privileges
GRANT scogo_nexus_dev TO NAME_pgdb_admin;

-- Connect to nexusrmm database to set ownership
\c nexusrmm_dev
ALTER SCHEMA public OWNER TO scogo_nexus_dev;

-- Connect to nexusmesh database to set ownership
\c nexusmesh_dev
ALTER SCHEMA public OWNER TO scogo_nexus_dev;

```
- Verify the database access:
```

PGPASSWORD=SUPER_SECRET_PASSWORD psql -h scogo-pgdb-prod.postgres.database.azure.com -U scogo_nexus_dev -d nexusrmm_dev

PGPASSWORD=SUPER_SECRET_PASSWORD psql -h scogo-pgdb-prod.postgres.database.azure.com -U scogo_nexus_dev -d nexusmesh_dev

```

#### Production Environment:

```
User : scogo_nexus
Database Names 
- nexusrmm
- nexusmesh
```

```sql
-- Create both databases
CREATE DATABASE nexusrmm;
CREATE DATABASE nexusmesh;

-- Create a single user with password (use a strong password)
CREATE USER scogo_nexus WITH PASSWORD 'SUPER_SECRET_PASSWORD';

-- Set appropriate parameters for the user
ALTER ROLE scogo_nexus SET client_encoding TO 'utf8';
ALTER ROLE scogo_nexus SET default_transaction_isolation TO 'read committed';
ALTER ROLE scogo_nexus SET timezone TO 'UTC';

-- Grant necessary privileges to both databases
GRANT ALL PRIVILEGES ON DATABASE nexusrmm TO scogo_nexus;
GRANT ALL PRIVILEGES ON DATABASE nexusmesh TO scogo_nexus;

-- Grant membership privileges
GRANT scogo_nexus TO NAME_pgdb_admin;

-- Connect to nexusrmm database to set ownership
\c nexusrmm
ALTER SCHEMA public OWNER TO scogo_nexus;

-- Connect to nexusmesh database to set ownership
\c nexusmesh
ALTER SCHEMA public OWNER TO scogo_nexus;

```
- Verify the database access:

```bash
# Test tacticalrmm database connection
PGPASSWORD=SUPER_SECRET_PASSWORD psql -h your-postgres-host.example.com -U scogo_nexus -d nexusrmm

# Test meshcentral database connection
PGPASSWORD=SUPER_SECRET_PASSWORD psql -h your-postgres-host.example.com -U scogo_nexus -d nexusmesh
```

#### Connection Pooling

For high-performance setups, consider enabling connection pooling on your database service if available, or using PgBouncer in front of your PostgreSQL server.

## Installation Steps

### 1. Prepare Your Server

First, install the required packages and update your system:

```bash
sudo apt update
sudo apt install -y wget curl sudo ufw vim git
sudo apt -y upgrade
```

#### Create a Non-Root User (if not already done)

TacticalRMM installation should be run as a non-root user with sudo privileges:

```bash
sudo useradd -m -G sudo -s /bin/bash scogo
sudo passwd scogo
# Set a secure password for the user
```

Log in as the new user:

```bash
su - scogo
```

#### Configure Firewall

Set up basic firewall rules to protect your server:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow https
sudo ufw allow ssh
sudo ufw enable && sudo ufw reload
sudo ufw status
```

#### Verify Your Public IP

Confirm your server's public IP address to use for DNS records:

```bash
curl https://icanhazip.tacticalrmm.io
# Example output: 20.244.9.89
```

Use this IP address when creating the DNS records for your domains.

#### Complete System Updates

Finalize system preparation:

```bash
sudo apt update
sudo upgrade -y
sudo reboot
```

After the server reboots, log back in and continue with the installation.

### 2. Download the Installation Script

```bash
wget https://raw.githubusercontent.com/ksingh-scogo/tacticalrmm/refs/heads/ksingh-v1.0.0/install_ext_pgdb.sh
chmod +x install_ext_pgdb.sh
```

### 3. Update Installation Script with Your Database Credentials

Before running the installation script, modify the database configuration in `install_ext_pgdb.sh`:

```bash
# Download the installation script
wget https://raw.githubusercontent.com/ksingh-scogo/tacticalrmm/refs/heads/ksingh-v1.0.0/install_ext_pgdb.sh
chmod +x install_ext_pgdb.sh

# Edit the script to update database credentials
nano install_ext_pgdb.sh
```

Find and modify these lines in the script (around line 110-115):

```bash
# Set database credentials for external PostgreSQL
pgusername="trmm_user"  # Replace with your database user
pgpw="your_secure_password"  # Replace with your password
pghost="your-postgres-host.example.com"  # Replace with your PostgreSQL host
MESHPGUSER="trmm_user"  # Use the same user for meshcentral
MESHPGPWD="your_secure_password"  # Use the same password
```

Save the changes and proceed with the installation as described in the next section.

### Additional Configuration for Cloud Database Services

#### SSL Configuration

Most cloud PostgreSQL providers require SSL connections. The installation script already includes SSL configuration, but you might need to modify it for specific providers.

For Neon PostgreSQL:
```bash
# The script already includes this for Neon:
'OPTIONS': {
    'sslmode': 'require',
}
```

For AWS RDS or other providers that use certificates:
```bash
# You might need to add this to the script manually:
'OPTIONS': {
    'sslmode': 'verify-full',
    'sslrootcert': '/path/to/ca-certificate.pem',
}
```


### 4. Run the Installation Script

Important: Run as a regular user with sudo privileges, NOT as root!

```bash
./install_ext_pgdb.sh
```

### 5. Follow the Prompts

When prompted, enter the following information:

- Subdomain for backend: `nexus-api.icebrg.ai`
- Subdomain for frontend: `nexus.icebrg.ai`
- Subdomain for MeshCentral: `nexus-mesh.icebrg.ai`
- Root domain: `icebrg.ai`
- Email address for Let's Encrypt certificates
- Username for the RMM web interface

### 6. DNS Challenge for Let's Encrypt

During installation, you'll be prompted to create a DNS TXT record for Let's Encrypt validation:

1. Create the specified TXT record in your icebrg.ai domain's DNS settings
2. Wait for DNS propagation (may take a few minutes to several hours)
3. Press Enter to continue the installation once the record is created

### 7. Set Up Two-Factor Authentication

After installation, a QR code will be displayed for setting up two-factor authentication:

1. Scan the QR code with your authenticator app (Google Authenticator, Authy, etc.)
2. Keep the authenticator app code handy for your first login

## Post-Installation

1. Access your TacticalRMM instance at `https://nexus.icebrg.ai`
2. Log in with the username and password you created during installation
3. When prompted, enter the 2FA code from your authenticator app

## MeshCentral Access

The installation creates a MeshCentral admin account with the following credentials:
- URL: `https://nexus-mesh.icebrg.ai`
- Username: Generated during installation (shown in output)
- Password: Generated during installation (shown in output)

## Special Considerations

### Using Behind NAT/Home Network

If your server is behind NAT and your router doesn't support hairpin NAT:

1. Add entries to your local computer's hosts file to point the domains to the server's internal IP address:
   ```
   192.168.1.x    nexus-api.icebrg.ai nexus.icebrg.ai nexus-mesh.icebrg.ai
   ```
   (Replace 192.168.1.x with your server's actual internal IP)
2. This is only needed for devices on the same network as the server

### Self-Signed Certificates

If you prefer using self-signed certificates instead of Let's Encrypt:

```bash
./install_ext_pgdb.sh --insecure
```

### Using Your Own Certificates

If you already have valid certificates:

```bash
./install_ext_pgdb.sh --use-own-cert
```

You'll be prompted for the paths to your fullchain.pem and privkey.pem files.

## Day-to-Day Operations & Maintenance

### Monitoring System Health

Regular system monitoring is essential for optimal TacticalRMM performance:

```bash
# Check system resources
htop

# Check disk space
df -h

# Check service status for all TacticalRMM services
sudo systemctl status rmm.service daphne.service celery.service celerybeat.service nats.service nats-api.service meshcentral.service nginx
```

### Backing Up TacticalRMM

The system uses an external Neon PostgreSQL database, but you should still backup local configurations:

```bash
# Create a backup directory
sudo mkdir -p /backups/tacticalrmm

# Backup configuration files
sudo cp -r /rmm/api/tacticalrmm/tacticalrmm/local_settings.py /backups/tacticalrmm/
sudo cp -r /meshcentral/meshcentral-data/config.json /backups/tacticalrmm/
sudo cp -r /etc/nginx/sites-available/* /backups/tacticalrmm/

# Backup certificates if using Let's Encrypt
sudo cp -r /etc/letsencrypt /backups/tacticalrmm/
```

### Renewing Let's Encrypt Certificates

Let's Encrypt certificates expire after 90 days. To renew:

```bash
# Renew all certificates
sudo certbot renew

# Restart services to apply new certificates
sudo systemctl restart nginx meshcentral
```

### Log Management

Proper log management helps with troubleshooting and system health:

```bash
# Check and rotate TacticalRMM API logs
sudo find /rmm/api/tacticalrmm/tacticalrmm/private/log -type f -name "*.log" -size +100M -exec truncate -s 0 {} \;

# Check and rotate Celery logs
sudo find /var/log/celery -type f -name "*.log" -size +100M -exec truncate -s 0 {} \;

# Check Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Check MeshCentral logs
sudo journalctl -u meshcentral.service -f
```

## Troubleshooting

### Common Issues and Solutions

#### TacticalRMM Web UI Not Loading

1. Check if Nginx is running properly:
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

2. Check if frontend configuration is correct:
   ```bash
   sudo cat /etc/nginx/sites-available/frontend.conf
   ```

3. Check browser console for errors (F12 in most browsers)

#### Agent Connection Issues

1. Verify that NATS services are running:
   ```bash
   sudo systemctl status nats.service nats-api.service
   ```

2. Check NATS configuration:
   ```bash
   sudo cat /rmm/api/tacticalrmm/nats-rmm.conf
   ```

3. Test agent connectivity:
   ```bash
   # On agent machine
   ping nexus-api.icebrg.ai
   # Check certificate validation
   openssl s_client -connect nexus-api.icebrg.ai:443
   ```

#### MeshCentral Connection Issues

1. Check MeshCentral service:
   ```bash
   sudo systemctl status meshcentral
   ```

2. Verify MeshCentral configuration:
   ```bash
   sudo cat /meshcentral/meshcentral-data/config.json
   ```

3. Check MeshCentral logs:
   ```bash
   sudo journalctl -u meshcentral -n 100
   ```

#### Database Connection Issues

1. Test connection to Neon PostgreSQL database:
   ```bash
   # Install psql client if needed
   sudo apt install -y postgresql-client
   
   # Test connection using credentials from the install script
   PGPASSWORD=<database_password> psql -h <database_host> -U <database_user> -d tacticalrmm
   ```

### Service Recovery

If any service fails, follow these steps to recover:

```bash
# Check service logs to identify the issue
sudo journalctl -u [service_name] -n 100

# Restart the service
sudo systemctl restart [service_name]

# If the issue persists, try:
sudo systemctl stop [service_name]
sudo systemctl start [service_name]
```

For persistent issues, check configuration files for errors and consult the detailed logs.

## Advanced Configuration

### Modifying TacticalRMM Settings

The main TacticalRMM settings are stored in: `/rmm/api/tacticalrmm/tacticalrmm/local_settings.py`

To modify the configuration:

```bash
# Edit the settings file
sudo nano /rmm/api/tacticalrmm/tacticalrmm/local_settings.py

# After making changes, restart the services
sudo systemctl restart rmm.service daphne.service
```

Important settings you might want to modify:
- `DEBUG`: Set to `True` temporarily for detailed error information (not recommended in production)
- `CORS_ORIGIN_WHITELIST`: If you need to allow access from additional domains
- `ADMIN_ENABLED`: Enable the Django admin interface if needed

### Modifying MeshCentral Configuration

The MeshCentral configuration is stored in: `/meshcentral/meshcentral-data/config.json`

To modify the configuration:

```bash
# Edit the config file
sudo nano /meshcentral/meshcentral-data/config.json

# After making changes, restart MeshCentral
sudo systemctl restart meshcentral
```

Common settings to modify:
- `agentPing`: Change the interval for agent check-ins
- `allowHighQualityDesktop`: Enable/disable high-quality remote desktop
- `maxInvalidLogin`: Adjust brute-force protection settings

### Customizing the Frontend

The frontend files are located in: `/var/www/rmm/dist/`

To customize the frontend look or behavior:

```bash
# Make a backup first
sudo cp -r /var/www/rmm/dist /var/www/rmm/dist.bak

# Modify the required files
sudo nano /var/www/rmm/dist/env-config.js

# Ensure proper permissions
sudo chown www-data:www-data -R /var/www/rmm/dist
```

### Nginx Configuration

The Nginx configuration files are in: `/etc/nginx/sites-available/`

To modify Nginx settings:

```bash
# Edit the required configuration
sudo nano /etc/nginx/sites-available/rmm.conf
sudo nano /etc/nginx/sites-available/frontend.conf
sudo nano /etc/nginx/sites-available/meshcentral.conf

# Test the configuration
sudo nginx -t

# Apply changes
sudo systemctl reload nginx
```

### Managing Celery Workers

If you need to adjust the number of Celery workers or their behavior:

```bash
# Edit the Celery configuration
sudo nano /etc/conf.d/celery.conf

# Restart Celery services
sudo systemctl restart celery.service celerybeat.service
```

## System Updates and Maintenance

### Upgrading TacticalRMM

Use the update script to upgrade TacticalRMM to the latest version:

```bash
# Download the update script
wget https://raw.githubusercontent.com/ksingh-scogo/tacticalrmm/refs/heads/ksingh-v1.0.0/update.sh
chmod +x update.sh

# Run the update (follow the prompts)
./update.sh
```

### System Security Updates

Regularly update your system packages:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
```

### Database Maintenance

While the Neon cloud database is managed externally, you may want to perform some maintenance operations:

```bash
# Connect to the database using credentials from the install script
PGPASSWORD=<database_password> psql -h <database_host> -U <database_user> -d tacticalrmm

# Run ANALYZE to update statistics
ANALYZE;

# Check for bloated tables
SELECT schemaname, relname, n_dead_tup, n_live_tup, n_dead_tup / GREATEST(n_live_tup, 1)::float * 100 AS dead_percentage 
FROM pg_stat_user_tables 
WHERE n_dead_tup > 0 
ORDER BY dead_percentage DESC;

# Exit the database
\q
```

## Custom Development

### Working with the TacticalRMM API

If you need to develop custom integrations:

1. Activate the Python virtual environment:
   ```bash
   source /rmm/api/env/bin/activate
   ```

2. Navigate to the Django directory:
   ```bash
   cd /rmm/api/tacticalrmm
   ```

3. Use Django management commands:
   ```bash
   # List available commands
   python manage.py help
   
   # Create a Django shell
   python manage.py shell
   ```

4. Access the API directly:
   - API endpoint: `https://nexus-api.icebrg.ai/api/v3/`
   - Authentication: Bearer token (obtained via login)

### Adding Custom Scripts

Store custom scripts in the community scripts directory:

```bash
# Navigate to scripts directory
cd /opt/trmm-community-scripts

# Create a new script
nano my_custom_script.py

# Set proper permissions
chmod +x my_custom_script.py

# Register the script in TacticalRMM via the web UI (Scripts → Custom Scripts → Add)
```

## Security Considerations

### Hardening Your TacticalRMM Server

1. Configure firewall rules:
   ```bash
   sudo apt install -y ufw
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

2. Enable automatic security updates:
   ```bash
   sudo apt install -y unattended-upgrades
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```

3. Monitor login attempts:
   ```bash
   sudo apt install -y fail2ban
   sudo systemctl enable fail2ban
   sudo systemctl start fail2ban
   ```

### Two-Factor Authentication Management

If you lose access to your 2FA device:

1. Connect to the server
2. Access the Django shell:
   ```bash
   cd /rmm/api/tacticalrmm
   source /rmm/api/env/bin/activate
   python manage.py shell
   ```

3. Reset the 2FA for a user:
   ```python
   from accounts.models import User
   user = User.objects.get(username="your_username")
   user.totp_key = ""
   user.save()
   exit()
   ```

## Updating TacticalRMM

For updates, refer to the official TacticalRMM documentation at [https://github.com/ksingh-scogo/tacticalrmm](https://github.com/ksingh-scogo/tacticalrmm) 