#!/bin/bash

# Ayyıldız Haber Ajansı - Sıfırdan VPS Kurulum Scripti
# Ubuntu 24.04 için tam otomatik kurulum
# Usage: curl -O https://raw.githubusercontent.com/yourusername/ayyildizhaber/main/vps-install.sh && chmod +x vps-install.sh && ./vps-install.sh

set -e

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Ayyıldız Haber Ajansı VPS Kurulumu Başlatılıyor...${NC}"
echo -e "${YELLOW}Ubuntu 24.04 - Nginx + Gunicorn + PostgreSQL + SSL${NC}"

# Sistem güncellemesi
echo -e "${GREEN}📦 Sistem güncellemesi yapılıyor...${NC}"
apt update && apt upgrade -y

# Gerekli paketleri yükle
echo -e "${GREEN}🔧 Temel paketler yükleniyor...${NC}"
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
    supervisor \
    ufw \
    fail2ban \
    certbot \
    python3-certbot-nginx \
    htop \
    tree \
    nano

# PostgreSQL kurulumu ve yapılandırması
echo -e "${GREEN}🗄️ PostgreSQL yapılandırılıyor...${NC}"
systemctl start postgresql
systemctl enable postgresql

# PostgreSQL kullanıcısı ve veritabanı oluştur
sudo -u postgres psql << EOF
CREATE USER ayyildizhaber WITH PASSWORD 'ayyildiz2025!';
CREATE DATABASE ayyildizhaber OWNER ayyildizhaber;
GRANT ALL PRIVILEGES ON DATABASE ayyildizhaber TO ayyildizhaber;
ALTER USER ayyildizhaber CREATEDB;
\q
EOF

echo -e "${GREEN}✅ PostgreSQL yapılandırıldı${NC}"

# Proje klasörü oluştur
echo -e "${GREEN}📁 Proje klasörü hazırlanıyor...${NC}"
mkdir -p /var/www/ayyildizajans
cd /var/www/ayyildizajans

# Git repository clone (eğer varsa) veya boş klasör hazırla
echo -e "${GREEN}📥 Proje dosyaları hazırlanıyor...${NC}"
# Git clone yerine manuel upload bekleniyor

# Python virtual environment oluştur
echo -e "${GREEN}🐍 Python sanal ortamı oluşturuluyor...${NC}"
python3 -m venv venv
source venv/bin/activate

# Temel Python paketleri yükle
pip install --upgrade pip
pip install gunicorn

# Nginx yapılandırması
echo -e "${GREEN}🌐 Nginx yapılandırılıyor...${NC}"
cat > /etc/nginx/sites-available/ayyildizajans << 'EOF'
server {
    listen 80;
    server_name 69.62.110.158 ayyildizajans.com www.ayyildizajans.com;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Static files
    location /static {
        alias /var/www/ayyildizajans/static;
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
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # File upload size
    client_max_body_size 10M;
}
EOF

# Nginx site'ı aktif et
ln -sf /etc/nginx/sites-available/ayyildizajans /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Gunicorn systemd servisi
echo -e "${GREEN}⚙️ Gunicorn servisi oluşturuluyor...${NC}"
cat > /etc/systemd/system/gunicorn.service << 'EOF'
[Unit]
Description=Gunicorn instance to serve Ayyıldız Haber
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/ayyildizajans
Environment="PATH=/var/www/ayyildizajans/venv/bin"
Environment="DATABASE_URL=postgresql://ayyildizhaber:ayyildiz2025!@localhost/ayyildizhaber"
Environment="SESSION_SECRET=ayyildiz-super-secret-key-2025"
ExecStart=/var/www/ayyildizajans/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 3 --timeout 300 --keep-alive 2 --max-requests 1000 --max-requests-jitter 100 main:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Firewall yapılandırması
echo -e "${GREEN}🔥 Firewall yapılandırılıyor...${NC}"
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 80
ufw allow 443

# Fail2ban yapılandırması
echo -e "${GREEN}🛡️ Fail2ban yapılandırılıyor...${NC}"
systemctl enable fail2ban
systemctl start fail2ban

# Dosya izinleri
echo -e "${GREEN}🔐 Dosya izinleri ayarlanıyor...${NC}"
chown -R www-data:www-data /var/www/ayyildizajans
chmod -R 755 /var/www/ayyildizajans

# Servisleri başlat
echo -e "${GREEN}🚀 Servisler başlatılıyor...${NC}"
systemctl daemon-reload
systemctl enable nginx
systemctl enable gunicorn
systemctl start nginx

# Test nginx konfigürasyonu
nginx -t

echo -e "${GREEN}✅ VPS Kurulumu Tamamlandı!${NC}"

# Sistem durumu
echo -e "${BLUE}📊 Sistem Durumu:${NC}"
echo -e "${YELLOW}Nginx Status:${NC}"
systemctl status nginx --no-pager -l

echo -e "${YELLOW}PostgreSQL Status:${NC}"
systemctl status postgresql --no-pager -l

echo -e "${YELLOW}Sistem Bilgileri:${NC}"
echo "IP Adresi: $(hostname -I | awk '{print $1}')"
echo "Disk Kullanımı: $(df -h / | awk 'NR==2 {print $5 " kullanıldı"}')"
echo "RAM Kullanımı: $(free -h | awk 'NR==2{printf "%.1f/%.1fGB (%.2f%%)\n", $3/1024, $2/1024, $3*100/$2}')"

echo -e "${GREEN}🎉 Kurulum Başarıyla Tamamlandı!${NC}"
echo -e "${BLUE}📋 Sonraki Adımlar:${NC}"
echo "1. Proje dosyalarını /var/www/ayyildizajans/ klasörüne yükleyin"
echo "2. requirements.txt paketlerini yükleyin: source venv/bin/activate && pip install -r requirements.txt"
echo "3. Gunicorn servisini başlatın: systemctl start gunicorn"
echo "4. SSL sertifikası için: certbot --nginx -d ayyildizajans.com -d www.ayyildizajans.com"

echo -e "${YELLOW}🔗 Erişim Linkleri:${NC}"
echo "Site: http://$(hostname -I | awk '{print $1}')"
echo "Admin: http://$(hostname -I | awk '{print $1}')/admin"

echo -e "${GREEN}✨ Kurulum tamamlandı! Proje dosyalarını yüklemeye hazır.${NC}"