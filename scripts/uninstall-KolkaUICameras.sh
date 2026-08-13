#!/bin/bash
# ============================================================================
# KolkaUICameras - Uninstall Script for Debian
# Stops services, removes nginx config, drops database, deletes application files
# ============================================================================

set -e

# Configuration
APP_NAME="KolkaUICameras"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="kolka-uicameras"
DB_NAME="phototrapdb"
DB_USER="postgres"
DB_PASSWORD="12345678"
LOG_FILE="/var/log/${APP_NAME}_uninstall.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_status() {
    echo -e "${CYAN}[INFO]${NC} $1"
    log "INFO: $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
    log "OK: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log "WARN: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

# Check root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Initialize log
mkdir -p /var/log
echo "=== KolkaUICameras Uninstall Started: $(date) ===" > "$LOG_FILE"

echo ""
echo "=========================================="
echo "  KolkaUICameras Uninstall Script"
echo "=========================================="
echo ""
echo "This will remove:"
echo "  - systemd service: $SERVICE_NAME"
echo "  - nginx config:    $SERVICE_NAME"
echo "  - database:        $DB_NAME"
echo "  - application:     $APP_DIR"
echo "  - install log:     /var/log/${APP_NAME}_install.log"
echo ""
read -p "Are you sure? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# ============================================================================
# Step 1: Stop and disable service
# ============================================================================
print_status "Step 1: Stopping and disabling service..."

if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME"
    print_success "Service stopped"
else
    print_warning "Service $SERVICE_NAME is not running"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl disable "$SERVICE_NAME"
    print_success "Service disabled"
else
    print_warning "Service $SERVICE_NAME is not enabled"
fi

# ============================================================================
# Step 2: Remove systemd service file
# ============================================================================
print_status "Step 2: Removing systemd service..."

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [[ -f "$SERVICE_FILE" ]]; then
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    print_success "Service file removed: $SERVICE_FILE"
else
    print_warning "Service file not found: $SERVICE_FILE"
fi

# ============================================================================
# Step 3: Remove nginx config
# ============================================================================
print_status "Step 3: Removing nginx configuration..."

NGINX_AVAILABLE="/etc/nginx/sites-available/${SERVICE_NAME}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${SERVICE_NAME}"

rm -f "$NGINX_ENABLED"
if [[ -f "$NGINX_AVAILABLE" ]]; then
    rm -f "$NGINX_AVAILABLE"
    print_success "Nginx config removed: $NGINX_AVAILABLE"
else
    print_warning "Nginx config not found: $NGINX_AVAILABLE"
fi

# Reload nginx if it is running
if systemctl is-active --quiet nginx 2>/dev/null; then
    nginx -t 2>&1 | tee -a "$LOG_FILE" && systemctl reload nginx
    print_success "Nginx reloaded"
else
    print_warning "Nginx is not running, skip reload"
fi

# ============================================================================
# Step 4: Drop database
# ============================================================================
print_status "Step 4: Dropping database $DB_NAME..."

if systemctl is-active --quiet postgresql 2>/dev/null; then
    DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null || echo "")
    if [[ "$DB_EXISTS" == "1" ]]; then
        # Terminate active connections to the database
        sudo -u postgres psql -c "
            SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();
        " 2>&1 | tee -a "$LOG_FILE" || true

        sudo -u postgres psql -c "DROP DATABASE ${DB_NAME};" 2>&1 | tee -a "$LOG_FILE"
        print_success "Database $DB_NAME dropped"
    else
        print_warning "Database $DB_NAME does not exist"
    fi
else
    print_warning "PostgreSQL is not running, cannot drop database"
fi

# ============================================================================
# Step 5: Remove application directory
# ============================================================================
print_status "Step 5: Removing application directory..."

if [[ -d "$APP_DIR" ]]; then
    rm -rf "$APP_DIR"
    print_success "Removed: $APP_DIR"
else
    print_warning "Directory not found: $APP_DIR"
fi

# ============================================================================
# Step 6: Remove backup directories (if any)
# ============================================================================
print_status "Step 6: Cleaning up backups..."

BACKUP_COUNT=0
for dir in /opt/${APP_NAME}_backup_*; do
    if [[ -d "$dir" ]]; then
        rm -rf "$dir"
        print_success "Removed backup: $dir"
        ((BACKUP_COUNT++))
    fi
done

if [[ $BACKUP_COUNT -eq 0 ]]; then
    print_warning "No backup directories found"
fi

# ============================================================================
# Step 7: Remove logs
# ============================================================================
print_status "Step 7: Cleaning up logs..."

for logfile in "/var/log/${APP_NAME}_install.log" "/var/log/${APP_NAME}_update.log"; do
    if [[ -f "$logfile" ]]; then
        rm -f "$logfile"
        print_success "Removed: $logfile"
    fi
done

# Remove nginx logs
for logfile in /var/log/nginx/${SERVICE_NAME}_access.log /var/log/nginx/${SERVICE_NAME}_error.log; do
    if [[ -f "$logfile" ]]; then
        rm -f "$logfile"
        print_success "Removed: $logfile"
    fi
done

# ============================================================================
# Complete
# ============================================================================
echo ""
echo "=========================================="
echo -e "${GREEN}  Uninstall Complete!${NC}"
echo "=========================================="
echo ""
echo "Removed:"
echo "  - systemd service: $SERVICE_NAME"
echo "  - nginx config:    $SERVICE_NAME"
echo "  - database:        $DB_NAME"
echo "  - application:     $APP_DIR"
echo ""
echo "Note: System packages (python3, postgresql, nginx, ffmpeg)"
echo "      were NOT removed. Remove manually if needed:"
echo "      apt remove network-manager ffmpeg"
echo ""
echo "Log: $LOG_FILE"
echo "=========================================="

log "Uninstall completed successfully"
