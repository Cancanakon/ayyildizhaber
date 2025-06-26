#!/bin/bash

# Emergency SSL Fix for Nginx Configuration
# Bu script SSL hatalarını derhal düzeltir

echo "=== ACİL NİNX SSL DÜZELTMESİ ==="

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Hata durumunda devam et ama logla
set +e

echo -e "${YELLOW}1. Nginx durumunu kontrol ediliyor...${NC}"
systemctl status nginx --no-pager -l

echo -e "${YELLOW}2. Hatalı SSL konfigürasyonu kaldırılıyor...${NC}"
# SSL içeren konfigürasyonları geçici olarak devre dışı bırak
if [ -f "/etc/nginx/sites-enabled/ayyildizhaber" ]; then
    mv /etc/nginx/sites-enabled/ayyildizhaber /etc/nginx/sites-enabled/ayyildizhaber.ssl-broken
    echo "Hatalı konfigürasyon geçici olarak devre dışı bırakıldı"
fi

echo -e "${YELLOW}3. Temel HTTP konfigürasyonu uygulanıyor...${NC}"
cat > /etc/nginx/sites-available/ayyildizhaber-temp << 'EOF'
server {
    listen 80;
    server_name 69.62.110.158 ayyildizajans.com www.ayyildizajans.com;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # File upload boyutu
    client_max_body_size 50M;

    # Static dosyalar
    location /static/ {
        alias /opt/ayyildizhaber/static/;
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
    }

    # Gzip sıkıştırma
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

# Konfigürasyonu etkinleştir
ln -sf /etc/nginx/sites-available/ayyildizhaber-temp /etc/nginx/sites-enabled/ayyildizhaber-temp

echo -e "${YELLOW}4. Nginx konfigürasyonu test ediliyor...${NC}"
if nginx -t; then
    echo -e "${GREEN}✓ Nginx konfigürasyonu BAŞARILI!${NC}"
    
    echo -e "${YELLOW}5. Nginx yeniden yükleniyor...${NC}"
    systemctl reload nginx
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ BAŞARILI: Nginx çalışıyor!${NC}"
        echo -e "${GREEN}✓ Site erişilebilir: http://69.62.110.158${NC}"
        echo -e "${GREEN}✓ Domain erişilebilir: http://ayyildizajans.com${NC}"
        
        # Eski hatalı konfigürasyonu temizle
        rm -f /etc/nginx/sites-enabled/ayyildizhaber.ssl-broken
        
        echo ""
        echo -e "${YELLOW}=== SSL SERTIFIKASI EKLEMEK İÇİN ===${NC}"
        echo "1. SSL sertifikalarının mevcut olduğundan emin olun:"
        echo "   ls -la /etc/letsencrypt/live/ayyildizajans.com/"
        echo ""
        echo "2. Sertifikalar varsa SSL konfigürasyonunu etkinleştirin:"
        echo "   cp /opt/ayyildizhaber/deployment/nginx-ssl.conf /etc/nginx/sites-available/ayyildizhaber"
        echo "   ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/"
        echo "   nginx -t && systemctl reload nginx"
        
    else
        echo -e "${RED}✗ Nginx başlatılamadı${NC}"
        systemctl status nginx --no-pager -l
        exit 1
    fi
else
    echo -e "${RED}✗ Nginx konfigürasyonu hala hatalı!${NC}"
    nginx -t
    exit 1
fi

echo ""
echo -e "${GREEN}=== ACİL DÜZELTME TAMAMLANDI ===${NC}"
echo "Site şu anda HTTP üzerinden çalışıyor"
echo "SSL eklemek için yukarıdaki adımları takip edin"