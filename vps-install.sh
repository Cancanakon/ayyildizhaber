#!/bin/bash

# Ayyıldız Haber Ajansı - Ubuntu 24.04 VPS Kurulum Scripti
# Domain: www.ayyildizajans.com
# IP: 69.62.110.158

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Hata kontrolü
error_exit() {
    echo -e "${RED}HATA: $1${NC}" >&2
    exit 1
}

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    error_exit "Root yetkileriyle çalıştırın! sudo bash vps-install.sh"
fi

echo -e "${GREEN}========================================"
echo "  AYYILDIZ HABER AJANSI VPS KURULUMU"
echo "  Ubuntu 24.04 - Nginx + Gunicorn"
echo "  Domain: www.ayyildizajans.com"
echo "  IP: 69.62.110.158"
echo "========================================${NC}"

# Sistem bilgileri
echo -e "${BLUE}Sistem bilgileri:${NC}"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "Disk: $(df -h / | awk 'NR==2{print $4}')"
echo ""

# 1. Sistem güncelleme
echo -e "${BLUE}=== ADIM 1: SISTEM GÜNCELLEME ===${NC}"
apt update -y
apt upgrade -y

# 2. Gerekli paketler
echo -e "${BLUE}=== ADIM 2: PAKET KURULUMU ===${NC}"
apt install -y \
    python3 python3-pip python3-venv python3-dev \
    nginx postgresql postgresql-contrib \
    git curl wget unzip build-essential \
    libpq-dev pkg-config \
    ufw fail2ban \
    htop tree nano vim \
    certbot python3-certbot-nginx

# 3. Güvenlik duvarı
echo -e "${BLUE}=== ADIM 3: GÜVENLİK DUVARI ===${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 4. PostgreSQL kurulumu
echo -e "${BLUE}=== ADIM 4: POSTGRESQL ===${NC}"
systemctl start postgresql
systemctl enable postgresql

# PostgreSQL yapılandırması
DB_NAME="ayyildizhaber_db"
DB_USER="ayyildizhaber"
DB_PASS="$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)"

sudo -u postgres createuser --createdb --no-superuser --no-createrole $DB_USER 2>/dev/null || true
sudo -u postgres createdb $DB_NAME -O $DB_USER 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER $DB_USER PASSWORD '$DB_PASS';"

echo -e "${GREEN}PostgreSQL yapılandırıldı${NC}"
echo "Veritabanı: $DB_NAME"
echo "Kullanıcı: $DB_USER"
echo "Şifre: $DB_PASS"

# 5. Uygulama kurulumu
echo -e "${BLUE}=== ADIM 5: UYGULAMA KURULUMU ===${NC}"

# Uygulama dizini
APP_DIR="/opt/ayyildizhaber"
mkdir -p $APP_DIR
cd $APP_DIR

# Dosyaları kontrol et ve kopyala
if [ -d "/tmp/ayyildizhaber" ]; then
    echo "Uygulama dosyaları kopyalanıyor..."
    cp -r /tmp/ayyildizhaber/* $APP_DIR/
elif [ ! -f "$APP_DIR/main.py" ]; then
    echo -e "${YELLOW}Uyarı: Uygulama dosyaları bulunamadı!${NC}"
    echo "Lütfen proje dosyalarını $APP_DIR dizinine kopyalayın:"
    echo "scp -r * root@69.62.110.158:$APP_DIR/"
    echo "Ardından scripti tekrar çalıştırın."
    exit 1
fi

# Python sanal ortamı
echo "Python sanal ortamı oluşturuluyor..."
python3 -m venv venv
source venv/bin/activate

# 6. Python paketleri
echo -e "${BLUE}=== ADIM 6: PYTHON PAKETLERİ ===${NC}"
pip install --upgrade pip setuptools wheel

# Ana paketler
pip install Flask==3.0.0 Flask-SQLAlchemy==3.1.1 Flask-Login==0.6.3
pip install psycopg2-binary==2.9.9 gunicorn==21.2.0 
pip install requests==2.31.0 beautifulsoup4==4.12.2
pip install "lxml>=4.9.0" "trafilatura>=1.6.0"
pip install APScheduler==3.10.4 python-dateutil==2.8.2
pip install email-validator==2.1.0 feedparser==6.0.10
pip install Werkzeug==3.0.1

# 7. Çevre değişkenleri
echo -e "${BLUE}=== ADIM 7: ÇEVRE DEĞİŞKENLERİ ===${NC}"
SESSION_SECRET=$(openssl rand -base64 32)

cat > $APP_DIR/.env << EOF
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost/$DB_NAME
SESSION_SECRET=$SESSION_SECRET
FLASK_ENV=production
FLASK_DEBUG=False
DOMAIN=www.ayyildizajans.com
SERVER_IP=69.62.110.158
EOF

# 8. Veritabanı başlatma
echo -e "${BLUE}=== ADIM 8: VERİTABANI BAŞLATMA ===${NC}"
export DATABASE_URL="postgresql://$DB_USER:$DB_PASS@localhost/$DB_NAME"
export SESSION_SECRET="$SESSION_SECRET"

python3 -c "
import os
import sys
sys.path.append('$APP_DIR')
os.environ['DATABASE_URL'] = '$DATABASE_URL'
os.environ['SESSION_SECRET'] = '$SESSION_SECRET'
try:
    from app import app, db
    with app.app_context():
        db.create_all()
        print('✓ Veritabanı tabloları oluşturuldu')
except Exception as e:
    print(f'Veritabanı hatası: {e}')
    sys.exit(1)
"

# 9. Nginx yapılandırması
echo -e "${BLUE}=== ADIM 9: NGINX YAPILANDIRMASI ===${NC}"

# Ana site yapılandırması
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
# Upstream tanımı
upstream ayyildizhaber_app {
    server 127.0.0.1:5000 fail_timeout=0;
}

# HTTP'den HTTPS'e yönlendirme
server {
    listen 80;
    server_name www.ayyildizajans.com ayyildizajans.com 69.62.110.158;
    
    # Let's Encrypt için
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # HTTPS'e yönlendir
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS ana site
server {
    listen 443 ssl http2;
    server_name www.ayyildizajans.com ayyildizajans.com 69.62.110.158;
    
    # SSL sertifikaları (Let's Encrypt ile güncellenecek)
    ssl_certificate /etc/letsencrypt/live/www.ayyildizajans.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/www.ayyildizajans.com/privkey.pem;
    
    # SSL güvenlik ayarları
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Güvenlik başlıkları
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Gzip sıkıştırma
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
    
    # Ana uygulama
    location / {
        proxy_pass http://ayyildizhaber_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_buffering off;
        
        # Timeout ayarları
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Statik dosyalar
    location /static/ {
        alias /opt/ayyildizhaber/static/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
        access_log off;
    }
    
    # Upload dosyaları
    location /uploads/ {
        alias /opt/ayyildizhaber/static/uploads/;
        expires 7d;
        access_log off;
    }
    
    # Robots.txt
    location /robots.txt {
        alias /opt/ayyildizhaber/static/robots.txt;
        access_log off;
    }
    
    # Favicon
    location /favicon.ico {
        alias /opt/ayyildizhaber/static/images/favicon.ico;
        access_log off;
    }
}
EOF

# Nginx ayarlarını etkinleştir
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Nginx test
nginx -t || error_exit "Nginx yapılandırma hatası"

# 10. Systemd servisi
echo -e "${BLUE}=== ADIM 10: SYSTEMD SERVİSİ ===${NC}"

cat > /etc/systemd/system/ayyildizhaber.service << EOF
[Unit]
Description=Ayyıldız Haber Ajansı Gunicorn
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
Environment=DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost/$DB_NAME
Environment=SESSION_SECRET=$SESSION_SECRET
Environment=FLASK_ENV=production
Environment=FLASK_DEBUG=False
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 --worker-class sync --timeout 120 --keep-alive 5 --max-requests 1000 --preload main:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

# Dosya izinleri
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

# Servisleri başlat
systemctl daemon-reload
systemctl enable ayyildizhaber
systemctl start ayyildizhaber

# 11. SSL sertifikası
echo -e "${BLUE}=== ADIM 11: SSL SERTİFİKASI ===${NC}"

# Geçici nginx yapılandırması (SSL öncesi)
cat > /etc/nginx/sites-available/ayyildizhaber-temp << 'EOF'
server {
    listen 80;
    server_name www.ayyildizajans.com ayyildizajans.com 69.62.110.158;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Geçici yapılandırmayı aktif et
ln -sf /etc/nginx/sites-available/ayyildizhaber-temp /etc/nginx/sites-enabled/ayyildizhaber
systemctl reload nginx

# SSL sertifikası al
echo "SSL sertifikası alınıyor..."
mkdir -p /var/www/html
certbot certonly --webroot --webroot-path=/var/www/html -d www.ayyildizajans.com -d ayyildizajans.com --non-interactive --agree-tos --email admin@ayyildizajans.com

# Ana yapılandırmaya geri dön
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/ayyildizhaber
systemctl reload nginx

# 12. Otomatik yenileme
echo -e "${BLUE}=== ADIM 12: OTOMATİK YENİLEME ===${NC}"

# Certbot otomatik yenileme
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -

# Sistem optimizasyonları
cat >> /etc/sysctl.conf << 'EOF'

# Ayyıldız Haber Ajansı optimizasyonları
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 5000
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

sysctl -p

# 13. İzleme ve log
echo -e "${BLUE}=== ADIM 13: İZLEME VE LOG ===${NC}"

# Logrotate yapılandırması
cat > /etc/logrotate.d/ayyildizhaber << 'EOF'
/var/log/nginx/access.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create
    postrotate
        systemctl reload nginx
    endscript
}
EOF

# 14. Durum kontrolü
echo -e "${BLUE}=== ADIM 14: DURUM KONTROLÜ ===${NC}"

# Servis durumları
echo "Servis durumları:"
systemctl is-active --quiet postgresql && echo "✓ PostgreSQL çalışıyor" || echo "✗ PostgreSQL sorunu"
systemctl is-active --quiet nginx && echo "✓ Nginx çalışıyor" || echo "✗ Nginx sorunu"  
systemctl is-active --quiet ayyildizhaber && echo "✓ Ayyıldız Haber çalışıyor" || echo "✗ Uygulama sorunu"

# Port kontrolü
echo ""
echo "Port durumları:"
ss -tlnp | grep :80 > /dev/null && echo "✓ Port 80 açık" || echo "✗ Port 80 kapalı"
ss -tlnp | grep :443 > /dev/null && echo "✓ Port 443 açık" || echo "✗ Port 443 kapalı"
ss -tlnp | grep :5000 > /dev/null && echo "✓ Port 5000 açık" || echo "✗ Port 5000 kapalı"

# DNS kontrolü
echo ""
echo "DNS kontrolü:"
nslookup www.ayyildizajans.com | grep "69.62.110.158" > /dev/null && echo "✓ DNS doğru" || echo "⚠ DNS kontrol edin"

echo ""
echo -e "${GREEN}========================================"
echo "  KURULUM TAMAMLANDI!"
echo "========================================${NC}"
echo ""
echo "🌐 Web sitesi: https://www.ayyildizajans.com"
echo "🌐 IP erişimi: https://69.62.110.158"  
echo "🔧 Admin paneli: https://www.ayyildizajans.com/admin"
echo "👤 Varsayılan admin: admin@gmail.com / admin123"
echo ""
echo "📊 Durum kontrolü:"
echo "   systemctl status ayyildizhaber"
echo "   systemctl status nginx"
echo "   journalctl -u ayyildizhaber -f"
echo ""
echo "🔄 Yeniden başlatma:"
echo "   systemctl restart ayyildizhaber"
echo ""
echo "📁 Uygulama dizini: $APP_DIR"
echo "📄 Nginx yapılandırması: /etc/nginx/sites-available/ayyildizhaber"
echo ""
echo -e "${YELLOW}Önemli: DNS ayarlarınızın www.ayyildizajans.com -> 69.62.110.158"
echo -e "A kaydını içerdiğinden emin olun!${NC}"

# Kurulum özeti dosyası
cat > $APP_DIR/kurulum-bilgileri.txt << EOF
Ayyıldız Haber Ajansı - Kurulum Bilgileri
========================================

Kurulum Tarihi: $(date)
Server IP: 69.62.110.158
Domain: www.ayyildizajans.com

Veritabanı:
- Adı: $DB_NAME
- Kullanıcı: $DB_USER  
- Şifre: $DB_PASS

Çevre Değişkenleri:
- DATABASE_URL: postgresql://$DB_USER:$DB_PASS@localhost/$DB_NAME
- SESSION_SECRET: $SESSION_SECRET

Önemli Komutlar:
- Uygulama durumu: systemctl status ayyildizhaber
- Nginx durumu: systemctl status nginx
- Logları görüntüle: journalctl -u ayyildizhaber -f
- Yeniden başlat: systemctl restart ayyildizhaber

SSL Sertifikası:
- Let's Encrypt ile otomatik yenileme aktif
- Crontab: 0 12 * * * /usr/bin/certbot renew --quiet

Güvenlik:
- UFW firewall aktif (80, 443, 22 portları açık)
- Fail2ban kurulu
- SSL/TLS güvenlik başlıkları aktif
EOF

echo -e "${GREEN}Kurulum bilgileri $APP_DIR/kurulum-bilgileri.txt dosyasına kaydedildi.${NC}"