#!/bin/bash

# Ayyıldız Haber Ajansı - Tam VPS Kurulum Scripti
# Ubuntu 24.04 için test edilmiş

set -e

echo "=== Ayyıldız Haber Ajansı VPS Kurulumu Başlıyor ==="
echo "Bu işlem yaklaşık 5-10 dakika sürecek..."

# Sistem güncellemesi
echo "Sistem güncelleniyor..."
apt update && apt upgrade -y

# Gerekli paketleri yükle
echo "Gerekli paketler yükleniyor..."
apt install -y python3 python3-pip python3-venv postgresql postgresql-contrib nginx git curl wget unzip

# PostgreSQL yapılandırması
echo "PostgreSQL yapılandırılıyor..."
systemctl start postgresql
systemctl enable postgresql

# Veritabanı ve kullanıcı oluştur
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS ayyildizhaber;
DROP ROLE IF EXISTS ayyildizhaber;
CREATE DATABASE ayyildizhaber;
CREATE ROLE ayyildizhaber WITH LOGIN PASSWORD 'ayyildizhaber123';
GRANT ALL PRIVILEGES ON DATABASE ayyildizhaber TO ayyildizhaber;
ALTER ROLE ayyildizhaber CREATEDB;
\q
EOF

# Uygulama dizini oluştur
echo "Uygulama dizini oluşturuluyor..."
mkdir -p /var/www/ayyildizhaber
cd /var/www/ayyildizhaber

# Python virtual environment oluştur
echo "Python ortamı hazırlanıyor..."
python3 -m venv venv
source venv/bin/activate

# Pip güncellemesi
pip install --upgrade pip

# Nginx yapılandırması
echo "Nginx yapılandırılıyor..."
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
server {
    listen 80;
    server_name 69.62.110.158 www.ayyildizajans.com ayyildizajans.com;
    
    client_max_body_size 20M;
    
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
    
    location /static/ {
        alias /var/www/ayyildizhaber/static/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;
}
EOF

# Nginx site aktif et
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Nginx test et ve yeniden başlat
nginx -t
systemctl restart nginx
systemctl enable nginx

# Systemd service dosyası oluştur
echo "Systemd servisi oluşturuluyor..."
cat > /etc/systemd/system/ayyildizhaber.service << 'EOF'
[Unit]
Description=Ayyıldız Haber Ajansı Gunicorn instance
After=network.target postgresql.service
Requires=postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/ayyildizhaber
Environment="PATH=/var/www/ayyildizhaber/venv/bin"
ExecStart=/var/www/ayyildizhaber/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 120 --access-logfile /var/log/ayyildizhaber/access.log --error-logfile /var/log/ayyildizhaber/error.log main:app
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Log dizini oluştur
mkdir -p /var/log/ayyildizhaber
chown www-data:www-data /var/log/ayyildizhaber

# Uygulama dosyalarının sahipliğini ayarla
chown -R www-data:www-data /var/www/ayyildizhaber

# Güvenlik duvarı ayarları
echo "Güvenlik duvarı yapılandırılıyor..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

echo "=== VPS Kurulumu Tamamlandı ==="
echo "Şimdi proje dosyalarını yükleyebilirsiniz."
echo ""
echo "Sonraki adım: Bilgisayarınızdan deploy-to-vps.sh scriptini çalıştırın"