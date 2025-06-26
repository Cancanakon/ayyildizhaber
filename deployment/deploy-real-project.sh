#!/bin/bash

# Ayyıldız Haber Ajansı - Gerçek Projeyi VPS'e Kurulum
# Replit'teki tam projeyi VPS'e taşıma

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[HATA] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[UYARI] $1${NC}"
}

clear
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    Ayyıldız Haber Ajansı - Gerçek Proje       ${NC}"
echo -e "${BLUE}    Replit'ten VPS'e Tam Taşıma                ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Root check
if [[ $EUID -ne 0 ]]; then
   error "Bu script root kullanıcısı ile çalıştırılmalıdır: sudo $0"
fi

# 1. Tamamen temizle
log "Eski kurulum tamamen temizleniyor..."
supervisorctl stop all 2>/dev/null || true
pkill -f python 2>/dev/null || true
pkill -f gunicorn 2>/dev/null || true

rm -rf /var/www/ayyildiz 2>/dev/null || true
rm -f /etc/supervisor/conf.d/ayyildiz.conf 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/ayyildiz 2>/dev/null || true
rm -f /etc/nginx/sites-available/ayyildiz 2>/dev/null || true

# 2. Gerekli paketleri kur
log "Sistem paketleri kuruluyor..."
apt update -y
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git curl wget ufw build-essential libpq-dev

# 3. PostgreSQL hazırlığı
log "PostgreSQL yapılandırılıyor..."
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres dropdb ayyildiz_db 2>/dev/null || true
sudo -u postgres dropuser ayyildiz 2>/dev/null || true
sudo -u postgres createuser ayyildiz
sudo -u postgres createdb ayyildiz_db -O ayyildiz
sudo -u postgres psql -c "ALTER USER ayyildiz PASSWORD 'SecurePass123';"

# 4. Kullanıcı hazırlığı
log "Kullanıcı hazırlanıyor..."
userdel -r ayyildiz 2>/dev/null || true
useradd -m -s /bin/bash ayyildiz

# 5. Uygulama dizini oluştur
log "Uygulama dizini oluşturuluyor..."
mkdir -p /var/www/ayyildiz
cd /var/www/ayyildiz

# 6. GitHub'dan gerçek projeyi çek
log "GitHub'dan gerçek proje indiriliyor..."
read -p "GitHub Repository URL'nizi girin: " GITHUB_URL
if [[ -z "$GITHUB_URL" ]]; then
    error "GitHub URL gerekli!"
fi

git clone $GITHUB_URL temp_repo
cp -r temp_repo/* .
rm -rf temp_repo

# 7. Python sanal ortam
log "Python sanal ortamı kuruluyor..."
python3 -m venv venv
source venv/bin/activate

# 8. Python paketlerini yükle
log "Python paketleri yükleniyor..."
pip install --upgrade pip

# Temel Flask paketleri
pip install flask==2.3.3
pip install flask-sqlalchemy==3.0.5
pip install flask-login==0.6.3
pip install werkzeug==2.3.7
pip install gunicorn==21.2.0
pip install psycopg2-binary==2.9.7

# Proje paketleri
pip install apscheduler==3.10.4
pip install beautifulsoup4==4.12.2
pip install lxml>=4.9.0
pip install requests==2.31.0
pip install trafilatura>=1.6.0
pip install email-validator==2.0.0
pip install feedparser==6.0.10
pip install python-dateutil==2.8.2

# 9. App.py'yi production için düzelt
log "App.py production için düzenleniyor..."
cp app.py app.py.backup

cat > app.py << 'EOF'
import os
import logging
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from sqlalchemy.orm import DeclarativeBase
from werkzeug.middleware.proxy_fix import ProxyFix
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
import atexit

# Logging setup
logging.basicConfig(level=logging.INFO)

class Base(DeclarativeBase):
    pass

# Global extensions
db = SQLAlchemy(model_class=Base)

def create_app():
    """Application factory"""
    app = Flask(__name__)
    
    # Configuration
    app.secret_key = os.environ.get("SESSION_SECRET", "dev-secret-key-change-in-production")
    app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get("DATABASE_URL", "sqlite:///app.db")
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "pool_recycle": 300,
        "pool_pre_ping": True,
    }
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024
    
    # Proxy fix
    app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)
    
    # Initialize extensions
    db.init_app(app)
    
    # Login manager
    login_manager = LoginManager()
    login_manager.init_app(app)
    login_manager.login_view = 'admin_routes.login'
    login_manager.login_message = 'Bu sayfaya erişmek için giriş yapmalısınız.'
    login_manager.login_message_category = 'warning'
    
    @login_manager.user_loader
    def load_user(user_id):
        from models import Admin
        return Admin.query.get(int(user_id))
    
    # Import models and create tables
    with app.app_context():
        import models
        db.create_all()
        
        # Initialize default data
        init_default_data()
    
    # Register blueprints
    register_blueprints(app)
    
    return app

def register_blueprints(app):
    """Register all blueprints"""
    try:
        from routes import main_bp
        app.register_blueprint(main_bp)
    except ImportError as e:
        app.logger.warning(f"Could not import main routes: {e}")
    
    try:
        from admin_routes import admin_bp
        app.register_blueprint(admin_bp, url_prefix='/admin')
    except ImportError as e:
        app.logger.warning(f"Could not import admin routes: {e}")
    
    try:
        from ad_routes import ad_bp
        app.register_blueprint(ad_bp, url_prefix='/ads')
    except ImportError as e:
        app.logger.warning(f"Could not import ad routes: {e}")
    
    try:
        from admin_config_routes import config_bp
        app.register_blueprint(config_bp, url_prefix='/admin/config')
    except ImportError as e:
        app.logger.warning(f"Could not import config routes: {e}")

def init_default_data():
    """Initialize default data"""
    from models import Category, Admin
    from werkzeug.security import generate_password_hash
    
    # Create default categories
    if not Category.query.first():
        categories = [
            {'name': 'Gündem', 'slug': 'gundem', 'color': '#dc2626'},
            {'name': 'Ekonomi', 'slug': 'ekonomi', 'color': '#059669'},
            {'name': 'Spor', 'slug': 'spor', 'color': '#7c3aed'},
            {'name': 'Teknoloji', 'slug': 'teknoloji', 'color': '#2563eb'},
            {'name': 'Sağlık', 'slug': 'saglik', 'color': '#dc2626'},
            {'name': 'Kültür-Sanat', 'slug': 'kultur-sanat', 'color': '#7c2d12'},
            {'name': 'Dünya', 'slug': 'dunya', 'color': '#1f2937'},
            {'name': 'Politika', 'slug': 'politika', 'color': '#991b1b'},
            {'name': 'Yerel Haberler', 'slug': 'yerel-haberler', 'color': '#0369a1'}
        ]
        
        for cat_data in categories:
            category = Category(**cat_data)
            db.session.add(category)
        
        db.session.commit()
    
    # Create default admin
    if not Admin.query.first():
        admin = Admin(
            username='admin',
            email='admin@gmail.com',
            password_hash=generate_password_hash('admin123'),
            is_super_admin=True,
            is_active=True
        )
        db.session.add(admin)
        db.session.commit()

# Create app
app = create_app()

# Background scheduler
scheduler = BackgroundScheduler()

def fetch_external_news():
    """Background task to fetch news from TRT and other sources"""
    with app.app_context():
        try:
            from services.trt_news_service import fetch_and_save_trt_news
            fetch_and_save_trt_news()
            app.logger.info("External news fetched successfully")
        except Exception as e:
            app.logger.error(f"Error fetching external news: {e}")

# Schedule news fetching
if not scheduler.running:
    scheduler.add_job(
        func=fetch_external_news,
        trigger=IntervalTrigger(minutes=15),
        id='fetch_external_news',
        name='Fetch external news every 15 minutes',
        replace_existing=True
    )
    
    scheduler.add_job(
        func=fetch_external_news,
        trigger='date',
        id='startup_news_job',
        name='Startup news fetch'
    )
    
    scheduler.start()
    atexit.register(lambda: scheduler.shutdown())

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

# 10. Models.py'yi düzelt
log "Models.py düzenleniyor..."
# Models.py zaten mevcut, sadece extend_existing ekle
if ! grep -q "extend_existing" models.py; then
    sed -i 's/__tablename__ = /&/g; s/__tablename__ = \(.*\)/__tablename__ = \1\n    __table_args__ = {"extend_existing": True}/g' models.py
fi

# 11. Environment dosyası
log "Environment dosyası oluşturuluyor..."
cat > .env << EOF
DATABASE_URL=postgresql://ayyildiz:SecurePass123@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF

# 12. Main.py
log "Main.py oluşturuluyor..."
cat > main.py << 'EOF'
from app import app

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

# 13. Start script
log "Start script oluşturuluyor..."
cat > start.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Activate venv
source venv/bin/activate

# Clear cache
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true

# Start Gunicorn
exec gunicorn \
    --bind 127.0.0.1:5000 \
    --workers 2 \
    --worker-class sync \
    --timeout 120 \
    --keep-alive 5 \
    --max-requests 1000 \
    --preload \
    --access-logfile /var/log/ayyildiz_access.log \
    --error-logfile /var/log/ayyildiz_error.log \
    --log-level info \
    main:app
EOF

chmod +x start.sh

# 14. Gerekli dizinler
log "Gerekli dizinler oluşturuluyor..."
mkdir -p static/uploads/{images,videos}
mkdir -p cache
mkdir -p templates

# 15. Supervisor config
log "Supervisor yapılandırılıyor..."
systemctl enable supervisor
systemctl start supervisor

cat > /etc/supervisor/conf.d/ayyildiz.conf << EOF
[program:ayyildiz]
command=/var/www/ayyildiz/start.sh
directory=/var/www/ayyildiz
user=ayyildiz
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/ayyildiz.log
stderr_logfile=/var/log/ayyildiz_error.log
environment=PATH="/var/www/ayyildiz/venv/bin:/usr/local/bin:/usr/bin:/bin"
EOF

# 16. Nginx config
log "Nginx yapılandırılıyor..."
cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    client_max_body_size 50M;
    
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

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ayyildiz /etc/nginx/sites-enabled/

# 17. Permissions
log "İzinler ayarlanıyor..."
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod +x /var/www/ayyildiz/start.sh
chmod 600 /var/www/ayyildiz/.env

# 18. Database initialization
log "Database başlatılıyor..."
sudo -u ayyildiz bash << 'DBEOF'
cd /var/www/ayyildiz
source venv/bin/activate
source .env
python3 -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Database initialized successfully')
"
DBEOF

# 19. Services başlat
log "Servisler başlatılıyor..."
nginx -t
systemctl restart nginx

supervisorctl reread
supervisorctl update
supervisorctl start ayyildiz

# 20. Firewall
log "Firewall ayarlanıyor..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# 21. Test
log "Uygulama test ediliyor..."
sleep 15

for i in {1..20}; do
    if curl -s http://127.0.0.1:5000 > /dev/null; then
        log "✅ Gerçek proje başarıyla çalışıyor!"
        break
    else
        log "Test $i/20: Bekleniyor..."
        sleep 3
    fi
    
    if [ $i -eq 20 ]; then
        warning "Uygulama henüz yanıt vermiyor"
    fi
done

# 22. Final report
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}    GERÇEK PROJE KURULUMU TAMAMLANDI          ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

supervisorctl status ayyildiz
echo ""

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000 || echo "000")
echo -e "${BLUE}Web Sitesi:${NC} http://69.62.110.158"
echo -e "${BLUE}Admin Panel:${NC} http://69.62.110.158/admin"
echo -e "${BLUE}HTTP Status:${NC} $HTTP_STATUS"
echo ""
echo -e "${BLUE}Giriş Bilgileri:${NC}"
echo -e "  Email: ${GREEN}admin@gmail.com${NC}"
echo -e "  Şifre: ${GREEN}admin123${NC}"
echo ""
echo -e "${BLUE}Loglar:${NC}"
echo -e "  Uygulama: ${GREEN}tail -f /var/log/ayyildiz.log${NC}"
echo -e "  Hatalar: ${GREEN}tail -f /var/log/ayyildiz_error.log${NC}"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
    log "🎉 Gerçek proje başarıyla kuruldu ve çalışıyor!"
else
    log "⚠️ Kurulum tamamlandı ama site henüz yanıt vermiyor"
    log "Logları kontrol edin: tail -f /var/log/ayyildiz.log"
fi

echo ""
log "Gerçek proje kurulumu tamamlandı!"
EOF

chmod +x deployment/deploy-real-project.sh