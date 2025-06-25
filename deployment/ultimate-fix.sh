#!/bin/bash

# Ayyıldız Haber Ajansı - Ultimate SQLAlchemy Fix
# Circular import ve mapper sorunlarının kesin çözümü

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
echo -e "${GREEN}    ULTIMATE SQLALCHEMY FIX                   ${NC}"
echo -e "${GREEN}================================================${NC}"

cd /var/www/ayyildiz

# 1. Tüm Python process'leri durdur
log "Tüm Python süreçleri durdruluyor..."
supervisorctl stop all 2>/dev/null || true
pkill -f python 2>/dev/null || true
pkill -f gunicorn 2>/dev/null || true
sleep 5

# 2. Python cache'i tamamen temizle
log "Python cache temizleniyor..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.pyo" -delete 2>/dev/null || true
rm -rf .pytest_cache 2>/dev/null || true

# 3. Tamamen yeni app.py oluştur - circular import'u önle
log "Yeni app.py oluşturuluyor..."
cat > app.py << 'EOF'
import os
import logging
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from sqlalchemy.orm import DeclarativeBase
from werkzeug.middleware.proxy_fix import ProxyFix

# Logging setup
logging.basicConfig(level=logging.INFO)

class Base(DeclarativeBase):
    pass

# Global extensions
db = SQLAlchemy(model_class=Base)
login_manager = LoginManager()

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
    login_manager.init_app(app)
    login_manager.login_view = 'admin_routes.login'
    login_manager.login_message = 'Bu sayfaya erişmek için giriş yapmalısınız.'
    login_manager.login_message_category = 'warning'
    
    @login_manager.user_loader
    def load_user(user_id):
        # Import here to avoid circular import
        from models import Admin
        return Admin.query.get(int(user_id))
    
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

def init_database(app):
    """Initialize database with default data"""
    with app.app_context():
        # Import models after app context
        import models
        
        # Create all tables
        db.create_all()
        
        # Create default categories
        from models import Category, Admin
        from werkzeug.security import generate_password_hash
        
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
        app.logger.info("Database initialized successfully")

# Create app instance
app = create_app()

if __name__ == '__main__':
    init_database(app)
    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

# 4. Models.py'yi yeniden yaz - extend_existing ekle
log "Models.py yeniden yazılıyor..."
cat > models.py << 'EOF'
from datetime import datetime
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from app import db

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

class UserPreference(db.Model):
    __tablename__ = 'user_preferences'
    __table_args__ = {'extend_existing': True}
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(64), db.ForeignKey('user_sessions.session_id'), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'), nullable=False)
    interest_score = db.Column(db.Float, default=0.0)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

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

# 5. Basit main.py
log "main.py oluşturuluyor..."
cat > main.py << 'EOF'
from app import app, init_database

# Initialize database on startup
init_database(app)

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

# 6. Start script
log "Start script oluşturuluyor..."
cat > start_app.sh << 'EOF'
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

# Test import
python3 -c "
try:
    from app import app
    print('App import: SUCCESS')
except Exception as e:
    print(f'App import: FAILED - {e}')
    exit(1)
"

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

chmod +x start_app.sh

# 7. Database initialization script
log "Database init script oluşturuluyor..."
cat > init_db.py << 'EOF'
#!/usr/bin/env python3
import os
import sys

# Add current directory to path
sys.path.insert(0, '/var/www/ayyildiz')

# Set environment
os.environ['DATABASE_URL'] = os.environ.get('DATABASE_URL', 'postgresql://ayyildiz:password@localhost/ayyildiz_db')
os.environ['SESSION_SECRET'] = os.environ.get('SESSION_SECRET', 'dev-secret')

try:
    from app import app, init_database
    print("Importing app: SUCCESS")
    
    print("Initializing database...")
    init_database(app)
    print("Database initialization: SUCCESS")
    
except Exception as e:
    print(f"Database initialization: FAILED - {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

chmod +x init_db.py

# 8. Environment dosyası kontrol
log "Environment kontrol ediliyor..."
if [ ! -f ".env" ]; then
    cat > .env << EOF
DATABASE_URL=postgresql://ayyildiz:MySecurePass123@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF
    chmod 600 .env
fi

chown ayyildiz:ayyildiz .env

# 9. Database test
log "Database bağlantısı test ediliyor..."
sudo -u postgres psql -c "SELECT version();" >/dev/null 2>&1 || {
    error "PostgreSQL çalışmıyor!"
}

sudo -u postgres psql -c "\l" | grep ayyildiz_db >/dev/null || {
    log "Database oluşturuluyor..."
    sudo -u postgres createdb ayyildiz_db -O ayyildiz 2>/dev/null || true
}

# 10. Database initialize et
log "Database initialize ediliyor..."
sudo -u ayyildiz bash << 'DBEOF'
cd /var/www/ayyildiz
source venv/bin/activate
source .env
python3 init_db.py
DBEOF

# 11. Ownership fix
log "File permissions düzenleniyor..."
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod -R 755 /var/www/ayyildiz
chmod 600 /var/www/ayyildiz/.env
chmod +x /var/www/ayyildiz/*.py
chmod +x /var/www/ayyildiz/*.sh

# 12. Supervisor restart
log "Supervisor yeniden başlatılıyor..."
supervisorctl reread
supervisorctl update
supervisorctl start ayyildiz

# 13. Nginx restart
systemctl restart nginx

# 14. Test application
log "Uygulama test ediliyor..."
sleep 15

TEST_RESULT="FAILED"
for i in {1..20}; do
    if curl -s http://127.0.0.1:5000 >/dev/null 2>&1; then
        TEST_RESULT="SUCCESS"
        break
    else
        log "Test $i/20: Bekleniyor..."
        sleep 3
    fi
done

# 15. Final report
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}    ULTIMATE FIX TAMAMLANDI                    ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

supervisorctl status ayyildiz
echo ""
echo -e "Test Result: ${GREEN}$TEST_RESULT${NC}"
echo -e "Web Site: ${GREEN}http://69.62.110.158${NC}"
echo -e "Admin Panel: ${GREEN}http://69.62.110.158/admin${NC}"
echo -e "Login: ${GREEN}admin@gmail.com / admin123${NC}"
echo ""

if [ "$TEST_RESULT" = "SUCCESS" ]; then
    log "✓ Siteniz başarıyla çalışıyor!"
else
    warning "✗ Site yanıt vermiyor - logları kontrol edin:"
    echo "  tail -f /var/log/ayyildiz_error.log"
    echo "  supervisorctl status"
fi

echo ""
log "Ultimate fix tamamlandı!"
EOF

chmod +x deployment/ultimate-fix.sh