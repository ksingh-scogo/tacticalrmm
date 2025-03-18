#!/usr/bin/env bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_green() {
  printf >&2 "${GREEN}%0.s-${NC}" {1..80}
  printf >&2 "\n"
  printf >&2 "${GREEN}${1}${NC}\n"
  printf >&2 "${GREEN}%0.s-${NC}" {1..80}
  printf >&2 "\n"
}

print_yellow() {
  printf >&2 "${YELLOW}${1}${NC}\n"
}

print_red() {
  printf >&2 "${RED}${1}${NC}\n"
}

# Check if script is being run as root
if [ $EUID -eq 0 ]; then
  print_red "Do NOT run this script as root. Exiting."
  exit 1
fi

print_green "Starting Tactical RMM uninstallation"

# 1. Stop and disable all services
print_green "Stopping and disabling services"
sudo systemctl stop meshcentral nats-api nats celerybeat celery daphne rmm nginx redis-server
sudo systemctl disable meshcentral nats-api nats celerybeat celery daphne rmm nginx redis-server

# 2. Remove systemd service files
print_green "Removing systemd service files"
sudo rm -f /etc/systemd/system/rmm.service
sudo rm -f /etc/systemd/system/daphne.service
sudo rm -f /etc/systemd/system/nats.service
sudo rm -f /etc/systemd/system/nats-api.service
sudo rm -f /etc/systemd/system/celery.service
sudo rm -f /etc/systemd/system/celerybeat.service
sudo rm -f /etc/systemd/system/meshcentral.service
sudo systemctl daemon-reload

# 3. Remove Nginx configurations
print_green "Removing Nginx configurations"
sudo rm -f /etc/nginx/sites-enabled/rmm.conf
sudo rm -f /etc/nginx/sites-enabled/meshcentral.conf
sudo rm -f /etc/nginx/sites-enabled/frontend.conf
sudo rm -f /etc/nginx/sites-available/rmm.conf
sudo rm -f /etc/nginx/sites-available/meshcentral.conf
sudo rm -f /etc/nginx/sites-available/frontend.conf
sudo rm -f /etc/nginx/nginx.conf.bak
# If the script created a custom nginx.conf, restore the original if backup exists
if [ -f /etc/nginx/nginx.conf.bak ]; then
  sudo mv /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
fi

# 4. Clean up directories
print_green "Removing application directories"
sudo rm -rf /rmm
sudo rm -rf /meshcentral
sudo rm -rf /opt/tactical
sudo rm -rf /var/www/rmm
sudo rm -rf /var/log/celery
sudo rm -rf /etc/conf.d
sudo rm -rf /opt/trmm-community-scripts
sudo rm -rf /meshcentral/meshcentral-data
sudo rm -rf /meshcentral/meshcentral-files
sudo rm -rf /meshcentral/meshcentral-backups
sudo rm -rf /meshcentral/meshcentral-recordings
sudo rm -rf /meshcentral/node_modules
sudo rm -f /meshcentral/package.json

# 5. Remove binary files
print_green "Removing binary files"
sudo rm -f /usr/local/bin/nats-server
sudo rm -f /usr/local/bin/nats-api

# 6. Clean up hosts file if entries exist
print_green "Cleaning up hosts file"
HOSTS_FILE="/etc/hosts"

if [ -f "$HOSTS_FILE" ]; then
  print_yellow "Removing any Tactical RMM entries from hosts file..."
  # Make a backup of hosts file
  sudo cp $HOSTS_FILE ${HOSTS_FILE}.bak
  
  # Remove any 127.0.1.1 line containing rmm, mesh or api subdomains
  sudo sed -i '/127\.0\.1\.1.*\(rmm\|mesh\|api\)/d' $HOSTS_FILE
fi

# 7. Reset system limits modified for MeshCentral
print_green "Reverting system limit changes"
if grep -q "fs.file-max = 100000" /etc/sysctl.conf; then
  sudo sed -i '/fs.file-max = 100000/d' /etc/sysctl.conf
fi

if grep -q "* soft nofile 100000" /etc/security/limits.conf; then
  sudo sed -i '/* soft nofile 100000/d' /etc/security/limits.conf
fi

if grep -q "* hard nofile 100000" /etc/security/limits.conf; then
  sudo sed -i '/* hard nofile 100000/d' /etc/security/limits.conf
fi

# Check for and remove session limits entry
if grep -q "session required pam_limits.so" /etc/pam.d/common-session; then
  sudo sed -i '/session required pam_limits.so/d' /etc/pam.d/common-session
fi

# 8. Remove certificates
print_green "Cleaning up certificates"
# Remove Let's Encrypt certificates if they exist
if [ -d "/etc/letsencrypt/live" ]; then
  print_yellow "Found Let's Encrypt certificates. Do you want to remove them? [y/N]"
  read -r remove_certs
  if [[ "$remove_certs" =~ ^[Yy]$ ]]; then
    print_green "Removing Let's Encrypt certificates"
    # Get all certificate names from the live directory
    CERT_NAMES=$(sudo find /etc/letsencrypt/live -mindepth 1 -maxdepth 1 -type d -not -path "*/\.*" | xargs -n1 basename 2>/dev/null || echo "")
    
    if [ -n "$CERT_NAMES" ]; then
      for cert_name in $CERT_NAMES; do
        print_yellow "Deleting certificate: $cert_name"
        sudo certbot delete --cert-name "$cert_name" --non-interactive || true
      done
    fi
    
    # To be thorough, remove the entire letsencrypt directory
    print_yellow "Removing the entire letsencrypt directory for complete cleanup"
    sudo rm -rf /etc/letsencrypt
  else
    print_yellow "Skipping Let's Encrypt certificate removal"
  fi
fi

# Remove self-signed certificates if they exist
if [ -d "/etc/ssl/tactical" ]; then
  print_green "Removing self-signed certificates"
  sudo rm -rf /etc/ssl/tactical
fi

# 9. Clean up package sources
print_green "Cleaning up package sources"
# Remove Nginx repository
if [ -f /etc/apt/sources.list.d/nginx.list ]; then
  sudo rm -f /etc/apt/sources.list.d/nginx.list
  sudo rm -f /etc/apt/keyrings/nginx-archive-keyring.gpg
fi

# Remove Node.js repository
if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
  sudo rm -f /etc/apt/sources.list.d/nodesource.list
  sudo rm -f /etc/apt/keyrings/nodesource.gpg
fi

# Remove PostgreSQL repository
if [ -f /etc/apt/sources.list.d/pgdg.list ]; then
  sudo rm -f /etc/apt/sources.list.d/pgdg.list
  sudo rm -f /etc/apt/keyrings/postgresql-archive-keyring.gpg
fi

# 10. Reset cloud-init configuration if modified
print_green "Checking for cloud-init configuration changes"
if [ -f /etc/cloud/cloud.cfg ]; then
  if grep -q "manage_etc_hosts: false" /etc/cloud/cloud.cfg; then
    print_yellow "Reverting cloud-init hosts management configuration"
    sudo sed -i '/manage_etc_hosts: false/d' /etc/cloud/cloud.cfg
    sudo systemctl restart cloud-init >/dev/null 2>&1 || true
  fi
fi

# 11. Remove any Python virtual environment
print_green "Removing Python virtual environment"
if [ -d "/rmm/api/env" ]; then
  sudo rm -rf /rmm/api/env
fi

# 12. Clean up any temporary files
print_green "Cleaning up temporary files"
rm -rf ~/Python-3.11.*

# 13. Optional: uninstall packages
print_yellow "Do you want to uninstall installed packages? (nginx, redis, nodejs, git, certbot) [y/N]"
read -r uninstall_pkgs

if [[ "$uninstall_pkgs" =~ ^[Yy]$ ]]; then
  print_green "Uninstalling packages"
  sudo apt remove -y nginx redis nodejs certbot git
  sudo apt autoremove -y
fi

# 15. Clean npm cache directories if npm was used
print_green "Cleaning up npm cache"
if command -v npm &> /dev/null; then
  npm cache clean --force || true
fi

# 16. Restore original PAM configuration if modified
if [ -f /etc/pam.d/common-session.bak ]; then
  sudo mv /etc/pam.d/common-session.bak /etc/pam.d/common-session
fi

# 17. Apply system changes
print_green "Applying system changes"
sudo sysctl -p || true

print_green "Uninstallation completed successfully"
print_yellow "Your system has been cleaned of all Tactical RMM components"
print_yellow "You can now re-run the install_ext_pgdb.sh script for a fresh installation" 