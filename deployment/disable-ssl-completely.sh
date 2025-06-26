#!/bin/bash

# SSL'i Tamamen Devre Dışı Bırak - Tek Komut Çözümü
echo "SSL tamamen devre dışı bırakılıyor..."

# 1. Tüm SSL konfigürasyonlarını kaldır
rm -f /etc/nginx/sites-enabled/ayyildizhaber*
rm -f /etc/nginx/sites-available/ayyildizhaber*

# 2. Basit HTTP-only konfigürasyon oluştur
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 50M;
    
    location /static/ {
        alias /opt/ayyildizhaber/static/;
    }
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

# 3. Konfigürasyonu etkinleştir
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/

# 4. Nginx'i yeniden başlat
nginx -t && systemctl reload nginx

echo "SSL devre dışı bırakıldı. Site HTTP üzerinden çalışıyor."