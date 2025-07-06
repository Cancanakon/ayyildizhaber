#!/bin/bash

# Ayyıldız Haber Ajansı - GitHub'dan Sıfırdan VPS Kurulum
# Ubuntu 24.04 için tam otomatik kurulum
# Yeni API sistemi ile güncellenmiş versiyon

set -e

# GitHub Repository Settings
GITHUB_USER="yourusername"
GITHUB_REPO="ayyildizhaber"
GITHUB_TOKEN=""  # Bu kısmı doldurmanız gerekiyor
GITHUB_BRANCH="main"

PROJECT_DIR="/var/www/ayyildizhaber"
DB_USER="ayyildizhaber"
DB_PASS="ayyildizhaber2025!"
DB_NAME="ayyildizhaber"

# API Key for mobile access
API_KEY="ayyildizhaber_mobile_2025"

# GitHub token kontrolü
if [ -z "$GITHUB_TOKEN" ]; then
    echo "HATA: GitHub token gerekli!"
    echo "Lütfen scriptin başındaki GITHUB_TOKEN değişkenini doldurun."
    echo "GitHub -> Settings -> Developer settings -> Personal access tokens"
    echo "Token permissions: repo (full access)"
    exit 1
fi

echo "=== Ayyıldız Haber Ajansı GitHub'dan Sıfırdan Kurulum ==="
echo "📱 Yeni özellik: Mobil API sistemi dahil"
echo "🔑 API Key: $API_KEY"
echo "Bu işlem 12-18 dakika sürecek..."

# Sistem güncellemesi
echo "1/10 - Sistem güncelleniyor..."
apt update && apt upgrade -y

# Gerekli paketler
echo "2/10 - Gerekli paketler yükleniyor..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    postgresql \
    postgresql-contrib \
    nginx \
    git \
    curl \
    wget \
    unzip \
    supervisor

# PostgreSQL yapılandırması
echo "3/10 - PostgreSQL yapılandırılıyor..."
systemctl start postgresql
systemctl enable postgresql

# Veritabanı ve kullanıcı oluştur
sudo -u postgres psql << EOF
-- Mevcut veritabanını sil
DROP DATABASE IF EXISTS ${DB_NAME};
DROP ROLE IF EXISTS ${DB_USER};

-- Yeni veritabanı oluştur
CREATE DATABASE ${DB_NAME};
CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
ALTER ROLE ${DB_USER} CREATEDB;
ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};
\q
EOF

# Proje dizinini temizle
echo "4/10 - Proje dizini hazırlanıyor..."
rm -rf ${PROJECT_DIR}
mkdir -p ${PROJECT_DIR}
cd ${PROJECT_DIR}

# GitHub'dan projeyi klonla (token ile)
echo "5/10 - GitHub'dan proje indiriliyor..."
REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
git clone -b ${GITHUB_BRANCH} ${REPO_URL} .

# Python ortamı oluştur
echo "6/10 - Python ortamı oluşturuluyor..."
python3 -m venv venv
source venv/bin/activate

# Pip güncelle
pip install --upgrade pip

# Paketleri yükle
echo "7/10 - Python paketleri yükleniyor..."
cat > requirements.txt << 'EOF'
flask==3.0.0
flask-sqlalchemy==3.1.1
flask-login==0.6.3
werkzeug==3.0.1
gunicorn==21.2.0
psycopg2-binary==2.9.9
apscheduler==3.10.4
beautifulsoup4==4.12.2
requests==2.31.0
trafilatura==1.8.0
lxml==4.9.4
feedparser==6.0.11
python-dateutil==2.8.2
email-validator==2.1.0
EOF

pip install -r requirements.txt

# Çevre değişkenleri
echo "8/10 - Çevre değişkenleri ayarlanıyor..."
cat > .env << EOF
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost/${DB_NAME}
SESSION_SECRET=ayyildizhaber-github-secret-key-$(date +%s)
FLASK_ENV=production
PYTHONPATH=${PROJECT_DIR}
EOF

# Veritabanı tablolarını oluştur
echo "9/10 - Veritabanı tabloları oluşturuluyor..."
export DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost/${DB_NAME}
export SESSION_SECRET=ayyildizhaber-github-secret-key-$(date +%s)
export FLASK_ENV=production
export PYTHONPATH=${PROJECT_DIR}

python3 << 'PYEOF'
import sys
import os
sys.path.insert(0, '/var/www/ayyildizhaber')

try:
    from app import app, db
    with app.app_context():
        db.create_all()
        print("Veritabanı tabloları başarıyla oluşturuldu")
except Exception as e:
    print(f"Veritabanı hatası: {e}")
    exit(1)
PYEOF

# Nginx yapılandırması
echo "10/10 - Web sunucusu yapılandırılıyor..."
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
server {
    listen 80;
    server_name 69.62.110.158 www.ayyildizajans.com ayyildizajans.com;
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        proxy_buffering off;
    }
    
    location /static/ {
        alias /var/www/ayyildizhaber/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /favicon.ico {
        alias /var/www/ayyildizhaber/static/favicon.ico;
    }
    
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

# Nginx site aktif et
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Supervisor yapılandırması
cat > /etc/supervisor/conf.d/ayyildizhaber.conf << EOF
[program:ayyildizhaber]
command=${PROJECT_DIR}/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 3 --timeout 300 --max-requests 1000 --preload main:app
directory=${PROJECT_DIR}
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/ayyildizhaber.log
environment=DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@localhost/${DB_NAME}",SESSION_SECRET="ayyildizhaber-github-secret-key-$(date +%s)",FLASK_ENV="production",PYTHONPATH="${PROJECT_DIR}"
EOF

# Dosya izinleri
chown -R www-data:www-data ${PROJECT_DIR}
chmod -R 755 ${PROJECT_DIR}
mkdir -p ${PROJECT_DIR}/static/uploads
chown -R www-data:www-data ${PROJECT_DIR}/static/uploads
chmod -R 775 ${PROJECT_DIR}/static/uploads

# Log dosyası
touch /var/log/ayyildizhaber.log
chown www-data:www-data /var/log/ayyildizhaber.log

# Servisleri başlat
systemctl reload supervisor
supervisorctl reread
supervisorctl update
supervisorctl start ayyildizhaber

nginx -t
systemctl restart nginx
systemctl enable nginx

# Güvenlik duvarı
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

echo ""
echo "=== KURULUM TAMAMLANDI ==="
echo ""
echo "🌐 Website URL'leri:"
echo "   http://69.62.110.158"
echo "   http://www.ayyildizajans.com"
echo ""
echo "🔧 Admin Panel:"
echo "   http://69.62.110.158/admin"
echo "   Email: admin@gmail.com"
echo "   Şifre: admin123"
echo ""
echo "📱 Mobile API Base URL:"
echo "   http://69.62.110.158/api/v1"
echo "   http://www.ayyildizajans.com/api/v1"
echo ""
echo "🔑 API Authentication:"
echo "   Header: X-API-Key: ${API_KEY}"
echo ""
echo "📋 API Test Komutları:"
echo "   # API Info"
echo "   curl -H \"X-API-Key: ${API_KEY}\" \"http://69.62.110.158/api/v1/info\""
echo ""
echo "   # Haberler"
echo "   curl -H \"X-API-Key: ${API_KEY}\" \"http://69.62.110.158/api/v1/news?per_page=5\""
echo ""
echo "   # Kategoriler"
echo "   curl -H \"X-API-Key: ${API_KEY}\" \"http://69.62.110.158/api/v1/categories\""
echo ""
echo "   # Homepage Data"
echo "   curl -H \"X-API-Key: ${API_KEY}\" \"http://69.62.110.158/api/v1/homepage\""
echo ""
echo "📊 Sistem Kontrol:"
echo "   supervisorctl status ayyildizhaber"
echo "   tail -f /var/log/ayyildizhaber.log"
echo "   systemctl status nginx"
echo ""
echo "🔄 Güncelleme için:"
echo "   cd ${PROJECT_DIR}"
echo "   git pull https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
echo "   supervisorctl restart ayyildizhaber"
echo ""
echo "📚 API Dokümantasyonu:"
echo "   ${PROJECT_DIR}/API_DOCUMENTATION.md"
echo ""
echo "✅ Kurulum başarıyla tamamlandı!"
echo "🚀 Artık mobil uygulama geliştirmeye başlayabilirsiniz!"