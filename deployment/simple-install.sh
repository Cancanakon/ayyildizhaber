#!/bin/bash

# Ayyıldız Haber Ajansı - Simple Install Script
# One-command installation for Ubuntu 24.04 VPS

echo "Ayyıldız Haber Ajansı - Simple Installation"
echo "==========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root. Use: sudo ./simple-install.sh"
   exit 1
fi

# Get basic configuration
echo "Please provide the following information:"
echo ""
read -p "GitHub repository URL: " GITHUB_URL
read -p "Domain name (or 'ip' for IP-only): " DOMAIN
read -p "Server IP address: " SERVER_IP
read -p "Email for SSL certificate: " EMAIL
read -p "Database password: " DB_PASSWORD

# Validate inputs
if [[ -z "$GITHUB_URL" || -z "$SERVER_IP" || -z "$EMAIL" || -z "$DB_PASSWORD" ]]; then
    error "All fields are required!"
    exit 1
fi

echo ""
log "Starting installation..."

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install packages
log "Installing required packages..."
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git curl wget ufw certbot python3-certbot-nginx

# Create user
log "Creating application user..."
useradd -m -s /bin/bash ayyildiz 2>/dev/null || true
usermod -aG sudo ayyildiz 2>/dev/null || true
echo "ayyildiz ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ayyildiz

# Clone from GitHub
log "Downloading application from GitHub..."
rm -rf /var/www/ayyildiz 2>/dev/null || true
git clone $GITHUB_URL /var/www/ayyildiz
chown -R ayyildiz:ayyildiz /var/www/ayyildiz

# Setup Python environment
log "Setting up Python environment..."
cd /var/www/ayyildiz
sudo -u ayyildiz python3 -m venv venv
sudo -u ayyildiz ./venv/bin/pip install --upgrade pip

# Install dependencies
log "Installing Python packages..."
sudo -u ayyildiz ./venv/bin/pip install flask==2.3.3 flask-sqlalchemy==3.0.5 flask-login==0.6.3 gunicorn==21.2.0 psycopg2-binary==2.9.7 apscheduler==3.10.4 beautifulsoup4 lxml requests trafilatura email-validator feedparser python-dateutil werkzeug==2.3.7

# Setup PostgreSQL
log "Configuring database..."
systemctl start postgresql
systemctl enable postgresql
sudo -u postgres createuser ayyildiz 2>/dev/null || true
sudo -u postgres createdb ayyildiz_db -O ayyildiz 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER ayyildiz PASSWORD '$DB_PASSWORD';" 2>/dev/null || true

# Create environment file
log "Creating configuration..."
cat > /var/www/ayyildiz/.env << EOF
DATABASE_URL=postgresql://ayyildiz:$DB_PASSWORD@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF

chown ayyildiz:ayyildiz /var/www/ayyildiz/.env
chmod 600 /var/www/ayyildiz/.env

# Create run script
cat > /var/www/ayyildiz/run_app.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz
source venv/bin/activate
source .env
export DATABASE_URL SESSION_SECRET FLASK_ENV FLASK_APP
exec gunicorn --bind 127.0.0.1:5000 --workers 4 --timeout 120 main:app
EOF

chmod +x /var/www/ayyildiz/run_app.sh
chown ayyildiz:ayyildiz /var/www/ayyildiz/run_app.sh

# Setup Supervisor
log "Configuring process manager..."
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

# Configure Nginx
log "Setting up web server..."
if [[ "$DOMAIN" == "ip" ]]; then
    # IP-only configuration
    cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $SERVER_IP _;
    client_max_body_size 50M;
    
    location /static/ {
        alias /var/www/ayyildiz/static/;
        expires 1y;
    }
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
    
    location /static/ {
        alias /var/www/ayyildiz/static/;
        expires 1y;
    }
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
fi

# Enable site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ayyildiz /etc/nginx/sites-enabled/
nginx -t

# Setup firewall
log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Initialize database
log "Initializing database..."
mkdir -p /var/www/ayyildiz/static /var/www/ayyildiz/cache /var/www/ayyildiz/uploads
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod -R 755 /var/www/ayyildiz

cd /var/www/ayyildiz
sudo -u ayyildiz bash -c "source venv/bin/activate && source .env && python3 -c 'from app import app, db; app.app_context().push(); db.create_all(); print(\"Database ready\")'"

# Start services
log "Starting services..."
systemctl enable supervisor nginx
systemctl start supervisor
supervisorctl reread
supervisorctl update
supervisorctl start ayyildiz
systemctl restart nginx

# Setup SSL for domain
if [[ "$DOMAIN" != "ip" ]]; then
    log "Setting up SSL certificate..."
    certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect || {
        warning "SSL setup failed - website will work on HTTP"
    }
fi

# Create management commands
cat > /usr/local/bin/ayyildiz-status << 'EOF'
#!/bin/bash
echo "=== Ayyıldız Haber Ajansı Status ==="
supervisorctl status ayyildiz
systemctl status nginx --no-pager
tail -5 /var/log/ayyildiz.log
EOF

chmod +x /usr/local/bin/ayyildiz-status

# Final check
sleep 3
supervisorctl status ayyildiz

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Installation Completed Successfully!  ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
if [[ "$DOMAIN" == "ip" ]]; then
    echo -e "${BLUE}Website URL:${NC} http://$SERVER_IP"
else
    echo -e "${BLUE}Website URL:${NC} https://$DOMAIN"
fi
echo -e "${BLUE}Admin Panel:${NC} /admin"
echo -e "${BLUE}Default Login:${NC} admin@gmail.com / admin123"
echo ""
echo -e "${YELLOW}Important:${NC} Change admin password after first login!"
echo ""
echo -e "${GREEN}Management Commands:${NC}"
echo "• Check status: ayyildiz-status"
echo "• Restart app: supervisorctl restart ayyildiz"
echo "• View logs: tail -f /var/log/ayyildiz.log"
echo ""
log "Installation completed! Your website is ready."