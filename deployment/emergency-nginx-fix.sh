#!/bin/bash

# Emergency Nginx Configuration Fix
# Bu script sunucudaki problemli Nginx konfigürasyonunu acil olarak düzeltir

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    error "Bu script root olarak çalıştırılmalıdır"
fi

log "Emergency Nginx configuration fix başlatılıyor..."

# 1. Problemli config dosyalarını kaldır
log "Problemli Nginx konfigürasyonları kaldırılıyor..."
rm -f /etc/nginx/sites-enabled/ayyildizhaber
rm -f /etc/nginx/sites-available/ayyildizhaber*
rm -f /etc/nginx/sites-enabled/default

# 2. Doğru HTTP konfigürasyonunu oluştur
log "Temel HTTP konfigürasyonu oluşturuluyor..."
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
server {
    listen 80;
    server_name 69.62.110.158 ayyildizajans.com www.ayyildizajans.com;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # File upload boyutu
    client_max_body_size 50M;

    # Static dosyalar
    location /static/ {
        alias /var/www/ayyildizhaber/static/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
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
        proxy_buffer_size 64k;
        proxy_buffers 32 64k;
        proxy_busy_buffers_size 128k;
    }

    # Gzip sıkıştırma
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
}
EOF

# 3. Site'ı aktifleştir
log "Site aktifleştiriliyor..."
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/

# 4. Nginx test
log "Nginx konfigürasyonu test ediliyor..."
if nginx -t; then
    log "✓ Nginx konfigürasyonu başarılı!"
    
    # 5. Nginx reload
    log "Nginx reload ediliyor..."
    systemctl reload nginx
    
    # 6. Status kontrol
    log "Nginx status kontrol ediliyor..."
    systemctl status nginx --no-pager
    
    log "✓ Emergency Nginx fix tamamlandı!"
    log "Site şu adreslerden erişilebilir olmalı:"
    log "  - http://69.62.110.158"
    log "  - http://ayyildizajans.com"
    log "  - http://www.ayyildizajans.com"
    
else
    error "Nginx konfigürasyonu hala hatalı!"
fi

# 7. Ayyıldız Haber servis durumunu kontrol et
log "Ayyıldız Haber servis durumu kontrol ediliyor..."
if systemctl is-active --quiet ayyildizhaber.service; then
    log "✓ Ayyıldız Haber servisi çalışıyor"
else
    log "⚠ Ayyıldız Haber servisi çalışmıyor, başlatılıyor..."
    systemctl start ayyildizhaber.service
    sleep 3
    if systemctl is-active --quiet ayyildizhaber.service; then
        log "✓ Ayyıldız Haber servisi başlatıldı"
    else
        log "✗ Ayyıldız Haber servisi başlatılamadı"
        systemctl status ayyildizhaber.service --no-pager
    fi
fi

log "Emergency fix completed!"