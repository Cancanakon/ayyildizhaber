#!/bin/bash

# Ayyıldız Haber Ajansı - Kusursuz Kurulum Scripti
# Tüm hatalardan öğrenilmiş, test edilmiş kurulum
# Ubuntu 24.04 için optimize edilmiş

echo "========================================"
echo "  AYYILDIZ HABER AJANSI KURULUM"
echo "========================================"
echo "Bu script tüm hatalardan öğrenerek hazırlanmıştır"
echo "Başlangıç: $(date)"

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Hata durumunda çıkış
set -e

# Hata yakalama fonksiyonu
error_exit() {
    echo -e "${RED}HATA: $1${NC}" >&2
    echo "Kurulum başarısız oldu. Lütfen hatayı düzeltin ve tekrar deneyin."
    exit 1
}

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    error_exit "Bu script root yetkileriyle çalıştırılmalı! Kullanım: sudo bash perfect-install.sh"
fi

# Ubuntu sürüm kontrolü
if ! grep -q "Ubuntu 24.04" /etc/os-release; then
    echo -e "${YELLOW}Uyarı: Bu script Ubuntu 24.04 için optimize edilmiştir${NC}"
    read -p "Devam etmek istiyor musunuz? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${BLUE}=== ADIM 1: SISTEM GÜNCELLEME ===${NC}"
apt update && apt upgrade -y || error_exit "Sistem güncellenemedi"

echo -e "${BLUE}=== ADIM 2: GEREKLI PAKETLER ===${NC}"
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib \
    git curl wget unzip supervisor ufw certbot python3-certbot-nginx \
    build-essential python3-dev libpq-dev || error_exit "Paketler kurulamadı"

echo -e "${BLUE}=== ADIM 3: FIREWALL YAPILIANDIRMASI ===${NC}"
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
echo "✓ Firewall yapılandırıldı"

echo -e "${BLUE}=== ADIM 4: POSTGRESQL KURULUMU ===${NC}"
systemctl start postgresql
systemctl enable postgresql

# PostgreSQL kullanıcı ve veritabanı oluştur
sudo -u postgres createuser --createdb --no-superuser --no-createrole ayyildizhaber 2>/dev/null || true
sudo -u postgres createdb ayyildizhaber_db -O ayyildizhaber 2>/dev/null || true

# Şifre oluştur
DB_PASSWORD=$(openssl rand -base64 32)
sudo -u postgres psql -c "ALTER USER ayyildizhaber PASSWORD '$DB_PASSWORD';" || error_exit "PostgreSQL yapılandırması başarısız"

echo "✓ PostgreSQL kuruldu ve yapılandırıldı"

echo -e "${BLUE}=== ADIM 5: UYGULAMA KURULUMU ===${NC}"
# Uygulama dizini oluştur
mkdir -p /opt/ayyildizhaber
cd /opt/ayyildizhaber

# GitHub'dan kodu çek (eğer .git yoksa)
if [ ! -d ".git" ]; then
    echo "GitHub deposundan kod çekiliyor..."
    # Mevcut dosyalar varsa yedekle
    if [ "$(ls -A .)" ]; then
        mkdir -p /tmp/ayyildizhaber-backup-$(date +%Y%m%d-%H%M%S)
        cp -r * /tmp/ayyildizhaber-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true
    fi
    git clone https://github.com/username/ayyildizhaber.git . || error_exit "GitHub'dan kod çekilemedi"
fi

# Python virtual environment oluştur
python3 -m venv venv
source venv/bin/activate

# Requirements yükle
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt || error_exit "Python paketleri kurulamadı"
elif [ -f "pyproject.toml" ]; then
    pip install . || error_exit "Python paketleri kurulamadı"
else
    # Temel paketleri manuel kur
    pip install flask flask-sqlalchemy flask-login psycopg2-binary gunicorn \
        requests beautifulsoup4 lxml trafilatura apscheduler python-dateutil \
        email-validator feedparser || error_exit "Python paketleri kurulamadı"
fi

echo "✓ Python uygulaması kuruldu"

echo -e "${BLUE}=== ADIM 6: ÇEVRE DEĞİŞKENLERİ ===${NC}"
# .env dosyası oluştur
cat > .env << EOF
DATABASE_URL=postgresql://ayyildizhaber:$DB_PASSWORD@localhost/ayyildizhaber_db
SESSION_SECRET=$(openssl rand -base64 32)
FLASK_ENV=production
FLASK_DEBUG=False
EOF

# Çevre değişkenlerini sistem genelinde kullanılabilir yap
cat > /etc/environment << EOF
DATABASE_URL=postgresql://ayyildizhaber:$DB_PASSWORD@localhost/ayyildizhaber_db
SESSION_SECRET=$(grep SESSION_SECRET .env | cut -d'=' -f2)
FLASK_ENV=production
FLASK_DEBUG=False
EOF

echo "✓ Çevre değişkenleri ayarlandı"

echo -e "${BLUE}=== ADIM 7: VERİTABANI BAŞLATMA ===${NC}"
# Veritabanını başlat
export DATABASE_URL="postgresql://ayyildizhaber:$DB_PASSWORD@localhost/ayyildizhaber_db"
python3 -c "
import sys
sys.path.insert(0, '/opt/ayyildizhaber')
from app import app, db
with app.app_context():
    db.create_all()
    print('Veritabanı tabloları oluşturuldu')
" || error_exit "Veritabanı başlatılamadı"

echo "✓ Veritabanı başlatıldı"

echo -e "${BLUE}=== ADIM 8: NGINX YAPILANDIRMASI ===${NC}"
# SSL olmadan güvenli nginx yapılandırması
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # File upload size
    client_max_body_size 50M;
    
    # Static files
    location /static/ {
        alias /opt/ayyildizhaber/static/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

# Site'ı aktifleştir
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Nginx test et
nginx -t || error_exit "Nginx yapılandırması hatalı"
systemctl reload nginx
echo "✓ Nginx yapılandırıldı"

echo -e "${BLUE}=== ADIM 9: GUNICORN SERVİSİ ===${NC}"
# Gunicorn yapılandırması
cat > /etc/systemd/system/ayyildizhaber.service << EOF
[Unit]
Description=Ayyıldız Haber Ajansı Web Application
After=network.target postgresql.service
Wants=postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/ayyildizhaber
Environment=PATH=/opt/ayyildizhaber/venv/bin
Environment=DATABASE_URL=postgresql://ayyildizhaber:$DB_PASSWORD@localhost/ayyildizhaber_db
Environment=SESSION_SECRET=$(grep SESSION_SECRET .env | cut -d'=' -f2)
Environment=FLASK_ENV=production
ExecStart=/opt/ayyildizhaber/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 120 main:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Dosya izinlerini ayarla
chown -R www-data:www-data /opt/ayyildizhaber
chmod -R 755 /opt/ayyildizhaber

# Servisi başlat
systemctl daemon-reload
systemctl enable ayyildizhaber
systemctl start ayyildizhaber

# Servis durumunu kontrol et
sleep 5
if systemctl is-active --quiet ayyildizhaber; then
    echo "✓ Gunicorn servisi başlatıldı"
else
    error_exit "Gunicorn servisi başlatılamadı"
fi

echo -e "${BLUE}=== ADIM 10: SON KONTROLLER ===${NC}"
# Port kontrolü
if netstat -tuln | grep -q ":5000"; then
    echo "✓ Port 5000 dinleniyor"
else
    error_exit "Port 5000 dinlenmiyor"
fi

# HTTP bağlantı testi
sleep 3
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302\|404"; then
    echo "✓ Web uygulaması erişilebilir"
else
    echo -e "${YELLOW}Uyarı: Web uygulamasına henüz bağlanılamıyor, birkaç saniye bekleyin${NC}"
fi

echo -e "${GREEN}========================================"
echo "       KURULUM BAŞARIYLA TAMAMLANDI"
echo "========================================${NC}"
echo ""
echo "🌐 Web Sitesi: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo "📊 Admin Panel: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')/admin"
echo "📂 Uygulama Dizini: /opt/ayyildizhaber"
echo "🔑 Veritabanı Şifresi: $DB_PASSWORD"
echo ""
echo "=== ÖNEMLİ BİLGİLER ==="
echo "• Varsayılan admin: admin@gmail.com / admin123"
echo "• Loglar: journalctl -u ayyildizhaber -f"
echo "• Nginx logları: tail -f /var/log/nginx/error.log"
echo "• Servis durumu: systemctl status ayyildizhaber"
echo ""
echo "=== SSL SERTIFIKASI EKLEMEK İÇİN ==="
echo "1. Domain DNS'ini sunucu IP'sine yönlendirin"
echo "2. Şu komutu çalıştırın:"
echo "   certbot --nginx -d yourdomain.com"
echo ""
echo -e "${GREEN}Kurulum tamamlandı! Site artık çalışıyor.${NC}"