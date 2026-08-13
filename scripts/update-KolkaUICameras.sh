#!/bin/bash
# ============================================================================
# KolkaUICameras - Update Script for Debian
# ============================================================================

set -e

# Configuration
APP_NAME="KolkaUICameras"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="kolka-uicameras"
BACKUP_DIR="/opt/${APP_NAME}_backups"
LOG_FILE="/var/log/${APP_NAME}_update.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_status() { echo -e "${CYAN}[INFO]${NC} $1"; log "INFO: $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; log "OK: $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; log "WARN: $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; log "ERROR: $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

mkdir -p /var/log
echo "=== KolkaUICameras Update Started: $(date) ===" > "$LOG_FILE"

echo ""
echo "=========================================="
echo "  KolkaUICameras Update Script"
echo "=========================================="
echo ""

# ============================================================================
# Step 1: Find app.zip
# ============================================================================
print_status "Step 1: Looking for app.zip..."

APPZIP=""
for location in "/root" "/tmp" "/opt" "$APP_DIR"; do
    if [[ -f "$location/app.zip" ]]; then
        APPZIP="$location/app.zip"
        break
    fi
done

if [[ -z "$APPZIP" ]]; then
    print_error "app.zip not found!"
    echo "Please place app.zip in /root, /tmp, or /opt"
    exit 1
fi

print_status "Found: $APPZIP"

# ============================================================================
# Step 2: Create backup
# ============================================================================
print_status "Step 2: Creating backup..."

mkdir -p "$BACKUP_DIR"
BACKUP_PATH="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_PATH"

# Save current files
for f in app.py config.py models.py calibration.py config_loader.py requirements.txt appsettings.json .env; do
    cp "$APP_DIR/$f" "$BACKUP_PATH/" 2>/dev/null || true
done
cp -r "$APP_DIR/routes" "$BACKUP_PATH/" 2>/dev/null || true
cp -r "$APP_DIR/templates" "$BACKUP_PATH/" 2>/dev/null || true
cp -r "$APP_DIR/static" "$BACKUP_PATH/" 2>/dev/null || true

print_success "Backup created: $BACKUP_PATH"

# ============================================================================
# Step 3: Stop application
# ============================================================================
print_status "Step 3: Stopping application..."

systemctl stop "$SERVICE_NAME" 2>/dev/null || true

print_success "Application stopped"

# ============================================================================
# Step 4: Extract update
# ============================================================================
print_status "Step 4: Extracting update files..."

# Save .env
cp "$APP_DIR/.env" "/tmp/kolka_env_backup" 2>/dev/null || true

# Extract
unzip -o -q "$APPZIP" -d "$APP_DIR" 2>&1 | tee -a "$LOG_FILE"

# Restore .env
cp "/tmp/kolka_env_backup" "$APP_DIR/.env" 2>/dev/null || true
rm -f /tmp/kolka_env_backup

print_success "Update files extracted"

# ============================================================================
# Step 5: Update dependencies
# ============================================================================
print_status "Step 5: Updating Python dependencies..."

source "$APP_DIR/venv/bin/activate"
pip install --upgrade pip 2>&1 | tee -a "$LOG_FILE"
pip install -r "$APP_DIR/requirements.txt" 2>&1 | tee -a "$LOG_FILE"

print_success "Dependencies updated"

# ============================================================================
# Step 6: Set permissions and start
# ============================================================================
print_status "Step 6: Setting permissions and starting..."

chown -R www-data:www-data "$APP_DIR"
chmod -R 750 "$APP_DIR"

systemctl daemon-reload
systemctl start "$SERVICE_NAME"
systemctl reload nginx 2>/dev/null || true

print_success "Application started"

# ============================================================================
# Step 7: Verify
# ============================================================================
print_status "Step 7: Verifying update..."

sleep 3

if systemctl is-active --quiet "${SERVICE_NAME}"; then
    print_success "Application is running"
else
    print_error "Application failed to start!"
    echo "To rollback: sudo cp -r $BACKUP_PATH/* $APP_DIR/"
    exit 1
fi

# Cleanup old backups (keep 5)
cd "$BACKUP_DIR" 2>/dev/null && ls -dt */ 2>/dev/null | tail -n +6 | xargs rm -rf 2>/dev/null || true

# ============================================================================
# Complete
# ============================================================================
echo ""
echo "=========================================="
echo -e "${GREEN}  Update Complete!${NC}"
echo "=========================================="
echo ""
echo "Application: http://$(hostname -I | awk '{print $1}'):8088"
echo ""
echo "Backup: $BACKUP_PATH"
echo "Rollback: sudo cp -r $BACKUP_PATH/* $APP_DIR/ && sudo systemctl restart $SERVICE_NAME"
echo ""
echo "Log: $LOG_FILE"
echo "=========================================="

log "Update completed successfully"
