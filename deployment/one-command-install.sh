#!/bin/bash

# Ayyıldız Haber Ajansı - One Command Install
# Ultra-simple installation for Ubuntu 24.04

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Ayyıldız Haber Ajansı - One Command Install${NC}"
echo "=============================================="

# Must run as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run as root: sudo $0${NC}"
   exit 1
fi

# Get info
echo "Please provide:"
read -p "GitHub URL: " GITHUB_URL
read -p "Domain (or 'ip'): " DOMAIN  
read -p "Server IP: " SERVER_IP
read -p "Email: " EMAIL
read -p "DB Password: " DB_PASSWORD

echo -e "${GREEN}Installing...${NC}"

# Update & install
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git ufw certbot python3-certbot-nginx

# Create user
useradd -m ayyildiz 2>/dev/null || true
echo "ayyildiz ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ayyildiz

# Get code
rm -rf /var/www/ayyildiz 2>/dev/null || true
git clone $GITHUB_URL /var/www/ayyildiz
chown -R ayyildiz:ayyildiz /var/www/ayyildiz

# Python setup
cd /var/www/ayyildiz
sudo -u ayyildiz python3 -m venv venv
sudo -u ayyildiz ./venv/bin/pip install --upgrade pip
sudo -u ayyildiz ./venv/bin/pip install flask==2.3.3 flask-sqlalchemy==3.0.5 flask-login==0.6.3 gunicorn==21.2.0 psycopg2-binary==2.9.7 apscheduler==3.10.4 beautifulsoup4 lxml requests trafilatura email-validator feedparser python-dateutil werkzeug==2.3.7

# Database
systemctl start postgresql
systemctl enable postgresql
sudo -u postgres createuser ayyildiz 2>/dev/null || true
sudo -u postgres createdb ayyildiz_db -O ayyildiz 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER ayyildiz PASSWORD '$DB_PASSWORD';"

# Config
cat > /var/www/ayyildiz/.env << EOF
DATABASE_URL=postgresql://ayyildiz:$DB_PASSWORD@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF
chown ayyildiz:ayyildiz /var/www/ayyildiz/.env

# App script
cat > /var/www/ayyildiz/run.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz
source venv/bin/activate
source .env
export DATABASE_URL SESSION_SECRET FLASK_ENV FLASK_APP
exec gunicorn --bind 127.0.0.1:5000 --workers 4 --timeout 120 --keep-alive 5 --max-requests 1000 main:app
EOF
chmod +x /var/www/ayyildiz/run.sh
chown ayyildiz:ayyildiz /var/www/ayyildiz/run.sh

# Supervisor
cat > /etc/supervisor/conf.d/ayyildiz.conf << EOF
[program:ayyildiz]
command=/var/www/ayyildiz/run.sh
user=ayyildiz
autostart=true
autorestart=true
stdout_logfile=/var/log/ayyildiz.log
EOF

# Nginx
if [[ "$DOMAIN" == "ip" ]]; then
cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80 default_server;
    server_name $SERVER_IP;
    location /static/ { alias /var/www/ayyildiz/static/; }
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
else
cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    location /static/ { alias /var/www/ayyildiz/static/; }
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
fi

# Enable site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ayyildiz /etc/nginx/sites-enabled/

# Firewall
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Init DB
mkdir -p /var/www/ayyildiz/{static,cache,uploads}
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
cd /var/www/ayyildiz
sudo -u ayyildiz bash -c "source venv/bin/activate && source .env && python3 -c 'from app import app, db; app.app_context().push(); db.create_all()'"

# Start everything
systemctl enable supervisor nginx
systemctl start supervisor
supervisorctl reread && supervisorctl update
supervisorctl start ayyildiz
systemctl restart nginx

# SSL if domain
if [[ "$DOMAIN" != "ip" ]]; then
    certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect 2>/dev/null || echo "SSL failed - HTTP only"
fi

sleep 2
supervisorctl status ayyildiz

echo ""
echo -e "${GREEN}✓ Installation Complete!${NC}"
if [[ "$DOMAIN" == "ip" ]]; then
    echo "URL: http://$SERVER_IP"
else
    echo "URL: https://$DOMAIN"
fi
echo "Admin: /admin (admin@gmail.com / admin123)"
echo ""
echo "Commands:"
echo "• Status: supervisorctl status ayyildiz"
echo "• Logs: tail -f /var/log/ayyildiz.log"
echo "• Restart: supervisorctl restart ayyildiz"