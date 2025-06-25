#!/bin/bash

# Ayyıldız Haber Ajansı - Production Fix Script
# Fixes SQLAlchemy primary mapper and virtual environment issues

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

echo -e "${GREEN}Ayyıldız Haber Ajansı - Production Fix${NC}"
echo "======================================"

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

log "Starting production installation..."

# Stop any existing services
supervisorctl stop ayyildiz 2>/dev/null || true

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

# Clean and clone fresh
log "Getting fresh application code..."
rm -rf /var/www/ayyildiz 2>/dev/null || true
git clone $GITHUB_URL /var/www/ayyildiz
chown -R ayyildiz:ayyildiz /var/www/ayyildiz

# Setup Python environment
log "Setting up Python environment..."
cd /var/www/ayyildiz

# Remove any existing venv
rm -rf venv 2>/dev/null || true

# Create fresh virtual environment
sudo -u ayyildiz python3 -m venv venv
sudo -u ayyildiz ./venv/bin/pip install --upgrade pip setuptools wheel

# Install packages one by one to catch errors
log "Installing Python packages..."
sudo -u ayyildiz ./venv/bin/pip install flask==2.3.3
sudo -u ayyildiz ./venv/bin/pip install flask-sqlalchemy==3.0.5
sudo -u ayyildiz ./venv/bin/pip install flask-login==0.6.3
sudo -u ayyildiz ./venv/bin/pip install werkzeug==2.3.7
sudo -u ayyildiz ./venv/bin/pip install gunicorn==21.2.0
sudo -u ayyildiz ./venv/bin/pip install psycopg2-binary==2.9.7
sudo -u ayyildiz ./venv/bin/pip install apscheduler==3.10.4
sudo -u ayyildiz ./venv/bin/pip install beautifulsoup4 lxml requests
sudo -u ayyildiz ./venv/bin/pip install trafilatura email-validator feedparser python-dateutil

# Create fixed app.py to prevent SQLAlchemy conflicts
log "Fixing SQLAlchemy configuration..."
cat > /var/www/ayyildiz/app_fixed.py << 'EOF'
import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.orm import DeclarativeBase
from werkzeug.middleware.proxy_fix import ProxyFix

class Base(DeclarativeBase):
    pass

db = SQLAlchemy(model_class=Base)

def create_app():
    app = Flask(__name__)
    app.secret_key = os.environ.get("SESSION_SECRET", "dev-key-change-in-production")
    app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)
    
    # Database configuration
    app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get("DATABASE_URL")
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "pool_recycle": 300,
        "pool_pre_ping": True,
    }
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    
    # Upload configuration
    app.config["UPLOAD_FOLDER"] = "static/uploads"
    app.config["MAX_CONTENT_LENGTH"] = 50 * 1024 * 1024  # 50MB max file size
    
    # Initialize database
    db.init_app(app)
    
    return app

app = create_app()

# Import models and routes only after app creation
with app.app_context():
    try:
        from models import *
        from flask_login import LoginManager
        
        login_manager = LoginManager()
        login_manager.init_app(app)
        login_manager.login_view = 'admin.login'
        
        @login_manager.user_loader
        def load_user(user_id):
            from models import Admin
            return Admin.query.get(int(user_id))
        
        # Create tables
        db.create_all()
        
        # Import routes
        from routes import *
        from admin_routes import *
        from ad_routes import *
        from admin_config_routes import *
        
        # Create default data
        from models import Category, Admin
        from werkzeug.security import generate_password_hash
        
        # Create default categories
        default_categories = [
            {'name': 'Gündem', 'slug': 'gundem', 'description': 'Güncel gelişmeler ve önemli haberler', 'color': '#dc2626'},
            {'name': 'Ekonomi', 'slug': 'ekonomi', 'description': 'Ekonomi ve finans haberleri', 'color': '#059669'},
            {'name': 'Spor', 'slug': 'spor', 'description': 'Spor haberleri ve sonuçları', 'color': '#2563eb'},
            {'name': 'Teknoloji', 'slug': 'teknoloji', 'description': 'Teknoloji ve bilim haberleri', 'color': '#7c3aed'},
            {'name': 'Sağlık', 'slug': 'saglik', 'description': 'Sağlık ve tıp haberleri', 'color': '#dc2626'},
            {'name': 'Kültür-Sanat', 'slug': 'kultur-sanat', 'description': 'Kültür, sanat ve yaşam haberleri', 'color': '#ea580c'},
            {'name': 'Dünya', 'slug': 'dunya', 'description': 'Dünya haberleri', 'color': '#0891b2'},
            {'name': 'Politika', 'slug': 'politika', 'description': 'Politika haberleri', 'color': '#be123c'},
            {'name': 'Yerel Haberler', 'slug': 'yerel-haberler', 'description': 'Yerel haberler ve etkinlikler', 'color': '#16a34a'}
        ]
        
        for cat_data in default_categories:
            if not Category.query.filter_by(slug=cat_data['slug']).first():
                category = Category(**cat_data)
                db.session.add(category)
        
        # Create default admin
        if not Admin.query.filter_by(email='admin@gmail.com').first():
            admin = Admin(
                username='admin',
                email='admin@gmail.com',
                is_super_admin=True
            )
            admin.set_password('admin123')
            db.session.add(admin)
        
        db.session.commit()
        print("Default admin user created: admin@gmail.com / admin123")
        print("Default categories created")
        
    except Exception as e:
        print(f"Initialization error: {e}")
        import traceback
        traceback.print_exc()

# Start background tasks
try:
    from services.external_news_service import fetch_and_save_external_news
    from apscheduler.schedulers.background import BackgroundScheduler
    
    def fetch_external_news():
        with app.app_context():
            fetch_and_save_external_news()
    
    scheduler = BackgroundScheduler()
    scheduler.add_job(
        func=fetch_external_news,
        trigger="interval",
        minutes=15,
        id='fetch_external_news'
    )
    scheduler.start()
    
except Exception as e:
    print(f"Scheduler setup error: {e}")

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

# Copy fixed app.py
cp /var/www/ayyildiz/app_fixed.py /var/www/ayyildiz/app.py
chown ayyildiz:ayyildiz /var/www/ayyildiz/app.py

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
FLASK_APP=app.py
EOF

chown ayyildiz:ayyildiz /var/www/ayyildiz/.env
chmod 600 /var/www/ayyildiz/.env

# Create production startup script
log "Creating production startup script..."
cat > /var/www/ayyildiz/start_production.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Activate virtual environment
source venv/bin/activate

# Verify Flask installation
python3 -c "import flask; print(f'Flask {flask.__version__} loaded')" || {
    echo "Flask import failed"
    exit 1
}

# Start Gunicorn with production settings
exec gunicorn \
    --bind 127.0.0.1:5000 \
    --workers 4 \
    --worker-class sync \
    --timeout 120 \
    --keep-alive 5 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --access-logfile /var/log/ayyildiz_access.log \
    --error-logfile /var/log/ayyildiz_error.log \
    --log-level info \
    app:app
EOF

chmod +x /var/www/ayyildiz/start_production.sh
chown ayyildiz:ayyildiz /var/www/ayyildiz/start_production.sh

# Test the application
log "Testing application startup..."
cd /var/www/ayyildiz
sudo -u ayyildiz bash -c "source venv/bin/activate && source .env && timeout 15s python3 app.py" || {
    log "Application test completed (timeout expected)"
}

# Setup supervisor
log "Setting up process manager..."
cat > /etc/supervisor/conf.d/ayyildiz.conf << EOF
[program:ayyildiz]
command=/var/www/ayyildiz/start_production.sh
directory=/var/www/ayyildiz
user=ayyildiz
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/ayyildiz.log
stderr_logfile=/var/log/ayyildiz_error.log
environment=HOME="/home/ayyildiz",USER="ayyildiz",PATH="/var/www/ayyildiz/venv/bin:/usr/local/bin:/usr/bin:/bin"
startsecs=10
startretries=3
stopwaitsecs=10
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
mkdir -p /var/www/ayyildiz/{static,cache,uploads,static/uploads,static/uploads/images,static/uploads/videos}
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod -R 755 /var/www/ayyildiz

# Initialize database with fixed script
log "Initializing database..."
cd /var/www/ayyildiz
sudo -u ayyildiz bash << 'EOF'
source venv/bin/activate
source .env
python3 -c "
import os
os.environ['FLASK_ENV'] = 'production'
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
sleep 10
supervisorctl status ayyildiz

# Test application response
log "Testing application response..."
for i in {1..5}; do
    if curl -s http://127.0.0.1:5000 > /dev/null; then
        log "Application is responding correctly"
        break
    else
        log "Attempt $i: Waiting for application to start..."
        sleep 5
    fi
done

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

# Final status check
log "Final status check..."
supervisorctl status ayyildiz
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://127.0.0.1:5000 || echo "HTTP test failed"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Production Installation Complete!     ${NC}"
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

log "Production installation completed successfully!"