#!/bin/bash

# Ayyıldız Haber Ajansı - Sıfırdan VPS Kurulum
# Ubuntu 24.04 için optimize edilmiş kurulum scripti
# Kullanım: ./install.sh

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Ayyıldız Haber Ajansı VPS Kurulumu ===${NC}"
echo -e "${YELLOW}Domain: www.ayyildizajans.com${NC}"
echo -e "${YELLOW}IP: 69.62.110.158${NC}"

# Sistem güncelleme
echo -e "${GREEN}[1/8] Sistem güncelleniyor...${NC}"
apt update -y
apt upgrade -y

# Temel paketler
echo -e "${GREEN}[2/8] Temel paketler yükleniyor...${NC}"
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    nginx \
    postgresql \
    postgresql-contrib \
    libpq-dev \
    git \
    curl \
    wget \
    unzip \
    ufw \
    htop \
    tree

# PostgreSQL yapılandırma
echo -e "${GREEN}[3/8] PostgreSQL yapılandırılıyor...${NC}"
systemctl start postgresql
systemctl enable postgresql

# Database ve kullanıcı oluşturma
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ayyildizhaber;"
sudo -u postgres psql -c "DROP USER IF EXISTS ayyildizhaber;"
sudo -u postgres psql -c "CREATE USER ayyildizhaber WITH PASSWORD 'ayyildiz2025!';"
sudo -u postgres psql -c "CREATE DATABASE ayyildizhaber OWNER ayyildizhaber;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ayyildizhaber TO ayyildizhaber;"
sudo -u postgres psql -c "ALTER USER ayyildizhaber CREATEDB;"

echo -e "${GREEN}Database kuruldu: ayyildizhaber${NC}"

# Proje klasörü hazırlama
echo -e "${GREEN}[4/8] Proje klasörü hazırlanıyor...${NC}"
rm -rf /var/www/ayyildizajans
mkdir -p /var/www/ayyildizajans
cd /var/www/ayyildizajans

# Python sanal ortam
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install gunicorn

# Nginx yapılandırma
echo -e "${GREEN}[5/8] Nginx yapılandırılıyor...${NC}"
cat > /etc/nginx/sites-available/ayyildizajans << 'EOF'
server {
    listen 80;
    server_name 69.62.110.158 www.ayyildizajans.com ayyildizajans.com;

    # Gzip sıkıştırma
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/json;

    # Static dosyalar
    location /static {
        alias /var/www/ayyildizajans/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Ana uygulama
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

    # Dosya yükleme boyutu
    client_max_body_size 10M;
    
    # Güvenlik başlıkları
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

# Site aktifleştirme
ln -sf /etc/nginx/sites-available/ayyildizajans /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Gunicorn systemd servisi
echo -e "${GREEN}[6/8] Gunicorn servisi yapılandırılıyor...${NC}"
cat > /etc/systemd/system/gunicorn.service << 'EOF'
[Unit]
Description=Gunicorn instance to serve Ayyıldız Haber
After=network.target postgresql.service
Wants=postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/ayyildizajans
Environment="PATH=/var/www/ayyildizajans/venv/bin"
Environment="DATABASE_URL=postgresql://ayyildizhaber:ayyildiz2025!@localhost/ayyildizhaber"
Environment="SESSION_SECRET=ayyildiz-haber-2025-secret-key"
ExecStart=/var/www/ayyildizajans/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 2 --timeout 120 main:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Firewall yapılandırma
echo -e "${GREEN}[7/8] Güvenlik yapılandırılıyor...${NC}"
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# Dosya izinleri
chown -R www-data:www-data /var/www/ayyildizajans
chmod -R 755 /var/www/ayyildizajans

# Servisleri başlatma
echo -e "${GREEN}[8/8] Servisler başlatılıyor...${NC}"
systemctl daemon-reload
systemctl enable nginx
systemctl enable gunicorn
systemctl start nginx

# Nginx test
nginx -t
if [ $? -ne 0 ]; then
    echo -e "${RED}Nginx konfigürasyon hatası!${NC}"
    exit 1
fi

echo -e "${GREEN}=== KURULUM TAMAMLANDI ===${NC}"
echo ""
echo -e "${BLUE}Sistem Durumu:${NC}"
echo "- PostgreSQL: $(systemctl is-active postgresql)"
echo "- Nginx: $(systemctl is-active nginx)"
echo "- IP Adresi: $(hostname -I | awk '{print $1}')"
echo ""
echo -e "${YELLOW}Sonraki Adımlar:${NC}"
echo "1. Proje dosyalarını yükleyin"
echo "2. Gunicorn servisini başlatın"
echo ""
echo -e "${GREEN}VPS hazır - Proje dosyalarını bekliyor!${NC}"