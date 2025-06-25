#!/bin/bash

# Ayyıldız Haber Ajansı - Ubuntu 24.04 VPS Deployment Script
# Tested for both IP and domain deployment with SSL

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

# Check if running as root and create user if needed
if [[ $EUID -eq 0 ]]; then
   log "Running as root - creating ayyildiz user automatically..."
   # Create application user if running as root
   useradd -m -s /bin/bash ayyildiz 2>/dev/null || true
   usermod -aG sudo ayyildiz 2>/dev/null || true
   echo "ayyildiz ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ayyildiz
   ROOT_INSTALL=true
else
   ROOT_INSTALL=false
fi

# Get deployment configuration
echo -e "${BLUE}=== Ayyıldız Haber Ajansı VPS Deployment ===${NC}"
echo ""
read -p "Enter your domain name (e.g., ayyildizajans.com) or 'ip' for IP-only deployment: " DOMAIN
read -p "Enter your server IP address: " SERVER_IP
read -p "Enter your email for SSL certificate: " EMAIL
read -p "Enter database password for PostgreSQL: " DB_PASSWORD

# Validate inputs
if [[ -z "$SERVER_IP" || -z "$EMAIL" || -z "$DB_PASSWORD" ]]; then
    error "All fields are required!"
    exit 1
fi

log "Starting deployment for domain: $DOMAIN on IP: $SERVER_IP"

# Update system
log "Updating system packages..."
if [[ $ROOT_INSTALL == true ]]; then
    apt update && apt upgrade -y
else
    sudo apt update && sudo apt upgrade -y
fi

# Install required packages
log "Installing required packages..."
if [[ $ROOT_INSTALL == true ]]; then
    apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git curl wget ufw certbot python3-certbot-nginx
else
    sudo apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git curl wget ufw certbot python3-certbot-nginx
fi

# Create application user (skip if already done in root check)
if [[ $ROOT_INSTALL == false ]]; then
    log "Creating application user..."
    sudo useradd -m -s /bin/bash ayyildiz || true
    sudo usermod -aG sudo ayyildiz || true
fi

# Create application directory
log "Setting up application directory..."
sudo mkdir -p /var/www/ayyildiz
sudo chown ayyildiz:ayyildiz /var/www/ayyildiz

# Clone or copy application (assuming files are in current directory)
log "Copying application files..."
sudo cp -r . /var/www/ayyildiz/
sudo chown -R ayyildiz:ayyildiz /var/www/ayyildiz

# Create virtual environment
log "Setting up Python virtual environment..."
cd /var/www/ayyildiz
sudo -u ayyildiz python3 -m venv venv
sudo -u ayyildiz ./venv/bin/pip install --upgrade pip

# Install Python dependencies
log "Installing Python dependencies..."
if [ -f "deployment/requirements-prod.txt" ]; then
    sudo -u ayyildiz ./venv/bin/pip install -r deployment/requirements-prod.txt
elif [ -f "requirements.txt" ]; then
    sudo -u ayyildiz ./venv/bin/pip install -r requirements.txt
else
    # Install manually with specific versions
    sudo -u ayyildiz ./venv/bin/pip install flask==2.3.3 flask-sqlalchemy==3.0.5 flask-login==0.6.3 gunicorn==21.2.0 psycopg2-binary==2.9.7 apscheduler==3.10.4 beautifulsoup4 lxml requests trafilatura email-validator feedparser python-dateutil werkzeug==2.3.7
fi

# Setup PostgreSQL
log "Configuring PostgreSQL..."
sudo -u postgres createuser ayyildiz || true
sudo -u postgres createdb ayyildiz_db -O ayyildiz || true
sudo -u postgres psql -c "ALTER USER ayyildiz PASSWORD '$DB_PASSWORD';" || true

# Create environment file
log "Creating environment configuration..."
cat > /tmp/ayyildiz.env << EOF
DATABASE_URL=postgresql://ayyildiz:$DB_PASSWORD@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF

sudo mv /tmp/ayyildiz.env /var/www/ayyildiz/.env
sudo chown ayyildiz:ayyildiz /var/www/ayyildiz/.env
sudo chmod 600 /var/www/ayyildiz/.env

# Create application service script
log "Creating application service script..."
cat > /tmp/run_app.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz
source venv/bin/activate
source .env
export DATABASE_URL SESSION_SECRET FLASK_ENV FLASK_APP
exec gunicorn --bind 127.0.0.1:5000 --workers 4 --timeout 120 --keep-alive 5 --max-requests 1000 main:app
EOF

sudo mv /tmp/run_app.sh /var/www/ayyildiz/run_app.sh
sudo chmod +x /var/www/ayyildiz/run_app.sh
sudo chown ayyildiz:ayyildiz /var/www/ayyildiz/run_app.sh

# Create supervisor configuration
log "Setting up Supervisor for process management..."
cat > /tmp/ayyildiz.conf << EOF
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

sudo mv /tmp/ayyildiz.conf /etc/supervisor/conf.d/ayyildiz.conf

# Configure firewall
log "Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Create Nginx configuration
log "Configuring Nginx..."
if [[ "$DOMAIN" == "ip" ]]; then
    # IP-only configuration
    cat > /tmp/ayyildiz_nginx << EOF
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
    # Domain configuration with SSL
    cat > /tmp/ayyildiz_nginx << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    client_max_body_size 50M;
    
    # SSL configuration (will be added by certbot)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

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
sudo rm -f /etc/nginx/sites-enabled/default
sudo mv /tmp/ayyildiz_nginx /etc/nginx/sites-available/ayyildiz
sudo ln -sf /etc/nginx/sites-available/ayyildiz /etc/nginx/sites-enabled/

# Test nginx configuration
log "Testing Nginx configuration..."
sudo nginx -t

# Create directories and set permissions
log "Setting up directories and permissions..."
sudo mkdir -p /var/www/ayyildiz/static /var/www/ayyildiz/cache /var/www/ayyildiz/uploads
sudo chown -R ayyildiz:ayyildiz /var/www/ayyildiz
sudo chmod -R 755 /var/www/ayyildiz

# Initialize database
log "Initializing database..."
cd /var/www/ayyildiz
sudo -u ayyildiz bash -c "source venv/bin/activate && source .env && python3 -c 'from app import app, db; app.app_context().push(); db.create_all(); print(\"Database initialized successfully\")'"

# Start services
log "Starting services..."
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start ayyildiz
sudo systemctl restart nginx

# Setup SSL if domain is provided
if [[ "$DOMAIN" != "ip" ]]; then
    log "Setting up SSL certificate..."
    sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect
fi

# Create backup script
log "Creating backup script..."
cat > /tmp/backup.sh << 'EOF'
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

sudo mv /tmp/backup.sh /usr/local/bin/ayyildiz-backup.sh
sudo chmod +x /usr/local/bin/ayyildiz-backup.sh

# Add backup to crontab
log "Setting up automated backups..."
(sudo crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/ayyildiz-backup.sh") | sudo crontab -

# Create status check script
cat > /tmp/status.sh << 'EOF'
#!/bin/bash
echo "=== Ayyıldız Haber Ajansı Status ==="
echo "Supervisor status:"
sudo supervisorctl status ayyildiz
echo ""
echo "Nginx status:"
sudo systemctl status nginx --no-pager -l
echo ""
echo "Database status:"
sudo systemctl status postgresql --no-pager -l
echo ""
echo "Application logs (last 10 lines):"
sudo tail -10 /var/log/ayyildiz.log
EOF

sudo mv /tmp/status.sh /usr/local/bin/ayyildiz-status.sh
sudo chmod +x /usr/local/bin/ayyildiz-status.sh

# Final status check
log "Performing final status check..."
sleep 5
sudo supervisorctl status ayyildiz
sudo systemctl status nginx --no-pager

echo ""
log "=== DEPLOYMENT COMPLETED SUCCESSFULLY ==="
echo ""
echo -e "${GREEN}Application Details:${NC}"
if [[ "$DOMAIN" == "ip" ]]; then
    echo "  • URL: http://$SERVER_IP"
else
    echo "  • URL: https://$DOMAIN"
    echo "  • Alternative: https://www.$DOMAIN"
fi
echo "  • Admin Panel: /admin (default login: admin@gmail.com / admin123)"
echo "  • Database: PostgreSQL on localhost"
echo ""
echo -e "${GREEN}Management Commands:${NC}"
echo "  • Check status: sudo /usr/local/bin/ayyildiz-status.sh"
echo "  • Manual backup: sudo /usr/local/bin/ayyildiz-backup.sh"
echo "  • Restart app: sudo supervisorctl restart ayyildiz"
echo "  • Restart nginx: sudo systemctl restart nginx"
echo "  • View logs: sudo tail -f /var/log/ayyildiz.log"
echo ""
echo -e "${GREEN}File Locations:${NC}"
echo "  • Application: /var/www/ayyildiz"
echo "  • Nginx config: /etc/nginx/sites-available/ayyildiz"
echo "  • Supervisor config: /etc/supervisor/conf.d/ayyildiz.conf"
echo "  • Environment: /var/www/ayyildiz/.env"
echo "  • Backups: /var/backups/ayyildiz"
echo ""
if [[ "$DOMAIN" != "ip" ]]; then
    echo -e "${GREEN}SSL Certificate:${NC}"
    echo "  • Auto-renewal enabled via certbot"
    echo "  • Check renewal: sudo certbot certificates"
fi
echo ""
warning "Please change the default admin password after first login!"
log "Deployment completed successfully! Your website should now be accessible."