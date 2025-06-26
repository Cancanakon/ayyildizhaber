#!/bin/bash

# Ayyıldız Haber Ajansı - Tek Komut Kurulum
# Çalışan sistemden öğrenilmiş, HTTP-only kurulum

echo "========================================"
echo "  AYYILDIZ HABER AJANSI - TEK KOMUT KURULUM"
echo "========================================"
echo "Başlangıç: $(date)"
echo "Çalışan sistemden öğrenilmiş kurulum"

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Hata durumunda çıkış
set -e
error_exit() {
    echo -e "${RED}HATA: $1${NC}" >&2
    exit 1
}

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    error_exit "Root yetkileriyle çalıştırın! Kullanım: sudo bash single-command-install.sh"
fi

echo -e "${BLUE}=== ADIM 1: SISTEM GÜNCELLEME ===${NC}"
apt update && apt upgrade -y

echo -e "${BLUE}=== ADIM 2: GEREKLI PAKETLER ===${NC}"
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib \
    git curl wget unzip build-essential python3-dev libpq-dev ufw

echo -e "${BLUE}=== ADIM 3: FIREWALL ===${NC}"
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443

echo -e "${BLUE}=== ADIM 4: POSTGRESQL ===${NC}"
systemctl start postgresql
systemctl enable postgresql

# PostgreSQL kullanıcı ve veritabanı
sudo -u postgres createuser --createdb --no-superuser --no-createrole ayyildizhaber 2>/dev/null || true
sudo -u postgres createdb ayyildizhaber_db -O ayyildizhaber 2>/dev/null || true

# Sabit şifre - güvenlik için değiştirin
DB_PASSWORD="ayyildiz123"
sudo -u postgres psql -c "ALTER USER ayyildizhaber PASSWORD '$DB_PASSWORD';"

echo -e "${BLUE}=== ADIM 5: UYGULAMA KURULUMU ===${NC}"
mkdir -p /opt/ayyildizhaber
cd /opt/ayyildizhaber

# GitHub yerine mevcut dosyaları kopyala (eğer varsa)
if [ ! -f "main.py" ]; then
    echo "main.py bulunamadı. Lütfen proje dosyalarını /opt/ayyildizhaber/ dizinine kopyalayın"
    echo "Örnek: scp -r * root@VPS_IP:/opt/ayyildizhaber/"
    exit 1
fi

# Python virtual environment
python3 -m venv venv
source venv/bin/activate

echo -e "${BLUE}=== ADIM 6: PYTHON PAKETLERI ===${NC}"
pip install --upgrade pip setuptools wheel
pip install Flask==3.0.0 Flask-SQLAlchemy==3.1.1 Flask-Login==0.6.3
pip install psycopg2-binary==2.9.9 gunicorn==21.2.0 requests==2.31.0
pip install beautifulsoup4==4.12.2 "lxml>=4.9.0" "trafilatura>=1.6.0"
pip install APScheduler==3.10.4 python-dateutil==2.8.2 email-validator==2.1.0 feedparser==6.0.10

echo -e "${BLUE}=== ADIM 7: ÇEVRE DEĞİŞKENLERİ ===${NC}"
cat > .env << EOF
DATABASE_URL=postgresql://ayyildizhaber:$DB_PASSWORD@localhost/ayyildizhaber_db
SESSION_SECRET=$(openssl rand -base64 32)
FLASK_ENV=production
FLASK_DEBUG=False
EOF

echo -e "${BLUE}=== ADIM 8: VERİTABANI BAŞLATMA ===${NC}"
export DATABASE_URL="postgresql://ayyildizhaber:$DB_PASSWORD@localhost/ayyildizhaber_db"
export SESSION_SECRET=$(openssl rand -base64 32)
python3 -c "
import os
os.environ['DATABASE_URL'] = 'postgresql://ayyildizhaber:$DB_PASSWORD@localhost/ayyildizhaber_db'
os.environ['SESSION_SECRET'] = '$(openssl rand -base64 32)'
from app import app, db
with app.app_context():
    db.create_all()
    print('✓ Veritabanı tabloları oluşturuldu')
"

echo -e "${BLUE}=== ADIM 9: NGINX YAPILANDIRMASI ===${NC}"
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

ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t || error_exit "Nginx yapılandırma hatası"

echo -e "${BLUE}=== ADIM 10: SYSTEMD SERVİSİ ===${NC}"
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
Environment=SESSION_SECRET=$(openssl rand -base64 32)
Environment=FLASK_ENV=production
ExecStart=/opt/ayyildizhaber/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 120 main:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Dosya izinleri
chown -R www-data:www-data /opt/ayyildizhaber
chmod -R 755 /opt/ayyildizhaber

echo -e "${BLUE}=== ADIM 11: SERVİSLERİ BAŞLAT ===${NC}"
systemctl daemon-reload
systemctl enable ayyildizhaber
systemctl start ayyildizhaber
systemctl restart nginx
systemctl enable nginx

echo -e "${BLUE}=== ADIM 12: SON KONTROLLER ===${NC}"
sleep 5

# Servis durumları
if systemctl is-active --quiet ayyildizhaber; then
    echo "✓ Ayyıldız Haber servisi çalışıyor"
else
    error_exit "Ayyıldız Haber servisi başlatılamadı"
fi

if systemctl is-active --quiet nginx; then
    echo "✓ Nginx çalışıyor"
else
    error_exit "Nginx başlatılamadı"
fi

# Port kontrolleri
if netstat -tuln | grep -q ":5000"; then
    echo "✓ Port 5000 dinleniyor"
else
    error_exit "Port 5000 dinlenmiyor"
fi

if netstat -tuln | grep -q ":80"; then
    echo "✓ Port 80 dinleniyor"
else
    error_exit "Port 80 dinlenmiyor"
fi

# HTTP bağlantı testi
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "VPS_IP")
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302"; then
    echo "✓ Web uygulaması erişilebilir"
else
    echo -e "${YELLOW}Uyarı: Web uygulamasına henüz bağlanılamıyor${NC}"
fi

echo -e "${GREEN}========================================"
echo "       KURULUM BAŞARIYLA TAMAMLANDI"
echo "========================================${NC}"
echo ""
echo "🌐 Web Sitesi: http://$SERVER_IP"
echo "📊 Admin Panel: http://$SERVER_IP/admin"
echo "📂 Uygulama Dizini: /opt/ayyildizhaber"
echo "🔑 Veritabanı Şifresi: $DB_PASSWORD"
echo ""
echo "=== ÖNEMLİ BİLGİLER ==="
echo "• Varsayılan admin: admin@gmail.com / admin123"
echo "• Loglar: journalctl -u ayyildizhaber -f"
echo "• Nginx logları: tail -f /var/log/nginx/error.log"
echo "• Servis durumu: systemctl status ayyildizhaber"
echo "• Yeniden başlat: systemctl restart ayyildizhaber"
echo ""
echo "=== SSL EKLEMEK İÇİN ==="
echo "1. Domain DNS'ini $SERVER_IP'ye yönlendirin"
echo "2. Şu komutu çalıştırın: certbot --nginx -d yourdomain.com"
echo ""
echo -e "${GREEN}Site şu anda HTTP olarak çalışıyor ve hazır!${NC}"