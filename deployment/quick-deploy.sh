#!/bin/bash

# Ayyıldız Haber Ajansı - Ubuntu 24.04 Quick Deploy Script
# Usage: sudo bash quick-deploy.sh

set -e

echo "🚀 Starting Ayyıldız Haber Ajansı deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Get user inputs
read -p "Enter your domain name (e.g., ayyildizajans.com): " DOMAIN_NAME
read -p "Enter database password: " -s DB_PASSWORD
echo
read -p "Enter admin email: " ADMIN_EMAIL
read -p "Enter admin password: " -s ADMIN_PASSWORD
echo

# Generate secret key
SECRET_KEY=$(openssl rand -hex 32)

print_status "Updating system packages..."
apt update && apt upgrade -y

print_status "Installing required packages..."
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git curl certbot python3-certbot-nginx

print_status "Setting up PostgreSQL..."
sudo -u postgres psql << EOF
CREATE DATABASE ayyildiz_haber;
CREATE USER ayyildiz_user WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE ayyildiz_haber TO ayyildiz_user;
ALTER USER ayyildiz_user CREATEDB;
\q
EOF

print_status "Creating application directory..."
mkdir -p /var/www/ayyildiz-haber
cd /var/www/ayyildiz-haber

print_status "Setting up Python virtual environment..."
python3 -m venv venv
./venv/bin/pip install --upgrade pip

# Create requirements.txt if not exists
if [ ! -f requirements.txt ]; then
    cat > requirements.txt << 'EOF'
Flask==2.3.3
Flask-SQLAlchemy==3.0.5
Flask-Login==0.6.3
psycopg2-binary==2.9.7
gunicorn==21.2.0
APScheduler==3.10.4
beautifulsoup4==4.12.2
lxml==4.9.3
requests==2.31.0
trafilatura==1.6.1
python-dateutil==2.8.2
email-validator==2.0.0
feedparser==6.0.10
Werkzeug==2.3.7
SQLAlchemy==2.0.23
anthropic==0.8.1
xml2js==0.3.0
EOF
fi

print_status "Installing Python dependencies..."
./venv/bin/pip install -r requirements.txt

print_status "Creating environment configuration..."
cat > .env << EOF
DATABASE_URL=postgresql://ayyildiz_user:$DB_PASSWORD@localhost/ayyildiz_haber
SESSION_SECRET=$SECRET_KEY
FLASK_ENV=production
FLASK_DEBUG=False
EOF

print_status "Setting up directories and permissions..."
mkdir -p static/uploads static/images cache logs
chown -R www-data:www-data /var/www/ayyildiz-haber

print_status "Creating Gunicorn configuration..."
cat > gunicorn.conf.py << 'EOF'
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

print_status "Setting up Supervisor..."
cat > /etc/supervisor/conf.d/ayyildiz-haber.conf << 'EOF'
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

supervisorctl reread
supervisorctl update

print_status "Configuring Nginx..."
rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/ayyildiz-haber << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    
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
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_buffering off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    client_max_body_size 10M;
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json;
}
EOF

ln -sf /etc/nginx/sites-available/ayyildiz-haber /etc/nginx/sites-enabled/

print_status "Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    print_status "Nginx configuration is valid, restarting..."
    systemctl restart nginx
else
    print_error "Nginx configuration test failed!"
    exit 1
fi

print_status "Initializing database..."
cd /var/www/ayyildiz-haber
sudo -u www-data ./venv/bin/python << EOF
from app import app, db
from models import Admin

with app.app_context():
    db.create_all()
    print("Database tables created")
    
    # Create admin user
    admin = Admin(
        username='admin',
        email='$ADMIN_EMAIL',
        is_super_admin=True
    )
    admin.set_password('$ADMIN_PASSWORD')
    db.session.add(admin)
    db.session.commit()
    print("Admin user created")
EOF

print_status "Starting application..."
supervisorctl start ayyildiz-haber

print_status "Setting up firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

print_status "Setting up SSL certificate..."
certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos --email $ADMIN_EMAIL

print_status "Setting up automatic backup..."
cat > /usr/local/bin/backup-ayyildiz.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/ayyildiz-haber"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
pg_dump -h localhost -U ayyildiz_user ayyildiz_haber > $BACKUP_DIR/db_$DATE.sql
tar -czf $BACKUP_DIR/files_$DATE.tar.gz -C /var/www/ayyildiz-haber static/uploads

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/backup-ayyildiz.sh

# Add cron jobs
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-ayyildiz.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

print_status "Deployment completed successfully! 🎉"
echo
echo "================================================================"
echo "🌟 Ayyıldız Haber Ajansı is now live!"
echo "================================================================"
echo "🌐 Website: https://$DOMAIN_NAME"
echo "🔐 Admin Panel: https://$DOMAIN_NAME/admin"
echo "📧 Admin Email: $ADMIN_EMAIL"
echo "📁 App Directory: /var/www/ayyildiz-haber"
echo
echo "📋 Useful Commands:"
echo "   Check status: sudo supervisorctl status ayyildiz-haber"
echo "   View logs: sudo tail -f /var/www/ayyildiz-haber/logs/supervisor.log"
echo "   Restart app: sudo supervisorctl restart ayyildiz-haber"
echo "   Nginx test: sudo nginx -t"
echo "   SSL renewal test: sudo certbot renew --dry-run"
echo
echo "🔒 Remember to:"
echo "   - Update DNS records to point to this server"
echo "   - Configure your external APIs (if needed)"
echo "   - Test all functionality"
echo "================================================================"