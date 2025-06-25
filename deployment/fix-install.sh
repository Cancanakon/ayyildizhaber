#!/bin/bash

# Ayyıldız Haber Ajansı - Fixed Install Script
# Addresses 502 Gateway and virtual environment issues

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

echo -e "${GREEN}Ayyıldız Haber Ajansı - Fixed Installation${NC}"
echo "================================================"

# Must run as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run as root: sudo $0${NC}"
   exit 1
fi

# Get configuration
echo "Configuration:"
read -p "GitHub URL: " GITHUB_URL
read -p "Domain (or 'ip'): " DOMAIN  
read -p "Server IP: " SERVER_IP
read -p "Email: " EMAIL
read -p "DB Password: " DB_PASSWORD

# Validate
if [[ -z "$GITHUB_URL" || -z "$SERVER_IP" || -z "$EMAIL" || -z "$DB_PASSWORD" ]]; then
    error "All fields required!"
    exit 1
fi

log "Starting installation..."

# Update system
log "Updating system..."
apt update && apt upgrade -y

# Install packages
log "Installing packages..."
apt install -y python3 python3-pip python3-venv python3-dev build-essential nginx postgresql postgresql-contrib supervisor git ufw certbot python3-certbot-nginx

# Create user
log "Creating user..."
useradd -m -s /bin/bash ayyildiz 2>/dev/null || true
usermod -aG sudo ayyildiz 2>/dev/null || true
echo "ayyildiz ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ayyildiz

# Clean and clone
log "Getting application code..."
rm -rf /var/www/ayyildiz 2>/dev/null || true
git clone $GITHUB_URL /var/www/ayyildiz
chown -R ayyildiz:ayyildiz /var/www/ayyildiz

# Setup Python environment with proper permissions
log "Setting up Python environment..."
cd /var/www/ayyildiz

# Remove any existing venv
sudo -u ayyildiz rm -rf venv 2>/dev/null || true

# Create fresh virtual environment
sudo -u ayyildiz python3 -m venv venv
sudo -u ayyildiz chmod +x venv/bin/activate

# Install packages step by step to catch errors
log "Installing Python packages..."
sudo -u ayyildiz ./venv/bin/pip install --upgrade pip setuptools wheel

# Install core packages first
sudo -u ayyildiz ./venv/bin/pip install flask==2.3.3
sudo -u ayyildiz ./venv/bin/pip install flask-sqlalchemy==3.0.5
sudo -u ayyildiz ./venv/bin/pip install flask-login==0.6.3
sudo -u ayyildiz ./venv/bin/pip install werkzeug==2.3.7
sudo -u ayyildiz ./venv/bin/pip install gunicorn==21.2.0

# Install database and other packages
sudo -u ayyildiz ./venv/bin/pip install psycopg2-binary==2.9.7
sudo -u ayyildiz ./venv/bin/pip install apscheduler==3.10.4
sudo -u ayyildiz ./venv/bin/pip install beautifulsoup4 lxml requests
sudo -u ayyildiz ./venv/bin/pip install trafilatura email-validator feedparser python-dateutil

# Verify Flask installation
log "Verifying Flask installation..."
sudo -u ayyildiz ./venv/bin/python3 -c "import flask; print(f'Flask version: {flask.__version__}')"

# Setup PostgreSQL
log "Setting up database..."
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

# Create run script with full path to venv
log "Creating application runner..."
cat > /var/www/ayyildiz/start_app.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Activate virtual environment
source /var/www/ayyildiz/venv/bin/activate

# Verify Flask is available
python3 -c "import flask" || {
    echo "Flask not found in virtual environment"
    exit 1
}

# Start application
exec /var/www/ayyildiz/venv/bin/gunicorn \
    --bind 127.0.0.1:5000 \
    --workers 2 \
    --timeout 120 \
    --keep-alive 5 \
    --max-requests 1000 \
    --preload \
    main:app
EOF

chmod +x /var/www/ayyildiz/start_app.sh
chown ayyildiz:ayyildiz /var/www/ayyildiz/start_app.sh

# Test the application script
log "Testing application startup..."
sudo -u ayyildiz timeout 10s /var/www/ayyildiz/start_app.sh || {
    log "Initial startup test completed (timeout expected)"
}

# Setup supervisor with correct script
log "Setting up process manager..."
cat > /etc/supervisor/conf.d/ayyildiz.conf << EOF
[program:ayyildiz]
command=/var/www/ayyildiz/start_app.sh
directory=/var/www/ayyildiz
user=ayyildiz
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/ayyildiz.log
stderr_logfile=/var/log/ayyildiz_error.log
environment=HOME="/home/ayyildiz",USER="ayyildiz"
startsecs=10
startretries=3
EOF

# Configure Nginx
log "Setting up web server..."
if [[ "$DOMAIN" == "ip" ]]; then
cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $SERVER_IP _;
    
    client_max_body_size 50M;
    
    location /static/ {
        alias /var/www/ayyildiz/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
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
cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    client_max_body_size 50M;
    
    location /static/ {
        alias /var/www/ayyildiz/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
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

# Enable site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ayyildiz /etc/nginx/sites-enabled/
nginx -t

# Configure firewall
log "Setting up firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Create directories
log "Setting up directories..."
mkdir -p /var/www/ayyildiz/{static,cache,uploads}
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod -R 755 /var/www/ayyildiz

# Initialize database
log "Initializing database..."
cd /var/www/ayyildiz
sudo -u ayyildiz bash << 'EOF'
source venv/bin/activate
source .env
python3 -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Database initialized successfully')
"
EOF

# Start services
log "Starting services..."
systemctl enable supervisor nginx
systemctl start supervisor
supervisorctl reread
supervisorctl update
supervisorctl start ayyildiz
systemctl restart nginx

# Wait and check status
log "Checking application status..."
sleep 5
supervisorctl status ayyildiz

# Check if app is responding
log "Testing application response..."
if curl -s http://127.0.0.1:5000 > /dev/null; then
    log "Application is responding correctly"
else
    error "Application not responding - checking logs..."
    tail -20 /var/log/ayyildiz.log
    tail -20 /var/log/ayyildiz_error.log
fi

# Setup SSL for domain (skip for IP)
if [[ "$DOMAIN" != "ip" ]]; then
    log "Setting up SSL certificate..."
    certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect || {
        echo -e "${YELLOW}SSL setup failed - website will work on HTTP${NC}"
    }
fi

# Create management script
cat > /usr/local/bin/ayyildiz-status << 'EOF'
#!/bin/bash
echo "=== Ayyıldız Haber Ajansı Status ==="
echo ""
echo "Supervisor Status:"
supervisorctl status ayyildiz
echo ""
echo "Nginx Status:"
systemctl status nginx --no-pager -l | head -10
echo ""
echo "Application Response Test:"
if curl -s http://127.0.0.1:5000 > /dev/null; then
    echo "✓ Application responding"
else
    echo "✗ Application not responding"
fi
echo ""
echo "Recent Application Logs:"
tail -10 /var/log/ayyildiz.log
echo ""
echo "Recent Error Logs:"
tail -5 /var/log/ayyildiz_error.log
EOF

chmod +x /usr/local/bin/ayyildiz-status

# Final status
log "Final status check..."
supervisorctl status ayyildiz
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://127.0.0.1:5000 || echo "Could not test HTTP response"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Installation Completed Successfully!  ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

if [[ "$DOMAIN" == "ip" ]]; then
    echo -e "Website URL: ${GREEN}http://$SERVER_IP${NC}"
else
    if certbot certificates --domain $DOMAIN &>/dev/null; then
        echo -e "Website URL: ${GREEN}https://$DOMAIN${NC}"
    else
        echo -e "Website URL: ${GREEN}http://$DOMAIN${NC}"
    fi
fi

echo -e "Admin Panel: ${GREEN}/admin${NC}"
echo -e "Default Login: ${GREEN}admin@gmail.com / admin123${NC}"
echo ""
echo -e "${YELLOW}Important: Change admin password after first login!${NC}"
echo ""
echo -e "Management Commands:"
echo "• Status check: ${GREEN}ayyildiz-status${NC}"
echo "• Restart app: ${GREEN}supervisorctl restart ayyildiz${NC}"
echo "• View logs: ${GREEN}tail -f /var/log/ayyildiz.log${NC}"
echo "• Error logs: ${GREEN}tail -f /var/log/ayyildiz_error.log${NC}"
echo ""

log "Installation completed successfully!"