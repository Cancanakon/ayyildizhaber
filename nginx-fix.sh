#!/bin/bash

# Nginx Konfigürasyon Düzeltme Scripti
# VPS'te çalıştırın: ./nginx-fix.sh

echo "🔧 Nginx konfigürasyonu düzeltiliyor..."

# Doğru Nginx konfigürasyonunu oluştur
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
    gzip_proxied any;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Static files
    location /static {
        alias /var/www/ayyildizajans/static;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Upload files
    location /uploads {
        alias /var/www/ayyildizajans/static/uploads;
        expires 7d;
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
        proxy_redirect off;
    }

    # File upload size
    client_max_body_size 10M;
    
    # Logging
    access_log /var/log/nginx/ayyildizajans_access.log;
    error_log /var/log/nginx/ayyildizajans_error.log;
}
EOF

# Site'ı aktif et
ln -sf /etc/nginx/sites-available/ayyildizajans /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Nginx test et
echo "🔍 Nginx konfigürasyonu test ediliyor..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx konfigürasyonu doğru"
    systemctl restart nginx
    echo "🚀 Nginx yeniden başlatıldı"
    systemctl status nginx --no-pager -l
else
    echo "❌ Nginx konfigürasyon hatası"
    exit 1
fi