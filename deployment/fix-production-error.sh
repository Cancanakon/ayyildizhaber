#!/bin/bash

# Ayyıldız Haber Ajansı - Production SQLAlchemy Hatası Düzeltme
# "primary mapper already defined" hatasının kesin çözümü

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}    SQLAlchemy Production Hatası Düzeltme      ${NC}"
echo -e "${GREEN}================================================${NC}"

# Uygulama dizinini kontrol et
if [ ! -d "/var/www/ayyildiz" ]; then
    error "Uygulama dizini bulunamadı: /var/www/ayyildiz"
fi

cd /var/www/ayyildiz

# 1. Uygulamayı durdur
log "Uygulama durdruluyor..."
supervisorctl stop ayyildiz 2>/dev/null || true
pkill -f "gunicorn.*main:app" 2>/dev/null || true
sleep 3

# 2. Python cache temizle
log "Python cache temizleniyor..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.pyo" -delete 2>/dev/null || true

# 3. App.py'yi düzelt - SQLAlchemy çakışmasını önle
log "app.py düzeltiliyor..."
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

# Logging ayarları
logging.basicConfig(level=logging.INFO)

class Base(DeclarativeBase):
    pass

# Global değişkenler
db = SQLAlchemy(model_class=Base)

def create_app():
    """Application factory pattern"""
    app = Flask(__name__)
    
    # Configuration
    app.secret_key = os.environ.get("SESSION_SECRET", "dev-secret-key-change-in-production")
    app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get("DATABASE_URL", "sqlite:///app.db")
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "pool_recycle": 300,
        "pool_pre_ping": True,
    }
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB
    
    # Proxy fix for production
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
    
    # Create tables and import models
    with app.app_context():
        # Import all models AFTER db initialization
        import models
        db.create_all()
        
        # Initialize default data
        from models import Category, Admin, SystemSettings
        
        # Create default categories if not exist
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
            app.logger.info("Default categories created")
        
        # Create default admin if not exist
        if not Admin.query.first():
            from werkzeug.security import generate_password_hash
            admin = Admin(
                username='admin',
                email='admin@gmail.com',
                password_hash=generate_password_hash('admin123'),
                is_super_admin=True,
                is_active=True
            )
            db.session.add(admin)
            db.session.commit()
            app.logger.info("Default admin created: admin@gmail.com / admin123")
    
    # Register blueprints
    from routes import main_bp
    from admin_routes import admin_bp
    from ad_routes import ad_bp
    from admin_config_routes import config_bp
    
    app.register_blueprint(main_bp)
    app.register_blueprint(admin_bp, url_prefix='/admin')
    app.register_blueprint(ad_bp, url_prefix='/ads')
    app.register_blueprint(config_bp, url_prefix='/admin/config')
    
    return app

# Create app instance
app = create_app()

# Background task scheduler
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

# Schedule news fetching every 15 minutes
if not scheduler.running:
    scheduler.add_job(
        func=fetch_external_news,
        trigger=IntervalTrigger(minutes=15),
        id='fetch_external_news',
        name='Fetch external news every 15 minutes',
        replace_existing=True
    )
    
    # Run once at startup after 30 seconds
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

# 4. Models.py'yi düzelt - Tablo çakışmasını önle
log "models.py düzeltiliyor..."
cat > models.py << 'EOF'
from datetime import datetime
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from app import db
import json

class Admin(UserMixin, db.Model):
    __tablename__ = 'admins'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    is_super_admin = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return f'<Admin {self.username}>'

class Category(db.Model):
    __tablename__ = 'categories'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False, unique=True)
    slug = db.Column(db.String(100), nullable=False, unique=True)
    description = db.Column(db.Text)
    color = db.Column(db.String(7), default='#dc2626')
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    news = db.relationship('News', backref='category', lazy='dynamic')

    def __repr__(self):
        return f'<Category {self.name}>'

class News(db.Model):
    __tablename__ = 'news'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    slug = db.Column(db.String(255), nullable=False, unique=True)
    summary = db.Column(db.Text)
    content = db.Column(db.Text, nullable=False)
    featured_image = db.Column(db.String(255))
    images = db.Column(db.Text)
    videos = db.Column(db.Text)
    source = db.Column(db.String(50), default='manual')
    source_url = db.Column(db.String(500))
    author = db.Column(db.String(100))
    status = db.Column(db.String(20), default='draft')
    is_featured = db.Column(db.Boolean, default=False)
    is_breaking = db.Column(db.Boolean, default=False)
    published_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    view_count = db.Column(db.Integer, default=0)
    
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'), nullable=False)
    admin_id = db.Column(db.Integer, db.ForeignKey('admins.id'))
    
    admin = db.relationship('Admin', backref=db.backref('news_created', lazy='dynamic'))

    def increment_view_count(self):
        self.view_count += 1
        db.session.commit()

    def __repr__(self):
        return f'<News {self.title}>'

class NewsView(db.Model):
    __tablename__ = 'news_views'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    news_id = db.Column(db.Integer, db.ForeignKey('news.id'), nullable=False)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.String(500))
    viewed_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    news = db.relationship('News', backref='views')

class SiteStatistics(db.Model):
    __tablename__ = 'site_statistics'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    total_visitors = db.Column(db.Integer, default=0)
    daily_visitors = db.Column(db.Integer, default=0)
    total_news = db.Column(db.Integer, default=0)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow)
    date = db.Column(db.Date, default=datetime.utcnow().date())

class SystemSettings(db.Model):
    __tablename__ = 'system_settings'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), unique=True, nullable=False)
    value = db.Column(db.Text)
    description = db.Column(db.Text)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class UserSession(db.Model):
    __tablename__ = 'user_sessions'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(64), unique=True, nullable=False)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.String(500))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_activity = db.Column(db.DateTime, default=datetime.utcnow)
    
    interactions = db.relationship('UserInteraction', backref='session', lazy='dynamic')

class UserInteraction(db.Model):
    __tablename__ = 'user_interactions'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(64), db.ForeignKey('user_sessions.session_id'), nullable=False)
    news_id = db.Column(db.Integer, db.ForeignKey('news.id'), nullable=False)
    interaction_type = db.Column(db.String(20), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'))
    duration = db.Column(db.Integer, default=0)
    scroll_depth = db.Column(db.Float, default=0.0)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    
    news = db.relationship('News', backref='interactions')
    category = db.relationship('Category', backref='interactions')

class UserPreference(db.Model):
    __tablename__ = 'user_preferences'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(64), db.ForeignKey('user_sessions.session_id'), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'), nullable=False)
    interest_score = db.Column(db.Float, default=0.0)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    session = db.relationship('UserSession', backref='preferences')
    category = db.relationship('Category', backref='user_preferences')

class Advertisement(db.Model):
    __tablename__ = 'advertisements'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    ad_type = db.Column(db.String(20), nullable=False)
    position = db.Column(db.String(20))
    slot_number = db.Column(db.Integer, default=1)
    title = db.Column(db.String(255))
    description = db.Column(db.Text)
    image_path = db.Column(db.String(500), nullable=False)
    link_url = db.Column(db.String(500))
    is_active = db.Column(db.Boolean, default=True)
    click_count = db.Column(db.Integer, default=0)
    impression_count = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    admin_id = db.Column(db.Integer, db.ForeignKey('admins.id'))
    admin = db.relationship('Admin', backref=db.backref('advertisements', lazy='dynamic'))

    def to_dict(self):
        return {
            'id': self.id,
            'ad_type': self.ad_type,
            'position': self.position,
            'slot_number': self.slot_number,
            'title': self.title,
            'description': self.description,
            'image_path': self.image_path,
            'link_url': self.link_url,
            'is_active': self.is_active,
            'click_count': self.click_count,
            'impression_count': self.impression_count
        }

    def increment_clicks(self):
        self.click_count += 1
        db.session.commit()

    def increment_impressions(self):
        self.impression_count += 1
        db.session.commit()
EOF

# 5. Environment dosyasını kontrol et
log "Environment dosyası kontrol ediliyor..."
if [ ! -f ".env" ]; then
    cat > .env << EOF
DATABASE_URL=postgresql://ayyildiz:your_db_password@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF
    chown ayyildiz:ayyildiz .env
    chmod 600 .env
    warning "Environment dosyası oluşturuldu - DATABASE_URL şifresini düzenleyin!"
fi

# 6. Start script'ini düzelt
log "Başlangıç scripti güncelleniyor..."
cat > start_app.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz

# Environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Activate virtual environment
source venv/bin/activate

# Clear Python cache
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true

# Test Flask import
python3 -c "import flask; print('Flask OK')" || exit 1

# Start application
exec gunicorn \
    --bind 127.0.0.1:5000 \
    --workers 2 \
    --worker-class sync \
    --timeout 120 \
    --keep-alive 5 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --access-logfile /var/log/ayyildiz_access.log \
    --error-logfile /var/log/ayyildiz_error.log \
    --log-level info \
    main:app
EOF

chmod +x start_app.sh
chown ayyildiz:ayyildiz start_app.sh

# 7. Main.py'yi basit tut
log "main.py oluşturuluyor..."
cat > main.py << 'EOF'
from app import app

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

chown ayyildiz:ayyildiz main.py

# 8. Veritabanını yeniden initialize et
log "Veritabanı yeniden başlatılıyor..."
sudo -u ayyildiz bash << 'DBEOF'
source venv/bin/activate
source .env 2>/dev/null || true
python3 -c "
from app import app, db
print('Database initialization starting...')
with app.app_context():
    try:
        db.create_all()
        print('Database tables created successfully')
    except Exception as e:
        print(f'Database error: {e}')
        exit(1)
"
DBEOF

# 9. Ownership ve permissions
log "Dosya sahiplikleri düzenleniyor..."
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod -R 755 /var/www/ayyildiz
chmod 600 /var/www/ayyildiz/.env

# 10. Servisleri yeniden başlat
log "Servisler yeniden başlatılıyor..."
supervisorctl reread
supervisorctl update
supervisorctl start ayyildiz
systemctl restart nginx

# 11. Test et
log "Uygulama testi yapılıyor..."
sleep 10

for i in {1..15}; do
    if curl -s http://127.0.0.1:5000 > /dev/null; then
        log "✓ Uygulama başarıyla çalışıyor!"
        break
    else
        log "Test $i: Uygulama başlatılıyor..."
        sleep 2
    fi
    
    if [ $i -eq 15 ]; then
        error "Uygulama başlatılamadı - logları kontrol edin"
    fi
done

# 12. Durum raporu
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}    SQLALCHEMY HATASI DÜZELTİLDİ!             ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

supervisorctl status ayyildiz
echo ""
log "Web sitesi: http://69.62.110.158"
log "Admin panel: http://69.62.110.158/admin"
log "Giriş: admin@gmail.com / admin123"
echo ""
log "Loglar: tail -f /var/log/ayyildiz.log"
echo ""
log "Düzeltme tamamlandı!"
EOF

chmod +x deployment/fix-production-error.sh