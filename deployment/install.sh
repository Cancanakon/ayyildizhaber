#!/bin/bash

# Ayyıldız Haber Ajansı - Ubuntu 22.04 Kurulum Scripti
# Bu script tüm sistem kurulumunu otomatik olarak yapar

set -e  # Hata durumunda script'i durdur

echo "=== Ayyıldız Haber Ajansı Kurulumu Başlıyor ==="
echo "Ubuntu 22.04 için optimized kurulum"

# Renklendirme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log fonksiyonu
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    error "Bu script root olarak çalıştırılmalıdır. 'sudo bash install.sh' kullanın"
fi

# 1. Sistem Güncellemesi
log "Sistem paketleri güncelleniyor..."
apt update && apt upgrade -y

# 2. Gerekli Paketlerin Kurulumu
log "Gerekli sistem paketleri kuruluyor..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    postgresql \
    postgresql-contrib \
    postgresql-server-dev-all \
    nginx \
    git \
    curl \
    wget \
    unzip \
    supervisor \
    fail2ban \
    ufw \
    certbot \
    python3-certbot-nginx \
    build-essential \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev

# 3. PostgreSQL Konfigürasyonu
log "PostgreSQL veritabanı konfigüre ediliyor..."

# PostgreSQL başlatma
systemctl start postgresql
systemctl enable postgresql

# Veritabanı ve kullanıcı oluşturma
sudo -u postgres psql << EOF
-- Eğer veritabanı zaten varsa sil (dikkatli!)
DROP DATABASE IF EXISTS ayyildizhaber;
DROP USER IF EXISTS ayyildizhaber_user;

-- Yeni veritabanı ve kullanıcı oluştur
CREATE USER ayyildizhaber_user WITH PASSWORD 'SecurePassword123!';
CREATE DATABASE ayyildizhaber OWNER ayyildizhaber_user;
GRANT ALL PRIVILEGES ON DATABASE ayyildizhaber TO ayyildizhaber_user;

-- Bağlantıyı test et
\q
EOF

log "PostgreSQL veritabanı başarıyla konfigüre edildi"

# 4. Uygulama Dizinlerinin Oluşturulması
log "Uygulama dizinleri oluşturuluyor..."

# Ana dizin
mkdir -p /var/www/ayyildizhaber
mkdir -p /var/log/ayyildizhaber
mkdir -p /var/run/ayyildizhaber

# Log dizini izinleri
chown www-data:www-data /var/log/ayyildizhaber
chown www-data:www-data /var/run/ayyildizhaber

# 5. Python Virtual Environment
log "Python sanal ortamı oluşturuluyor..."
cd /var/www/ayyildizhaber
python3 -m venv venv
source venv/bin/activate

# 6. Python Paketlerinin Kurulumu
log "Python bağımlılıkları kuruluyor..."
pip install --upgrade pip
pip install -r deployment/requirements.txt

# 7. Uygulama Dosyalarının Kopyalanması
log "Uygulama dosyaları kopyalanıyor..."
# Not: Bu adımda dosyalar manuel olarak kopyalanmalı veya git clone kullanılmalı

# 8. Environment Dosyası Oluşturma
log "Environment dosyası oluşturuluyor..."
cat > /var/www/ayyildizhaber/.env << EOF
# Database Configuration
DATABASE_URL=postgresql://ayyildizhaber_user:SecurePassword123!@localhost/ayyildizhaber

# Flask Configuration
FLASK_ENV=production
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
SESSION_SECRET=$(python3 -c 'import secrets; print(secrets.token_hex(32))')

# Security
WTF_CSRF_ENABLED=True
WTF_CSRF_TIME_LIMIT=3600

# File Upload
MAX_CONTENT_LENGTH=16777216
UPLOAD_FOLDER=/var/www/ayyildizhaber/static/uploads

# Logging
LOG_LEVEL=INFO
LOG_FILE=/var/log/ayyildizhaber/app.log

# Cache
CACHE_DIR=/var/www/ayyildizhaber/cache
EOF

# 9. Dosya İzinlerinin Ayarlanması
log "Dosya izinleri ayarlanıyor..."
chown -R www-data:www-data /var/www/ayyildizhaber
chmod -R 755 /var/www/ayyildizhaber
chmod 600 /var/www/ayyildizhaber/.env

# 10. Systemd Service Kurulumu
log "Systemd service konfigüre ediliyor..."
cp /var/www/ayyildizhaber/deployment/ayyildizhaber.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable ayyildizhaber.service

# 11. Nginx Konfigürasyonu
log "Nginx konfigüre ediliyor..."
cp /var/www/ayyildizhaber/deployment/nginx.conf /etc/nginx/sites-available/ayyildizhaber
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Nginx test
nginx -t || error "Nginx konfigürasyonu hatalı!"

# 12. Firewall Konfigürasyonu
log "Firewall konfigüre ediliyor..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 5000  # Geliştirme için, production'da kapatılmalı

# 13. Fail2Ban Konfigürasyonu
log "Fail2Ban konfigüre ediliyor..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log

[nginx-req-limit]
enabled = true
filter = nginx-req-limit
logpath = /var/log/nginx/error.log
maxretry = 10
EOF

systemctl enable fail2ban
systemctl start fail2ban

# 14. Veritabanı Migration
log "Veritabanı migration çalıştırılıyor..."
cd /var/www/ayyildizhaber
source venv/bin/activate
python3 -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Veritabanı tabloları oluşturuldu')
"

# 15. Static Files ve Cache Dizinleri
log "Static files ve cache dizinleri oluşturuluyor..."
mkdir -p /var/www/ayyildizhaber/static/uploads
mkdir -p /var/www/ayyildizhaber/cache
chown -R www-data:www-data /var/www/ayyildizhaber/static/uploads
chown -R www-data:www-data /var/www/ayyildizhaber/cache

# 16. Servisleri Başlatma
log "Servisler başlatılıyor..."
systemctl start ayyildizhaber.service
systemctl start nginx
systemctl reload nginx

# 17. Sistem Status Kontrolü
log "Sistem durumu kontrol ediliyor..."
if systemctl is-active --quiet ayyildizhaber.service; then
    log "✓ Ayyıldız Haber servisi çalışıyor"
else
    error "✗ Ayyıldız Haber servisi çalışmıyor"
fi

if systemctl is-active --quiet nginx; then
    log "✓ Nginx servisi çalışıyor"
else
    error "✗ Nginx servisi çalışmıyor"
fi

if systemctl is-active --quiet postgresql; then
    log "✓ PostgreSQL servisi çalışıyor"
else
    error "✗ PostgreSQL servisi çalışmıyor"
fi

# 18. SSL Sertifikası (Let's Encrypt) - Opsiyonel
warning "SSL sertifikası kurulumu için şu komutu çalıştırın:"
warning "certbot --nginx -d ayyildizajans.com -d www.ayyildizajans.com"

# 19. Cron Jobs (Backup ve Maintenance)
log "Cron jobs konfigüre ediliyor..."
(crontab -l 2>/dev/null; echo "0 2 * * * /var/www/ayyildizhaber/deployment/backup.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 0 * * 0 /var/www/ayyildizhaber/deployment/maintenance.sh") | crontab -

echo ""
echo "=== KURULUM TAMAMLANDI! ==="
echo ""
log "🎉 Ayyıldız Haber Ajansı başarıyla kuruldu!"
echo ""
echo "📋 ÖNEMLİ BİLGİLER:"
echo "• Site URL: http://$(curl -s ifconfig.me) (IP adresi)"
echo "• Admin paneli: http://$(curl -s ifconfig.me)/admin"
echo "• Varsayılan admin: admin@gmail.com / admin123"
echo "• Veritabanı: PostgreSQL (localhost:5432/ayyildizhaber)"
echo "• Log dosyaları: /var/log/ayyildizhaber/"
echo "• Uygulama dizini: /var/www/ayyildizhaber/"
echo ""
echo "🔧 SONRAKI ADIMLAR:"
echo "1. Domain adresinizi sunucunuza yönlendirin"
echo "2. SSL sertifikası kurun: certbot --nginx -d ayyildizajans.com"
echo "3. Admin şifresini değiştirin"
echo "4. Firewall'da 5000 portunu kapatın (production için)"
echo "5. Log monitoring kurabilirsiniz"
echo ""
echo "🔍 KONTROL KOMUTLARI:"
echo "• Servis durumu: systemctl status ayyildizhaber"
echo "• Log görüntüleme: tail -f /var/log/ayyildizhaber/error.log"
echo "• Nginx test: nginx -t"
echo "• Servis restart: systemctl restart ayyildizhaber"
echo ""
warning "Güvenlik için .env dosyasındaki şifreleri değiştirmeyi unutmayın!"