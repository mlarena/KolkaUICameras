#!/bin/bash
# ============================================================================
# KolkaUICameras - System Verification Script
# ============================================================================

# Configuration
APP_NAME="KolkaUICameras"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="kolka-uicameras"
GUNICORN_PORT=5011
NGINX_PORT=8088

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
WARN=0

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASS++))
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAIL++))
}

check_warn() {
    echo -e "  ${YELLOW}!${NC} $1"
    ((WARN++))
}

echo ""
echo "=========================================="
echo "  KolkaUICameras System Verification"
echo "=========================================="
echo ""

# ============================================================================
# 1. File System - Core
# ============================================================================
echo -e "${CYAN}[1] File System (Core)${NC}"

if [[ -d "$APP_DIR" ]]; then
    check_pass "Application directory exists: $APP_DIR"
else
    check_fail "Application directory not found: $APP_DIR"
fi

for f in app.py config.py models.py calibration.py config_loader.py requirements.txt appsettings.json; do
    if [[ -f "$APP_DIR/$f" ]]; then
        check_pass "File exists: $f"
    else
        check_fail "File missing: $f"
    fi
done

# ============================================================================
# 2. File System - Routes
# ============================================================================
echo ""
echo -e "${CYAN}[2] File System (Routes)${NC}"

if [[ -d "$APP_DIR/routes" ]]; then
    check_pass "Directory exists: routes/"
else
    check_fail "Directory missing: routes/"
fi

for f in __init__.py auth.py page.py api_traps.py api_downloads.py api_snapshots.py api_calibration.py api_config.py api_stats.py api_users.py api_database.py; do
    if [[ -f "$APP_DIR/routes/$f" ]]; then
        check_pass "File exists: routes/$f"
    else
        check_fail "File missing: routes/$f"
    fi
done

# ============================================================================
# 3. File System - Templates & Static
# ============================================================================
echo ""
echo -e "${CYAN}[3] File System (Templates & Static)${NC}"

for d in templates static static/css static/js static/css/font; do
    if [[ -d "$APP_DIR/$d" ]]; then
        check_pass "Directory exists: $d/"
    else
        check_fail "Directory missing: $d/"
    fi
done

for f in templates/base.html templates/dashboard.html templates/login.html; do
    if [[ -f "$APP_DIR/$f" ]]; then
        check_pass "File exists: $f"
    else
        check_fail "File missing: $f"
    fi
done

for f in static/css/bootstrap.min.css static/css/bootstrap-icons.css static/css/styles.css static/js/bootstrap.bundle.min.js static/js/app.js static/js/traps.js static/js/downloads.js static/js/snapshots.js static/js/calibration.js static/js/config.js static/js/users.js static/js/database.js; do
    if [[ -f "$APP_DIR/$f" ]]; then
        check_pass "File exists: $f"
    else
        check_fail "File missing: $f"
    fi
done

# ============================================================================
# 4. Python Environment
# ============================================================================
echo ""
echo -e "${CYAN}[4] Python Environment${NC}"

if [[ -d "$APP_DIR/venv" ]]; then
    check_pass "Virtual environment exists"
else
    check_fail "Virtual environment not found"
fi

if [[ -f "$APP_DIR/venv/bin/python" ]]; then
    PY_VERSION=$("$APP_DIR/venv/bin/python" --version 2>&1)
    check_pass "Python available: $PY_VERSION"
else
    check_fail "Python not found in venv"
fi

if [[ -f "$APP_DIR/venv/bin/pip" ]]; then
    check_pass "pip available"
else
    check_fail "pip not found in venv"
fi

# Check installed packages
source "$APP_DIR/venv/bin/activate" 2>/dev/null
for pkg in flask flask-sqlalchemy flask-jwt-extended psycopg2-binary gunicorn bleak asyncpg; do
    if pip show "$pkg" &>/dev/null; then
        check_pass "Package installed: $pkg"
    else
        check_fail "Package missing: $pkg"
    fi
done

# ============================================================================
# 5. Systemd Service
# ============================================================================
echo ""
echo -e "${CYAN}[5] Systemd Service${NC}"

if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
    check_pass "Service file exists"
else
    check_fail "Service file not found"
fi

if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
    check_pass "Service is enabled"
else
    check_warn "Service is not enabled"
fi

if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    check_pass "Service is running"
else
    check_fail "Service is not running"
fi

# ============================================================================
# 6. Ports
# ============================================================================
echo ""
echo -e "${CYAN}[6] Ports${NC}"

if ss -tlnp | grep -q ":${GUNICORN_PORT}"; then
    check_pass "Gunicorn listening on port $GUNICORN_PORT"
else
    check_fail "Gunicorn not listening on port $GUNICORN_PORT"
fi

if ss -tlnp | grep -q ":${NGINX_PORT}"; then
    check_pass "Nginx listening on port $NGINX_PORT"
else
    check_fail "Nginx not listening on port $NGINX_PORT"
fi

# ============================================================================
# 7. Nginx
# ============================================================================
echo ""
echo -e "${CYAN}[7] Nginx${NC}"

if [[ -f "/etc/nginx/sites-available/${SERVICE_NAME}" ]]; then
    check_pass "Nginx config exists"
else
    check_fail "Nginx config not found"
fi

if [[ -L "/etc/nginx/sites-enabled/${SERVICE_NAME}" ]]; then
    check_pass "Nginx config enabled"
else
    check_warn "Nginx config not enabled"
fi

if nginx -t 2>&1 | grep -q "successful"; then
    check_pass "Nginx config valid"
else
    check_fail "Nginx config invalid"
fi

# ============================================================================
# 8. HTTP Test
# ============================================================================
echo ""
echo -e "${CYAN}[8] HTTP Test${NC}"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${NGINX_PORT}/" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
    check_pass "HTTP response: $HTTP_CODE"
else
    check_fail "HTTP response: $HTTP_CODE (expected 200 or 302)"
fi

# ============================================================================
# 9. Database Connection
# ============================================================================
echo ""
echo -e "${CYAN}[9] Database Connection${NC}"

if PGPASSWORD=$(grep DATABASE_URL "$APP_DIR/.env" 2>/dev/null | cut -d@ -f1 | cut -d: -f3) psql -h localhost -U postgres -d phototrapdb -c "SELECT 1" &>/dev/null; then
    check_pass "Database connection OK"

    # Check tables
    TABLES=$(PGPASSWORD=$(grep DATABASE_URL "$APP_DIR/.env" 2>/dev/null | cut -d@ -f1 | cut -d: -f3) psql -h localhost -U postgres -d phototrapdb -tAc "SELECT tablename FROM pg_tables WHERE schemaname='public'" 2>/dev/null)
    for tbl in PhotoTrap DownloadLog SnapshotLog CalibrationLog PhotoTrapConfig users; do
        if echo "$TABLES" | grep -q "$tbl"; then
            check_pass "Table exists: $tbl"
        else
            check_fail "Table missing: $tbl"
        fi
    done
else
    check_warn "Could not test database connection (may need password)"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "=========================================="
echo "  Results"
echo "=========================================="
echo ""
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${YELLOW}Warnings: $WARN${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}System is healthy!${NC}"
else
    echo -e "${RED}Issues found. Please check the failures above.${NC}"
fi
echo ""
echo "=========================================="
