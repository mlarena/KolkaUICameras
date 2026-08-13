# KolkaUICameras - Deployment Scripts

## Requirements

- Debian 11/12 server
- PostgreSQL installed and configured
- Nginx installed
- Database `phototrapdb` already created with tables and data

## Files in Archive

The `KolkaUICameras.zip` archive contains:

```
KolkaUICameras/
├── app.zip
│   ├── app.py
│   ├── config.py
│   ├── models.py
│   ├── calibration.py
│   ├── config_loader.py
│   ├── appsettings.json
│   ├── requirements.txt
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── page.py
│   │   ├── api_traps.py
│   │   ├── api_downloads.py
│   │   ├── api_snapshots.py
│   │   ├── api_calibration.py
│   │   ├── api_config.py
│   │   ├── api_stats.py
│   │   ├── api_users.py
│   │   └── api_database.py
│   ├── templates/
│   │   ├── base.html
│   │   ├── dashboard.html
│   │   └── login.html
│   ├── static/
│   │   ├── css/
│   │   │   ├── bootstrap.min.css
│   │   │   ├── bootstrap-icons.css
│   │   │   ├── flatpickr.min.css
│   │   │   ├── styles.css
│   │   │   └── font/
│   │   └── js/
│   │       ├── bootstrap.bundle.min.js
│   │       ├── app.js
│   │       ├── traps.js
│   │       ├── downloads.js
│   │       ├── snapshots.js
│   │       ├── calibration.js
│   │       ├── config.js
│   │       ├── users.js
│   │       ├── database.js
│   │       ├── flatpickr.min.js
│   │       └── ru.js
│   └── sql/
│       ├── sql.sql
│       └── sql_config_insert.sql
├── install-KolkaUICameras.sh
├── update-KolkaUICameras.sh
└── verify-KolkaUICameras.sh
```

## Deployment Process

### Step 1: Build Package (Windows)

Run from the project root directory:

```powershell
.\scripts\build-package.ps1
```

This creates `KolkaUICameras.zip` in the project root.

### Step 2: Upload to Server

Upload the zip file to the server:

```bash
scp KolkaUICameras.zip root@server:/root/
```

### Step 3: Install

SSH into the server and run:

```bash
cd /root
unzip KolkaUICameras.zip -d /opt/KolkaUICameras
chmod +x /opt/KolkaUICameras/*.sh
sudo /opt/KolkaUICameras/install-KolkaUICameras.sh
```

### Step 4: Update

For subsequent updates:

1. Build new package on Windows: `.\scripts\build-package.ps1`
2. Upload `KolkaUICameras.zip` to server
3. Run update script:

```bash
sudo /opt/KolkaUICameras/update-KolkaUICameras.sh
```

## Service Management

```bash
# Check status
sudo systemctl status kolka-uicameras

# Restart
sudo systemctl restart kolka-uicameras

# Stop
sudo systemctl stop kolka-uicameras

# View logs (all output goes to journald)
sudo journalctl -u kolka-uicameras -f

# View logs (last 100 lines)
sudo journalctl -u kolka-uicameras -n 100
```

## Configuration

- **Application port**: 5011 (Gunicorn, internal)
- **Nginx port**: 8088 (external)
- **Application directory**: `/opt/KolkaUICameras`
- **Service name**: `kolka-uicameras`

## Default Credentials

- Username: `admin`
- Password: `admin123`

## Rollback

If update fails:

```bash
# Find backup
ls /opt/KolkaUICameras_backups/

# Restore
sudo cp -r /opt/KolkaUICameras_backups/backup_YYYYMMDD_HHMMSS/* /opt/KolkaUICameras/

# Restart
sudo systemctl restart kolka-uicameras
```
