# Ubuntu 24.04 VPS Deployment Guide - Ayyıldız Haber Ajansı

## 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git curl certbot python3-certbot-nginx

# Install Node.js (for frontend build tools if needed)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## 2. PostgreSQL Database Setup

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE ayyildiz_haber;
CREATE USER ayyildiz_user WITH PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE ayyildiz_haber TO ayyildiz_user;
ALTER USER ayyildiz_user CREATEDB;
\q

# Test connection
psql -h localhost -U ayyildiz_user -d ayyildiz_haber
```

## 3. Application Deployment

```bash
# Create app directory
sudo mkdir -p /var/www/ayyildiz-haber
cd /var/www/ayyildiz-haber

# Clone your repository (replace with your repo URL)
sudo git clone https://github.com/yourusername/ayyildiz-haber.git .

# Set proper ownership
sudo chown -R www-data:www-data /var/www/ayyildiz-haber

# Create virtual environment
sudo -u www-data python3 -m venv venv
sudo -u www-data ./venv/bin/pip install --upgrade pip

# Install Python dependencies
sudo -u www-data ./venv/bin/pip install -r requirements.txt
sudo -u www-data ./venv/bin/pip install gunicorn psycopg2-binary

# Create environment file
sudo -u www-data tee .env << 'EOF'
DATABASE_URL=postgresql://ayyildiz_user:your_secure_password_here@localhost/ayyildiz_haber
SESSION_SECRET=your_super_secret_session_key_here_make_it_long_and_random
FLASK_ENV=production
FLASK_DEBUG=False
EOF

# Create static directories
sudo -u www-data mkdir -p static/uploads
sudo -u www-data mkdir -p cache
sudo -u www-data mkdir -p logs
```

## 4. Gunicorn Configuration

```bash
# Create gunicorn config
sudo tee /var/www/ayyildiz-haber/gunicorn.conf.py << 'EOF'
import multiprocessing

bind = "127.0.0.1:5000"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
preload_app = True
user = "www-data"
group = "www-data"
access_logfile = "/var/www/ayyildiz-haber/logs/gunicorn_access.log"
error_logfile = "/var/www/ayyildiz-haber/logs/gunicorn_error.log"
loglevel = "info"
EOF
```

## 5. Supervisor Configuration (Process Management)

```bash
# Create supervisor config
sudo tee /etc/supervisor/conf.d/ayyildiz-haber.conf << 'EOF'
[program:ayyildiz-haber]
command=/var/www/ayyildiz-haber/venv/bin/gunicorn --config /var/www/ayyildiz-haber/gunicorn.conf.py main:app
directory=/var/www/ayyildiz-haber
user=www-data
group=www-data
autostart=true
autorestart=true
startsecs=5
startretries=3
redirect_stderr=true
stdout_logfile=/var/www/ayyildiz-haber/logs/supervisor.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
environment=PATH="/var/www/ayyildiz-haber/venv/bin"
EOF

# Reload supervisor
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start ayyildiz-haber
```

## 6. Nginx Configuration (FIXED - No HTTP directive error)

```bash
# Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Create new site configuration
sudo tee /etc/nginx/sites-available/ayyildiz-haber << 'EOF'
server {
    listen 80;
    server_name ayyildizajans.com www.ayyildizajans.com 69.62.110.158;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Static files
    location /static {
        alias /var/www/ayyildiz-haber/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media {
        alias /var/www/ayyildiz-haber/static/uploads;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_buffering off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # File upload size
    client_max_body_size 10M;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/javascript application/xml+rss application/json;
    
    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/ayyildiz-haber /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t

# If test passes, restart nginx
sudo systemctl restart nginx
```

## 7. SSL Certificate Setup

```bash
# Install SSL certificate
sudo certbot --nginx -d ayyildizajans.com -d www.ayyildizajans.com

# Test auto-renewal
sudo certbot renew --dry-run

# Add auto-renewal cron job
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

## 8. Firewall Configuration

```bash
# Configure UFW firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Check status
sudo ufw status
```

## 9. Database Migration and Initial Setup

```bash
# Navigate to app directory
cd /var/www/ayyildiz-haber

# Run database migrations
sudo -u www-data ./venv/bin/python -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Database tables created successfully')
"

# Create admin user (optional)
sudo -u www-data ./venv/bin/python -c "
from app import app, db
from models import Admin
import getpass

with app.app_context():
    admin = Admin(
        username='admin',
        email='admin@ayyildizajans.com',
        is_super_admin=True
    )
    admin.set_password('your_admin_password_here')
    db.session.add(admin)
    db.session.commit()
    print('Admin user created successfully')
"
```

## 10. Service Management Commands

```bash
# Check application status
sudo supervisorctl status ayyildiz-haber

# Restart application
sudo supervisorctl restart ayyildiz-haber

# View logs
sudo tail -f /var/www/ayyildiz-haber/logs/supervisor.log
sudo tail -f /var/www/ayyildiz-haber/logs/gunicorn_error.log

# Nginx commands
sudo systemctl status nginx
sudo systemctl restart nginx
sudo nginx -t  # Test configuration

# Database backup
pg_dump -h localhost -U ayyildiz_user ayyildiz_haber > backup_$(date +%Y%m%d_%H%M%S).sql
```

## 11. Domain DNS Configuration

Add these DNS records to your domain:
```
A     @              69.62.110.158
A     www            69.62.110.158
CNAME ayyildizajans.com.  www.ayyildizajans.com.
```

## 12. Monitoring and Maintenance

```bash
# Create log rotation
sudo tee /etc/logrotate.d/ayyildiz-haber << 'EOF'
/var/www/ayyildiz-haber/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        supervisorctl restart ayyildiz-haber
    endscript
}
EOF

# Create backup script
sudo tee /usr/local/bin/backup-ayyildiz.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/ayyildiz-haber"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Database backup
pg_dump -h localhost -U ayyildiz_user ayyildiz_haber > $BACKUP_DIR/db_$DATE.sql

# Files backup
tar -czf $BACKUP_DIR/files_$DATE.tar.gz -C /var/www/ayyildiz-haber static/uploads

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

sudo chmod +x /usr/local/bin/backup-ayyildiz.sh

# Add daily backup cron
echo "0 2 * * * /usr/local/bin/backup-ayyildiz.sh" | sudo crontab -
```

## Key Changes from Previous Version:
1. **Fixed Nginx Configuration**: Removed invalid "http" directive that was causing errors
2. **Security headers moved inside server block**: Proper Nginx syntax compliance
3. **Added proper SSL setup**: Using Certbot for automatic certificate management
4. **Added process management**: Using Supervisor for better application management
5. **Added backup and monitoring**: Comprehensive maintenance scripts
6. **Fixed permissions**: Proper www-data ownership throughout

## Troubleshooting:
- If Nginx fails to start: `sudo nginx -t` to check configuration
- If app doesn't start: Check `sudo supervisorctl status` and logs
- If SSL fails: Ensure domain DNS is pointing to your server IP
- If database connection fails: Check PostgreSQL service and user permissions