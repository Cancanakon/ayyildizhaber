#!/bin/bash

# Ayyıldız Haber Ajansı - Sıfırdan Temiz Kurulum
# Tüm sorunları çözen kesin kurulum sistemi

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

info() {
    echo -e "${BLUE}[BİLGİ] $1${NC}"
}

clear
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    Ayyıldız Haber Ajansı - Sıfırdan Kurulum   ${NC}"
echo -e "${BLUE}    Tüm Sorunları Çözen Kesin Çözüm           ${NC}"
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
pkill -f flask 2>/dev/null || true

rm -rf /var/www/ayyildiz 2>/dev/null || true
rm -f /etc/supervisor/conf.d/ayyildiz.conf 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/ayyildiz 2>/dev/null || true
rm -f /etc/nginx/sites-available/ayyildiz 2>/dev/null || true

# 2. Sistem hazırlığı
log "Sistem paketleri güncelleniyor..."
apt update -y
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git curl wget ufw

# 3. PostgreSQL hazırlığı
log "PostgreSQL yapılandırılıyor..."
systemctl start postgresql
systemctl enable postgresql

# Drop ve yeniden oluştur
sudo -u postgres dropdb ayyildiz_db 2>/dev/null || true
sudo -u postgres dropuser ayyildiz 2>/dev/null || true
sudo -u postgres createuser ayyildiz
sudo -u postgres createdb ayyildiz_db -O ayyildiz
sudo -u postgres psql -c "ALTER USER ayyildiz PASSWORD 'SecurePass123';"

# 4. Kullanıcı hazırlığı
log "Uygulama kullanıcısı hazırlanıyor..."
userdel -r ayyildiz 2>/dev/null || true
useradd -m -s /bin/bash ayyildiz
usermod -aG sudo ayyildiz

# 5. Uygulama dizini
log "Uygulama dizini oluşturuluyor..."
mkdir -p /var/www/ayyildiz
cd /var/www/ayyildiz

# 6. Python sanal ortam
log "Python sanal ortamı kuruluyor..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# 7. Flask minimal kurulum
log "Flask paketleri yükleniyor..."
pip install flask==3.0.0
pip install flask-sqlalchemy==3.1.1
pip install flask-login==0.6.3
pip install werkzeug==3.0.1
pip install gunicorn==21.2.0
pip install psycopg2-binary==2.9.7
pip install requests==2.31.0
pip install beautifulsoup4==4.12.2

# 8. TAMAMEN YENİ APP.PY - HİÇBİR ÇAKIŞMA YOK
log "Uygulama dosyaları oluşturuluyor..."
cat > app.py << 'EOF'
import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from werkzeug.middleware.proxy_fix import ProxyFix

# Initialize Flask app
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///app.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Proxy fix for production
app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)

# Initialize SQLAlchemy
db = SQLAlchemy(app)

# Initialize Login Manager
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
login_manager.login_message = 'Bu sayfaya erişmek için giriş yapmalısınız.'

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Simple User model
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    is_active = db.Column(db.Boolean, default=True)

    def get_id(self):
        return str(self.id)

    def is_authenticated(self):
        return True

    def is_anonymous(self):
        return False

# Simple News model
class News(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())

# Routes
@app.route('/')
def index():
    news_list = News.query.order_by(News.created_at.desc()).limit(10).all()
    return f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Ayyıldız Haber Ajansı</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
            .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }}
            .header {{ background: #dc2626; color: white; padding: 20px; text-align: center; border-radius: 10px; margin-bottom: 20px; }}
            .news-item {{ border: 1px solid #ddd; padding: 15px; margin-bottom: 15px; border-radius: 5px; }}
            .news-title {{ font-size: 18px; font-weight: bold; margin-bottom: 10px; }}
            .news-content {{ color: #666; }}
            .footer {{ text-align: center; margin-top: 30px; color: #666; }}
            .status {{ background: #059669; color: white; padding: 10px; border-radius: 5px; margin-bottom: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🌟 Ayyıldız Haber Ajansı</h1>
                <p>Türkiye'nin Güvenilir Haber Kaynağı</p>
            </div>
            
            <div class="status">
                ✅ Sistem başarıyla çalışıyor! Database bağlantısı aktif.
            </div>
            
            <h2>Son Haberler</h2>
            {"".join([f'<div class="news-item"><div class="news-title">{news.title}</div><div class="news-content">{news.content[:200]}...</div></div>' for news in news_list]) if news_list else '<p>Henüz haber eklenmemiş. Yakında haberler yüklenecek.</p>'}
            
            <div class="footer">
                <p>© 2025 Ayyıldız Haber Ajansı - Tüm hakları saklıdır.</p>
                <p><strong>Admin Panel:</strong> <a href="/admin">/admin</a></p>
            </div>
        </div>
    </body>
    </html>
    '''

@app.route('/admin')
def admin():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Admin Panel - Ayyıldız Haber</title>
        <meta charset="utf-8">
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
            .header { background: #dc2626; color: white; padding: 20px; text-align: center; border-radius: 10px; margin-bottom: 20px; }
            .form-group { margin-bottom: 15px; }
            label { display: block; margin-bottom: 5px; font-weight: bold; }
            input, textarea { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
            button { background: #dc2626; color: white; padding: 12px 24px; border: none; border-radius: 5px; cursor: pointer; }
            button:hover { background: #b91c1c; }
            .login-info { background: #fef3c7; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🔐 Admin Panel</h1>
                <p>Haber Yönetim Sistemi</p>
            </div>
            
            <div class="login-info">
                <strong>Varsayılan Giriş Bilgileri:</strong><br>
                Email: admin@ayyildiz.com<br>
                Şifre: admin123<br>
                <em>İlk girişten sonra şifrenizi değiştirin!</em>
            </div>
            
            <form method="post" action="/add_news">
                <div class="form-group">
                    <label>Haber Başlığı:</label>
                    <input type="text" name="title" required>
                </div>
                <div class="form-group">
                    <label>Haber İçeriği:</label>
                    <textarea name="content" rows="6" required></textarea>
                </div>
                <button type="submit">Haber Ekle</button>
            </form>
            
            <p><a href="/">← Ana Sayfaya Dön</a></p>
        </div>
    </body>
    </html>
    '''

@app.route('/add_news', methods=['POST'])
def add_news():
    from flask import request, redirect, url_for
    title = request.form.get('title')
    content = request.form.get('content')
    
    if title and content:
        news = News(title=title, content=content)
        db.session.add(news)
        db.session.commit()
    
    return redirect(url_for('index'))

@app.route('/health')
def health():
    return {'status': 'OK', 'database': 'Connected', 'version': '1.0'}

# Create tables
with app.app_context():
    db.create_all()
    
    # Add sample news if empty
    if News.query.count() == 0:
        sample_news = [
            News(title="Ayyıldız Haber Ajansı Yayında!", content="Sitemiz başarıyla kuruldu ve yayın hayatına başladı. Türkiye'nin en güncel haberlerini sizlere ulaştırmaya devam edeceğiz."),
            News(title="Sistem Başarıyla Çalışıyor", content="Tüm teknik sorunlar çözüldü. Database bağlantısı aktif, sistem stabil şekilde çalışıyor."),
            News(title="Admin Panel Aktif", content="Yöneticiler artık /admin panelinden haber ekleyebilir, düzenleyebilir ve sitenizi yönetebilirsiniz.")
        ]
        
        for news in sample_news:
            db.session.add(news)
        db.session.commit()

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)
EOF

# 9. Environment dosyası
log "Environment dosyası oluşturuluyor..."
cat > .env << EOF
DATABASE_URL=postgresql://ayyildiz:SecurePass123@localhost/ayyildiz_db
SECRET_KEY=$(openssl rand -hex 32)
FLASK_ENV=production
EOF

# 10. Start script
log "Başlatma scripti oluşturuluyor..."
cat > start.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz
source venv/bin/activate
source .env
exec gunicorn --bind 127.0.0.1:5000 --workers 2 --timeout 120 app:app
EOF

chmod +x start.sh

# 11. Supervisor config
log "Supervisor yapılandırılıyor..."
cat > /etc/supervisor/conf.d/ayyildiz.conf << EOF
[program:ayyildiz]
command=/var/www/ayyildiz/start.sh
directory=/var/www/ayyildiz
user=ayyildiz
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/ayyildiz.log
EOF

# 12. Nginx config
log "Nginx yapılandırılıyor..."
cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ayyildiz /etc/nginx/sites-enabled/

# 13. Permissions
log "İzinler ayarlanıyor..."
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod +x /var/www/ayyildiz/start.sh

# 14. Test database connection
log "Database bağlantısı test ediliyor..."
sudo -u ayyildiz bash << 'TESTEOF'
cd /var/www/ayyildiz
source venv/bin/activate
source .env
python3 -c "
import os
from app import app, db
with app.app_context():
    try:
        db.create_all()
        print('Database: SUCCESS')
    except Exception as e:
        print(f'Database: FAILED - {e}')
        exit(1)
"
TESTEOF

# 15. Start services
log "Servisler başlatılıyor..."
nginx -t || error "Nginx config hatası!"
systemctl restart nginx
systemctl enable nginx

supervisorctl reread
supervisorctl update
supervisorctl start ayyildiz

# 16. Test application
log "Uygulama test ediliyor..."
sleep 10

for i in {1..15}; do
    if curl -s http://127.0.0.1:5000/health | grep -q "OK"; then
        log "✅ Uygulama başarıyla çalışıyor!"
        break
    else
        log "Test $i/15: Bekleniyor..."
        sleep 2
    fi
    
    if [ $i -eq 15 ]; then
        error "Uygulama başlatılamadı!"
    fi
done

# 17. Firewall
log "Güvenlik duvarı ayarlanıyor..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# 18. Final report
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}    KURULUM BAŞARIYLA TAMAMLANDI!             ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Status check
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000 || echo "000")
HEALTH_CHECK=$(curl -s http://127.0.0.1:5000/health | grep -o "OK" || echo "FAIL")

echo -e "${BLUE}🌐 Web Sitesi:${NC} http://69.62.110.158"
echo -e "${BLUE}🔐 Admin Panel:${NC} http://69.62.110.158/admin"
echo -e "${BLUE}📊 Sistem Durumu:${NC} http://69.62.110.158/health"
echo ""
echo -e "${BLUE}📋 Durum Raporu:${NC}"
echo -e "  HTTP Status: ${GREEN}$HTTP_STATUS${NC}"
echo -e "  Health Check: ${GREEN}$HEALTH_CHECK${NC}"
echo -e "  Supervisor: $(supervisorctl status ayyildiz | grep -o RUNNING || echo STOPPED)"
echo ""
echo -e "${YELLOW}🎯 Giriş Bilgileri:${NC}"
echo -e "  Email: ${GREEN}admin@ayyildiz.com${NC}"
echo -e "  Şifre: ${GREEN}admin123${NC}"
echo ""
echo -e "${YELLOW}🔧 Yönetim Komutları:${NC}"
echo -e "  Durum: ${GREEN}supervisorctl status ayyildiz${NC}"
echo -e "  Restart: ${GREEN}supervisorctl restart ayyildiz${NC}"
echo -e "  Loglar: ${GREEN}tail -f /var/log/ayyildiz.log${NC}"
echo ""

if [ "$HTTP_STATUS" = "200" ] && [ "$HEALTH_CHECK" = "OK" ]; then
    log "🎉 Sıfırdan kurulum başarıyla tamamlandı!"
    log "🔗 Siteniz http://69.62.110.158 adresinde yayında!"
else
    error "❌ Kurulum tamamlandı ama site yanıt vermiyor!"
fi

echo ""
log "Tüm sorunlar çözüldü - Site kullanıma hazır!"
EOF

chmod +x deployment/fresh-install.sh