#!/bin/bash

# Ayyıldız Haber Ajansı - Root Install Script for Ubuntu 24.04
# Simplified installation that works with root user

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

echo -e "${BLUE}=== Ayyıldız Haber Ajansı VPS Deployment ===${NC}"
echo ""

# Get deployment configuration
read -p "Enter your GitHub repository URL (e.g., https://github.com/username/ayyildiz-news): " GITHUB_URL
read -p "Enter your domain name (e.g., ayyildizajans.com) or 'ip' for IP-only deployment: " DOMAIN
read -p "Enter your server IP address: " SERVER_IP
read -p "Enter your email for SSL certificate: " EMAIL
read -p "Enter database password for PostgreSQL: " DB_PASSWORD

# Validate inputs
if [[ -z "$GITHUB_URL" || -z "$SERVER_IP" || -z "$EMAIL" || -z "$DB_PASSWORD" ]]; then
    error "All fields are required!"
    exit 1
fi

log "Starting deployment for domain: $DOMAIN on IP: $SERVER_IP"

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
log "Installing required packages..."
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git curl wget ufw certbot python3-certbot-nginx

# Create application user
log "Creating application user..."
useradd -m -s /bin/bash ayyildiz 2>/dev/null || true
usermod -aG sudo ayyildiz 2>/dev/null || true
echo "ayyildiz ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ayyildiz

# Clone application from GitHub
log "Cloning application from GitHub..."
rm -rf /var/www/ayyildiz 2>/dev/null || true
git clone $GITHUB_URL /var/www/ayyildiz
chown -R ayyildiz:ayyildiz /var/www/ayyildiz

# Create virtual environment
log "Setting up Python virtual environment..."
cd /var/www/ayyildiz
sudo -u ayyildiz python3 -m venv venv
sudo -u ayyildiz ./venv/bin/pip install --upgrade pip

# Install Python dependencies
log "Installing Python dependencies..."
if [ -f "deployment/requirements-prod.txt" ]; then
    sudo -u ayyildiz ./venv/bin/pip install -r deployment/requirements-prod.txt
else
    # Install manually with specific versions
    sudo -u ayyildiz ./venv/bin/pip install flask==2.3.3 flask-sqlalchemy==3.0.5 flask-login==0.6.3 gunicorn==21.2.0 psycopg2-binary==2.9.7 apscheduler==3.10.4 beautifulsoup4 lxml requests trafilatura email-validator feedparser python-dateutil werkzeug==2.3.7
fi

# Setup PostgreSQL
log "Configuring PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql
sudo -u postgres createuser ayyildiz 2>/dev/null || true
sudo -u postgres createdb ayyildiz_db -O ayyildiz 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER ayyildiz PASSWORD '$DB_PASSWORD';" 2>/dev/null || true

# Create environment file
log "Creating environment configuration..."
cat > /var/www/ayyildiz/.env << EOF
DATABASE_URL=postgresql://ayyildiz:$DB_PASSWORD@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF

chown ayyildiz:ayyildiz /var/www/ayyildiz/.env
chmod 600 /var/www/ayyildiz/.env

# Create application service script
log "Creating application service script..."
cat > /var/www/ayyildiz/run_app.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz
source venv/bin/activate
source .env
export DATABASE_URL SESSION_SECRET FLASK_ENV FLASK_APP
exec gunicorn --bind 127.0.0.1:5000 --workers 4 --timeout 120 --keep-alive 5 --max-requests 1000 main:app
EOF

chmod +x /var/www/ayyildiz/run_app.sh
chown ayyildiz:ayyildiz /var/www/ayyildiz/run_app.sh

# Create supervisor configuration
log "Setting up Supervisor for process management..."
cat > /etc/supervisor/conf.d/ayyildiz.conf << EOF
[program:ayyildiz]
command=/var/www/ayyildiz/run_app.sh
directory=/var/www/ayyildiz
user=ayyildiz
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/ayyildiz.log
environment=HOME="/home/ayyildiz",USER="ayyildiz"
EOF

# Configure firewall
log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Create Nginx configuration
log "Configuring Nginx..."
if [[ "$DOMAIN" == "ip" ]]; then
    # IP-only configuration
    cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $SERVER_IP _;

    client_max_body_size 50M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Static files
    location /static/ {
        alias /var/www/ayyildiz/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF
else
    # Domain configuration
    cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    client_max_body_size 50M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Static files
    location /static/ {
        alias /var/www/ayyildiz/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF
fi

# Remove default nginx site and install our configuration
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ayyildiz /etc/nginx/sites-enabled/

# Test nginx configuration
log "Testing Nginx configuration..."
nginx -t

# Create directories and set permissions
log "Setting up directories and permissions..."
mkdir -p /var/www/ayyildiz/static /var/www/ayyildiz/cache /var/www/ayyildiz/uploads
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod -R 755 /var/www/ayyildiz

# Initialize database
log "Initializing database..."
cd /var/www/ayyildiz
sudo -u ayyildiz bash -c "source venv/bin/activate && source .env && python3 -c 'from app import app, db; app.app_context().push(); db.create_all(); print(\"Database initialized successfully\")'"

# Start services
log "Starting services..."
systemctl enable supervisor
systemctl start supervisor
supervisorctl reread
supervisorctl update
supervisorctl start ayyildiz
systemctl enable nginx
systemctl restart nginx

# Setup SSL if domain is provided
if [[ "$DOMAIN" != "ip" ]]; then
    log "Setting up SSL certificate..."
    certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect || {
        warning "SSL setup failed, website will run on HTTP only"
    }
fi

# Create management scripts
log "Creating management scripts..."

# Status script
cat > /usr/local/bin/ayyildiz-status.sh << 'EOF'
#!/bin/bash
echo "=== Ayyıldız Haber Ajansı Status ==="
echo "Supervisor status:"
supervisorctl status ayyildiz
echo ""
echo "Nginx status:"
systemctl status nginx --no-pager -l
echo ""
echo "Database status:"
systemctl status postgresql --no-pager -l
echo ""
echo "Application logs (last 10 lines):"
tail -10 /var/log/ayyildiz.log
EOF

chmod +x /usr/local/bin/ayyildiz-status.sh

# Backup script
cat > /usr/local/bin/ayyildiz-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/ayyildiz"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Database backup
sudo -u postgres pg_dump ayyildiz_db > $BACKUP_DIR/db_$DATE.sql

# Application backup
tar -czf $BACKUP_DIR/app_$DATE.tar.gz -C /var/www ayyildiz

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /usr/local/bin/ayyildiz-backup.sh

# Add backup to crontab
log "Setting up automated backups..."
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/ayyildiz-backup.sh") | crontab -

# Final status check
log "Performing final status check..."
sleep 5
supervisorctl status ayyildiz
systemctl status nginx --no-pager

echo ""
log "=== DEPLOYMENT COMPLETED SUCCESSFULLY ==="
echo ""
echo -e "${GREEN}Application Details:${NC}"
if [[ "$DOMAIN" == "ip" ]]; then
    echo "  • URL: http://$SERVER_IP"
else
    echo "  • URL: https://$DOMAIN (SSL setup attempted)"
    echo "  • Alternative: https://www.$DOMAIN"
    echo "  • If SSL failed: http://$DOMAIN"
fi
echo "  • Admin Panel: /admin (default login: admin@gmail.com / admin123)"
echo "  • Database: PostgreSQL on localhost"
echo ""
echo -e "${GREEN}Management Commands:${NC}"
echo "  • Check status: /usr/local/bin/ayyildiz-status.sh"
echo "  • Manual backup: /usr/local/bin/ayyildiz-backup.sh"
echo "  • Restart app: supervisorctl restart ayyildiz"
echo "  • Restart nginx: systemctl restart nginx"
echo "  • View logs: tail -f /var/log/ayyildiz.log"
echo ""
echo -e "${GREEN}File Locations:${NC}"
echo "  • Application: /var/www/ayyildiz"
echo "  • Nginx config: /etc/nginx/sites-available/ayyildiz"
echo "  • Supervisor config: /etc/supervisor/conf.d/ayyildiz.conf"
echo "  • Environment: /var/www/ayyildiz/.env"
echo "  • Backups: /var/backups/ayyildiz"
echo ""
warning "Please change the default admin password after first login!"
log "Deployment completed successfully! Your website should now be accessible."