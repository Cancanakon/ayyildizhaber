#!/bin/bash

# Nginx HTTP-only yapılandırması (SSL sertifikası olmadan)

echo "=== SSL Sertifikasız Nginx Yapılandırması ==="

# HTTP-only nginx yapılandırması
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
# Upstream tanımı
upstream ayyildizhaber_app {
    server 127.0.0.1:5000 fail_timeout=0;
}

# HTTP ana site
server {
    listen 80;
    server_name www.ayyildizajans.com ayyildizajans.com 69.62.110.158;
    
    # Güvenlik başlıkları (HTTP için)
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

# Nginx test ve yeniden başlat
nginx -t && systemctl reload nginx

echo "✅ Nginx HTTP-only yapılandırması tamamlandı"
echo "🌐 Site erişimi: http://www.ayyildizajans.com"
echo "🌐 IP erişimi: http://69.62.110.158"

# Servis durumları
echo ""
echo "Servis durumları:"
systemctl is-active --quiet ayyildizhaber && echo "✅ Ayyıldız Haber çalışıyor" || echo "❌ Uygulama sorunu"
systemctl is-active --quiet nginx && echo "✅ Nginx çalışıyor" || echo "❌ Nginx sorunu"

# Port kontrolü
echo ""
echo "Port durumları:"
ss -tlnp | grep :80 > /dev/null && echo "✅ Port 80 açık" || echo "❌ Port 80 kapalı"
ss -tlnp | grep :5000 > /dev/null && echo "✅ Port 5000 açık" || echo "❌ Port 5000 kapalı"

echo ""
echo "=== Site test komutları ==="
echo "curl -I http://localhost"
echo "curl -I http://69.62.110.158"
echo "curl -I http://www.ayyildizajans.com"