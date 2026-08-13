#!/bin/bash
# ============================================================================
# KolkaUICameras - Installation Script for Debian
# ============================================================================

set -e

# Configuration
APP_NAME="KolkaUICameras"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="kolka-uicameras"
GUNICORN_PORT=5011
NGINX_PORT=8088
DB_NAME="phototrapdb"
DB_USER="postgres"
LOG_FILE="/var/log/${APP_NAME}_install.log"

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
echo "=== KolkaUICameras Installation Started: $(date) ===" > "$LOG_FILE"

echo ""
echo "=========================================="
echo "  KolkaUICameras Installation Script"
echo "=========================================="
echo ""

# ============================================================================
# Step 1: System preparation
# ============================================================================
print_status "Step 1: Preparing system..."

apt update -qq 2>&1 | tee -a "$LOG_FILE"
apt install -y -qq python3 python3-pip python3-venv python3-dev build-essential unzip postgresql-client libdbus-1-dev libglib2.0-dev network-manager ffmpeg 2>&1 | tee -a "$LOG_FILE"

print_success "System packages installed"

# ============================================================================
# Step 2: Check Python version
# ============================================================================
print_status "Step 2: Checking Python version..."

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [[ $PYTHON_MAJOR -lt 3 ]] || [[ $PYTHON_MAJOR -eq 3 && $PYTHON_MINOR -lt 10 ]]; then
    print_error "Python 3.10+ required. Found: $PYTHON_VERSION"
    exit 1
fi

print_success "Python version: $PYTHON_VERSION"

# ============================================================================
# Step 3: Create application directory
# ============================================================================
print_status "Step 3: Setting up application directory..."

if [[ -d "$APP_DIR" ]]; then
    print_warning "Existing installation found. Creating backup..."
    BACKUP_DIR="${APP_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    cp -r "$APP_DIR" "$BACKUP_DIR"
    print_success "Backup created: $BACKUP_DIR"
fi

mkdir -p "$APP_DIR"

print_success "Application directory ready: $APP_DIR"

# ============================================================================
# Step 4: Extract application files
# ============================================================================
print_status "Step 4: Extracting application files..."

APPZIP=""
# Find app.zip
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

# Extract to app directory
unzip -o -q "$APPZIP" -d "$APP_DIR" 2>&1 | tee -a "$LOG_FILE"

print_success "Application files extracted"

# ============================================================================
# Step 5: Create virtual environment
# ============================================================================
print_status "Step 5: Creating Python virtual environment..."

if [[ -d "$APP_DIR/venv" ]]; then
    print_warning "Old venv found, removing..."
    rm -rf "$APP_DIR/venv"
fi

python3 -m venv "$APP_DIR/venv" 2>&1 | tee -a "$LOG_FILE"

if [[ ! -f "$APP_DIR/venv/bin/python" ]]; then
    print_error "Failed to create virtual environment!"
    exit 1
fi

source "$APP_DIR/venv/bin/activate"

print_success "Virtual environment created"

# ============================================================================
# Step 6: Install dependencies
# ============================================================================
print_status "Step 6: Installing Python dependencies..."

PIPMIRRORS=(
    "https://mirror.yandex.ru/simple"
    "https://mirrors.aliyun.com/pypi/simple"
    "https://pypi.tuna.tsinghua.edu.cn/simple"
    "https://pypi.org/simple"
)
PIPOK=false
set +e
for mirror in "${PIPMIRRORS[@]}"; do
    print_status "  Trying mirror: ${mirror}..."
    pip install --upgrade pip --timeout 30 --retries 3 -i "${mirror}" 2>&1 | tee -a "$LOG_FILE"
    pip install -r "$APP_DIR/requirements.txt" --timeout 30 --retries 3 -i "${mirror}" 2>&1 | tee -a "$LOG_FILE"
    pip install gunicorn --timeout 30 --retries 3 -i "${mirror}" 2>&1 | tee -a "$LOG_FILE"
    if source "$APP_DIR/venv/bin/activate" && python3 -c "import flask; import psycopg2" 2>/dev/null; then
        PIPOK=true
        print_success "Dependencies installed from ${mirror}"
        break
    else
        print_warning "Mirror ${mirror} failed or incomplete, trying next..."
    fi
done
set -e

if [[ "$PIPOK" != "true" ]]; then
    print_warning "All PyPI mirrors failed. Trying system packages as fallback..."
    apt install -y python3-psycopg2 python3-flask python3-flask-sqlalchemy python3-dotenv python3-werkzeug python3-gunicorn 2>&1 | tee -a "$LOG_FILE" || true

    # Try additional packages (may not exist in all repos)
    set +e
    apt install -y python3-bleak python3-asyncpg 2>&1 | tee -a "$LOG_FILE"
    set -e

    # Try to recreate venv with system site-packages
    python3 -m venv --system-site-packages "$APP_DIR/venv" 2>&1 | tee -a "$LOG_FILE"
    if [[ -f "$APP_DIR/venv/bin/python3" ]]; then
        print_success "venv recreated with system packages"
    else
        print_warning "venv creation failed, falling back to system python"
        rm -rf "$APP_DIR/venv"
        mkdir -p "$APP_DIR/venv/bin"
        ln -sf /usr/bin/python3 "$APP_DIR/venv/bin/python3"
        ln -sf /usr/bin/python3 "$APP_DIR/venv/bin/python"
        ln -sf /usr/bin/pip3 "$APP_DIR/venv/bin/pip"
        # Create minimal activate script
        cat > "$APP_DIR/venv/bin/activate" << 'ACTIVATE'
# Minimal activate for system python fallback
ACTIVATE
    fi

    source "$APP_DIR/venv/bin/activate"

    # Verify critical imports
    "$APP_DIR/venv/bin/python3" -c "import flask; import psycopg2" 2>&1 | tee -a "$LOG_FILE" || {
        print_error "Critical dependencies missing. Install manually:"
        echo "  apt install python3-flask python3-psycopg2"
        exit 1
    }
    print_success "Dependencies installed from system packages"
fi

# ============================================================================
# Step 7: Configure application
# ============================================================================
print_status "Step 7: Configuring application..."

DB_PASSWORD="12345678"
DATABASE_URL="postgresql://postgres:${DB_PASSWORD}@localhost/${DB_NAME}"

cat > "$APP_DIR/.env" << EOF
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
DATABASE_URL=${DATABASE_URL}
FLASK_ENV=production
EOF

chmod 600 "$APP_DIR/.env"

print_success "Application configured"

# ============================================================================
# Step 7.1: Create database and tables
# ============================================================================
print_status "Step 7.1: Setting up database..."

# Check if PostgreSQL is running
if ! systemctl is-active --quiet postgresql; then
    print_warning "PostgreSQL is not running. Starting..."
    systemctl start postgresql
fi

# Set postgres user password
PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U postgres -c "ALTER USER postgres WITH PASSWORD '${DB_PASSWORD}';" 2>&1 | tee -a "$LOG_FILE" || true

# Create database if not exists
DB_EXISTS=$(PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null)
if [[ "$DB_EXISTS" != "1" ]]; then
    print_status "Creating database ${DB_NAME}..."
    PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U postgres -c "CREATE DATABASE ${DB_NAME};" 2>&1 | tee -a "$LOG_FILE"
    print_success "Database created"
else
    print_success "Database ${DB_NAME} already exists"
fi

# Run SQL scripts if they exist
SQL_DIR="$APP_DIR/sql"
if [[ -d "$SQL_DIR" ]]; then
    if [[ -f "$SQL_DIR/sql.sql" ]]; then
        print_status "Creating tables..."
        PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U postgres -d "${DB_NAME}" -f "$SQL_DIR/sql.sql" 2>&1 | tee -a "$LOG_FILE" || true
        print_success "Tables created"
    fi
    if [[ -f "$SQL_DIR/sql_config_insert.sql" ]]; then
        print_status "Inserting default config..."
        PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U postgres -d "${DB_NAME}" -f "$SQL_DIR/sql_config_insert.sql" 2>&1 | tee -a "$LOG_FILE" || true
        print_success "Default config inserted"
    fi
else
    print_warning "SQL directory not found at $SQL_DIR, skipping table creation"
fi

print_success "Database setup complete"

# ============================================================================
# Step 8: Create systemd service
# ============================================================================
print_status "Step 8: Creating systemd service..."

cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=KolkaUICameras Flask Application (Gunicorn)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/gunicorn \\
    --workers 4 \\
    --worker-class sync \\
    --bind 127.0.0.1:$GUNICORN_PORT \\
    --access-logfile - \\
    --error-logfile - \\
    --capture-output \\
    --timeout 120 \\
    app:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

print_success "Systemd service created"

# ============================================================================
# Step 9: Configure Nginx
# ============================================================================
print_status "Step 9: Configuring Nginx..."

cat > "/etc/nginx/sites-available/${SERVICE_NAME}" << EOF
server {
    listen $NGINX_PORT;
    server_name _;

    access_log /var/log/nginx/${SERVICE_NAME}_access.log;
    error_log /var/log/nginx/${SERVICE_NAME}_error.log;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:$GUNICORN_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /static/ {
        alias $APP_DIR/static/;
        expires 7d;
    }
}
EOF

ln -sf "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-enabled/${SERVICE_NAME}"
#rm -f /etc/nginx/sites-enabled/default

nginx -t 2>&1 | tee -a "$LOG_FILE" || { print_error "Nginx config failed"; exit 1; }

print_success "Nginx configured"

# ============================================================================
# Step 10: Create directories and set permissions
# ============================================================================
print_status "Step 10: Creating directories and setting permissions..."

# Create images directory
mkdir -p "$APP_DIR/images"
chown -R www-data:www-data "$APP_DIR"
chmod -R 750 "$APP_DIR"

print_success "Directories created and permissions set"

# ============================================================================
# Step 11: Test database connection
# ============================================================================
print_status "Step 11: Testing database connection..."

source "$APP_DIR/venv/bin/activate"
python3 -c "
import sys
sys.path.insert(0, '$APP_DIR')
from app import app, db
with app.app_context():
    try:
        db.engine.connect()
        print('Database connection successful')
    except Exception as e:
        print(f'Database connection failed: {e}')
        sys.exit(1)
" 2>&1 | tee -a "$LOG_FILE" || {
    print_error "Cannot connect to database. Check PostgreSQL is running and credentials are correct."
    echo "Edit $APP_DIR/.env and try again."
    exit 1
}

print_success "Database connection OK"

# ============================================================================
# Step 12: Verify required files
# ============================================================================
print_status "Step 12: Verifying required files..."

REQUIRED_DIRS="routes templates static static/css static/js"
for d in $REQUIRED_DIRS; do
    if [[ -d "$APP_DIR/$d" ]]; then
        print_success "Directory exists: $d/"
    else
        print_error "Required directory missing: $d/"
        exit 1
    fi
done

REQUIRED_FILES="app.py config.py models.py calibration.py config_loader.py kolka_snapshot_and_download.py compress_images.py routes/__init__.py routes/auth.py routes/page.py routes/api_traps.py routes/api_downloads.py routes/api_snapshots.py routes/api_config.py routes/api_stats.py routes/api_users.py routes/api_database.py routes/api_calibration.py routes/api_snapshot_download.py static/js/bootstrap.bundle.min.js static/js/app.js"
for f in $REQUIRED_FILES; do
    if [[ -f "$APP_DIR/$f" ]]; then
        print_success "File exists: $f"
    else
        print_error "Required file missing: $f"
        exit 1
    fi
done

print_success "All required files present"

# ============================================================================
# Step 13: Start services
# ============================================================================
print_status "Step 13: Starting services..."

systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"
systemctl restart nginx

print_success "Services started"

# ============================================================================
# Step 14: Verify
# ============================================================================
print_status "Step 14: Verifying installation..."

sleep 3

if systemctl is-active --quiet "${SERVICE_NAME}"; then
    print_success "Application service is running"
else
    print_error "Application service failed to start"
    echo "Check: journalctl -u ${SERVICE_NAME} -n 50"
    exit 1
fi

# ============================================================================
# Complete
# ============================================================================
echo ""
echo "=========================================="
echo -e "${GREEN}  Installation Complete!${NC}"
echo "=========================================="
echo ""
echo "Application: http://$(hostname -I | awk '{print $1}'):$NGINX_PORT"
echo ""
echo "Default credentials: admin / admin123"
echo ""
echo "Commands:"
echo "  sudo systemctl status $SERVICE_NAME"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo "  sudo $APP_DIR/verify-KolkaUICameras.sh"
echo ""
echo "Log: $LOG_FILE"
echo "=========================================="

log "Installation completed successfully"
