#!/bin/bash

# Ayyıldız Haber Ajansı - VPS Otomatik Kurulum
# Sıfır VPS için tam otomatik GitHub kurulumu
# Ubuntu 22.04/24.04 destekli

set -e  # Hata durumunda dur

# Renkli çıktı
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

# Başlık
clear
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    Ayyıldız Haber Ajansı VPS Kurulumu         ${NC}"
echo -e "${BLUE}    Sıfır VPS - Tam Otomatik GitHub Kurulumu   ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
   error "Bu script root kullanıcısı ile çalıştırılmalıdır: sudo $0"
fi

# Kurulum bilgileri al
echo "Kurulum için gerekli bilgileri girin:"
echo ""
read -p "GitHub Repository URL'i: " GITHUB_URL
read -p "Domain adınız (veya 'ip' yazın): " DOMAIN
read -p "Sunucu IP adresiniz: " SERVER_IP
read -p "SSL için email adresiniz: " EMAIL
read -p "PostgreSQL veritabanı şifresi: " DB_PASSWORD

# Giriş doğrulama
if [[ -z "$GITHUB_URL" || -z "$SERVER_IP" || -z "$EMAIL" || -z "$DB_PASSWORD" ]]; then
    error "Tüm alanlar doldurulmalıdır!"
fi

echo ""
log "Kurulum başlatılıyor..."
log "Domain: $DOMAIN"
log "IP: $SERVER_IP"
log "GitHub: $GITHUB_URL"

# 1. Sistem Güncelleme
log "Sistem paketleri güncelleniyor..."
apt update -y
apt upgrade -y

# 2. Gerekli Paketleri Yükle
log "Gerekli paketler yükleniyor..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libpq-dev \
    nginx \
    postgresql \
    postgresql-contrib \
    supervisor \
    git \
    curl \
    wget \
    ufw \
    certbot \
    python3-certbot-nginx \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# 3. Uygulama Kullanıcısı Oluştur
log "Uygulama kullanıcısı oluşturuluyor..."
if ! id "ayyildiz" &>/dev/null; then
    useradd -m -s /bin/bash ayyildiz
    usermod -aG sudo ayyildiz
    echo "ayyildiz ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ayyildiz
    log "Kullanıcı 'ayyildiz' oluşturuldu"
else
    log "Kullanıcı 'ayyildiz' zaten mevcut"
fi

# 4. Uygulama Dizini Oluştur ve Temizle
log "Uygulama dizini hazırlanıyor..."
rm -rf /var/www/ayyildiz 2>/dev/null || true
mkdir -p /var/www

# 5. GitHub'dan Proje İndir
log "GitHub'dan proje indiriliyor..."
cd /var/www
git clone $GITHUB_URL ayyildiz
chown -R ayyildiz:ayyildiz /var/www/ayyildiz

# 6. Python Sanal Ortam Kur
log "Python sanal ortamı kuruluyor..."
cd /var/www/ayyildiz
sudo -u ayyildiz python3 -m venv venv
sudo -u ayyildiz ./venv/bin/pip install --upgrade pip setuptools wheel

# 7. Python Paketlerini Yükle
log "Python paketleri yükleniyor..."
sudo -u ayyildiz ./venv/bin/pip install flask==2.3.3
sudo -u ayyildiz ./venv/bin/pip install flask-sqlalchemy==3.0.5
sudo -u ayyildiz ./venv/bin/pip install flask-login==0.6.3
sudo -u ayyildiz ./venv/bin/pip install werkzeug==2.3.7
sudo -u ayyildiz ./venv/bin/pip install gunicorn==21.2.0
sudo -u ayyildiz ./venv/bin/pip install psycopg2-binary==2.9.7
sudo -u ayyildiz ./venv/bin/pip install apscheduler==3.10.4
sudo -u ayyildiz ./venv/bin/pip install beautifulsoup4
sudo -u ayyildiz ./venv/bin/pip install lxml
sudo -u ayyildiz ./venv/bin/pip install requests
sudo -u ayyildiz ./venv/bin/pip install trafilatura
sudo -u ayyildiz ./venv/bin/pip install email-validator
sudo -u ayyildiz ./venv/bin/pip install feedparser
sudo -u ayyildiz ./venv/bin/pip install python-dateutil

# 8. Flask Kurulumunu Doğrula
log "Flask kurulumu doğrulanıyor..."
sudo -u ayyildiz ./venv/bin/python3 -c "import flask; print(f'Flask {flask.__version__} yüklendi')" || error "Flask yüklenemedi!"

# 9. PostgreSQL Kur ve Yapılandır
log "PostgreSQL veritabanı yapılandırılıyor..."
systemctl start postgresql
systemctl enable postgresql

# Kullanıcı ve veritabanı oluştur
sudo -u postgres createuser ayyildiz 2>/dev/null || true
sudo -u postgres createdb ayyildiz_db -O ayyildiz 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER ayyildiz PASSWORD '$DB_PASSWORD';" 2>/dev/null || true

log "Veritabanı hazır: ayyildiz_db"

# 10. Environment Dosyası Oluştur
log "Ortam değişkenleri yapılandırılıyor..."
cat > /var/www/ayyildiz/.env << EOF
DATABASE_URL=postgresql://ayyildiz:$DB_PASSWORD@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF

chown ayyildiz:ayyildiz /var/www/ayyildiz/.env
chmod 600 /var/www/ayyildiz/.env

# 11. Başlangıç Script'i Oluştur
log "Uygulama başlangıç scripti oluşturuluyor..."
cat > /var/www/ayyildiz/start_app.sh << 'EOF'
#!/bin/bash
cd /var/www/ayyildiz

# Ortam değişkenlerini yükle
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Sanal ortamı aktifleştir
source venv/bin/activate

# Flask kontrolü
python3 -c "import flask" || {
    echo "Flask bulunamadı!"
    exit 1
}

# Gunicorn ile başlat
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
    main:app
EOF

chmod +x /var/www/ayyildiz/start_app.sh
chown ayyildiz:ayyildiz /var/www/ayyildiz/start_app.sh

# 12. Supervisor Yapılandır
log "Process manager (supervisor) yapılandırılıyor..."
cat > /etc/supervisor/conf.d/ayyildiz.conf << EOF
[program:ayyildiz]
command=/var/www/ayyildiz/start_app.sh
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

# 13. Nginx Yapılandır
log "Web sunucusu (nginx) yapılandırılıyor..."
if [[ "$DOMAIN" == "ip" ]]; then
    # IP tabanlı yapılandırma
cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $SERVER_IP _;
    
    client_max_body_size 50M;
    
    # Statik dosyalar
    location /static/ {
        alias /var/www/ayyildiz/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Ana uygulama
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
    # Domain tabanlı yapılandırma
cat > /etc/nginx/sites-available/ayyildiz << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    client_max_body_size 50M;
    
    # Statik dosyalar
    location /static/ {
        alias /var/www/ayyildiz/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Ana uygulama
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

# Nginx siteyi aktifleştir
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ayyildiz /etc/nginx/sites-enabled/

# Nginx yapılandırmasını test et
nginx -t || error "Nginx yapılandırma hatası!"

# 14. Güvenlik Duvarı Yapılandır
log "Güvenlik duvarı yapılandırılıyor..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# 15. Gerekli Dizinleri Oluştur
log "Uygulama dizinleri oluşturuluyor..."
mkdir -p /var/www/ayyildiz/{static,cache,uploads,static/uploads,static/uploads/images,static/uploads/videos}
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
chmod -R 755 /var/www/ayyildiz

# 16. Veritabanını Başlat
log "Veritabanı başlatılıyor..."
cd /var/www/ayyildiz
sudo -u ayyildiz bash << 'EOF'
source venv/bin/activate
source .env
python3 -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Veritabanı başarıyla oluşturuldu')
"
EOF

# 17. Servisleri Başlat
log "Servisler başlatılıyor..."
systemctl enable supervisor nginx postgresql
systemctl start supervisor
supervisorctl reread
supervisorctl update
supervisorctl start ayyildiz
systemctl restart nginx

# 18. Uygulama Durumunu Kontrol Et
log "Uygulama durumu kontrol ediliyor..."
sleep 10

# Supervisor durumu
supervisorctl status ayyildiz

# HTTP testi
for i in {1..10}; do
    if curl -s http://127.0.0.1:5000 > /dev/null; then
        log "✓ Uygulama başarıyla çalışıyor"
        break
    else
        log "Deneme $i: Uygulama başlatılıyor..."
        sleep 3
    fi
    
    if [ $i -eq 10 ]; then
        warning "Uygulama yanıt vermiyor - logları kontrol edin"
    fi
done

# 19. SSL Sertifikası (Domain için)
if [[ "$DOMAIN" != "ip" ]]; then
    log "SSL sertifikası kuruluyor..."
    certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect || {
        warning "SSL kurulumu başarısız - HTTP üzerinden çalışacak"
    }
fi

# 20. Yönetim Araçları Oluştur
log "Yönetim araçları oluşturuluyor..."

# Durum kontrol scripti
cat > /usr/local/bin/ayyildiz-durum << 'EOF'
#!/bin/bash
echo "=== Ayyıldız Haber Ajansı Durum Raporu ==="
echo ""
echo "Supervisor Durumu:"
supervisorctl status ayyildiz
echo ""
echo "Nginx Durumu:"
systemctl status nginx --no-pager -l | head -10
echo ""
echo "PostgreSQL Durumu:"
systemctl status postgresql --no-pager -l | head -5
echo ""
echo "HTTP Test:"
if curl -s http://127.0.0.1:5000 > /dev/null; then
    echo "✓ Uygulama yanıt veriyor"
else
    echo "✗ Uygulama yanıt vermiyor"
fi
echo ""
echo "Son Loglar:"
echo "--- Uygulama Logları ---"
tail -10 /var/log/ayyildiz.log
echo ""
echo "--- Hata Logları ---"
tail -5 /var/log/ayyildiz_error.log
EOF

chmod +x /usr/local/bin/ayyildiz-durum

# Yeniden başlatma scripti
cat > /usr/local/bin/ayyildiz-restart << 'EOF'
#!/bin/bash
echo "Ayyıldız Haber Ajansı yeniden başlatılıyor..."
supervisorctl restart ayyildiz
systemctl restart nginx
echo "Yeniden başlatma tamamlandı"
EOF

chmod +x /usr/local/bin/ayyildiz-restart

# Yedekleme scripti
cat > /usr/local/bin/ayyildiz-yedek << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/ayyildiz"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "Veritabanı yedekleniyor..."
sudo -u postgres pg_dump ayyildiz_db > $BACKUP_DIR/db_$DATE.sql

echo "Uygulama dosyaları yedekleniyor..."
tar -czf $BACKUP_DIR/app_$DATE.tar.gz -C /var/www ayyildiz

# 7 günden eski yedekleri sil
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Yedekleme tamamlandı: $BACKUP_DIR"
EOF

chmod +x /usr/local/bin/ayyildiz-yedek

# Otomatik yedekleme için cron ekle
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/ayyildiz-yedek") | crontab -

# 21. Son Durum Kontrolü ve Rapor
log "Son kontroller yapılıyor..."
sleep 5

# HTTP durumu
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000 || echo "000")

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}    KURULUM BAŞARIYLA TAMAMLANDI!             ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# URL bilgisi
if [[ "$DOMAIN" == "ip" ]]; then
    echo -e "${BLUE}Web Sitesi:${NC} http://$SERVER_IP"
else
    if certbot certificates --domain $DOMAIN &>/dev/null; then
        echo -e "${BLUE}Web Sitesi:${NC} https://$DOMAIN"
        echo -e "${BLUE}Alternatif:${NC} https://www.$DOMAIN"
    else
        echo -e "${BLUE}Web Sitesi:${NC} http://$DOMAIN"
        echo -e "${BLUE}Alternatif:${NC} http://www.$DOMAIN"
    fi
fi

echo -e "${BLUE}Admin Panel:${NC} /admin"
echo -e "${BLUE}Varsayılan Giriş:${NC} admin@gmail.com / admin123"
echo -e "${BLUE}HTTP Durum:${NC} $HTTP_STATUS"
echo ""

# Yönetim komutları
echo -e "${YELLOW}Yönetim Komutları:${NC}"
echo "• Durum kontrolü: ${GREEN}ayyildiz-durum${NC}"
echo "• Yeniden başlat: ${GREEN}ayyildiz-restart${NC}"
echo "• Yedek al: ${GREEN}ayyildiz-yedek${NC}"
echo "• Canlı loglar: ${GREEN}tail -f /var/log/ayyildiz.log${NC}"
echo "• Hata logları: ${GREEN}tail -f /var/log/ayyildiz_error.log${NC}"
echo ""

# Dosya konumları
echo -e "${YELLOW}Önemli Dosya Konumları:${NC}"
echo "• Uygulama: ${GREEN}/var/www/ayyildiz${NC}"
echo "• Nginx ayarları: ${GREEN}/etc/nginx/sites-available/ayyildiz${NC}"
echo "• Supervisor ayarları: ${GREEN}/etc/supervisor/conf.d/ayyildiz.conf${NC}"
echo "• Ortam değişkenleri: ${GREEN}/var/www/ayyildiz/.env${NC}"
echo "• Yedekler: ${GREEN}/var/backups/ayyildiz${NC}"
echo ""

# Güvenlik uyarısı
echo -e "${RED}ÖNEMLİ GÜVENLİK UYARISI:${NC}"
echo "• İlk girişten sonra admin şifresini mutlaka değiştirin!"
echo "• SSH portunu değiştirmeyi düşünün"
echo "• Düzenli yedekleme kontrolü yapın"
echo ""

# Test önerisi
echo -e "${BLUE}Test için:${NC}"
if [[ "$DOMAIN" == "ip" ]]; then
    echo "1. Tarayıcınızda http://$SERVER_IP adresini ziyaret edin"
else
    echo "1. Tarayıcınızda http://$DOMAIN adresini ziyaret edin"
fi
echo "2. /admin sayfasından giriş yapın"
echo "3. admin@gmail.com / admin123 ile test edin"
echo "4. Şifreyi hemen değiştirin!"
echo ""

log "Kurulum 100% tamamlandı! Siteniz kullanıma hazır."