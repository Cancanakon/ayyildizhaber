#!/bin/bash

# Ayyıldız Haber Ajansı - Otomatik SSL Sertifikası Kurulum Script
# Bu script Let's Encrypt SSL sertifikasını otomatik olarak kurar

set -e

# Konfigürasyon
DOMAIN="ayyildizajans.com"
WWW_DOMAIN="www.ayyildizajans.com"
EMAIL="ayyildizcasttr@gmail.com"
WEBROOT="/var/www/ayyildizhaber"

# Renklendirme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    error "Bu script root olarak çalıştırılmalıdır. 'sudo bash ssl-setup.sh' kullanın"
fi

echo "=== SSL Sertifikası Otomatik Kurulum ==="
echo "Domain: $DOMAIN, $WWW_DOMAIN"
echo "Email: $EMAIL"
echo ""

# 1. Domain kontrolü
log "Domain DNS ayarları kontrol ediliyor..."
DOMAIN_IP=$(dig +short $DOMAIN)
WWW_IP=$(dig +short $WWW_DOMAIN)
SERVER_IP=$(curl -s ifconfig.me)

if [ -z "$DOMAIN_IP" ]; then
    error "Domain ($DOMAIN) DNS kaydı bulunamadı. DNS ayarlarını kontrol edin."
fi

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    warning "Domain IP ($DOMAIN_IP) sunucu IP'si ($SERVER_IP) ile eşleşmiyor."
    read -p "Devam etmek istiyor musunuz? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 2. Nginx test ve HTTP kurulumu
log "Nginx konfigürasyonu kontrol ediliyor..."
nginx -t || error "Nginx konfigürasyonu hatalı!"

# 3. HTTP-only Nginx konfigürasyonu (SSL öncesi)
log "SSL öncesi HTTP konfigürasyonu oluşturuluyor..."
cat > /etc/nginx/sites-available/ayyildizhaber-http << EOF
server {
    listen 80;
    server_name $DOMAIN $WWW_DOMAIN;
    
    # Let's Encrypt acme-challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files \$uri =404;
    }
    
    # Ana uygulama
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 4. Certbot dizinini oluştur
mkdir -p /var/www/certbot
chown www-data:www-data /var/www/certbot

# 5. Geçici HTTP konfigürasyonunu aktifleştir
ln -sf /etc/nginx/sites-available/ayyildizhaber-http /etc/nginx/sites-enabled/ayyildizhaber
rm -f /etc/nginx/sites-enabled/default
systemctl reload nginx

# 6. Uygulama çalışıyor mu kontrol et
log "Uygulama durumu kontrol ediliyor..."
if ! systemctl is-active --quiet ayyildizhaber.service; then
    log "Ayyıldız Haber servisi başlatılıyor..."
    systemctl start ayyildizhaber.service
    sleep 5
fi

# 7. HTTP erişim testi
log "HTTP erişim testi yapılıyor..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN/ || echo "000")
if [ "$HTTP_STATUS" != "200" ]; then
    error "HTTP erişim başarısız (Status: $HTTP_STATUS). Uygulama çalışmıyor olabilir."
fi

# 8. Let's Encrypt sertifikası al
log "Let's Encrypt SSL sertifikası alınıyor..."
certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d $DOMAIN \
    -d $WWW_DOMAIN

if [ $? -ne 0 ]; then
    error "SSL sertifikası alınamadı! Certbot loglarını kontrol edin."
fi

# 9. SSL Nginx konfigürasyonu
log "SSL Nginx konfigürasyonu oluşturuluyor..."
cat > /etc/nginx/sites-available/ayyildizhaber-ssl << EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN $WWW_DOMAIN;
    
    # Let's Encrypt acme-challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files \$uri =404;
    }
    
    # Redirect to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN $WWW_DOMAIN;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Static files
    location /static/ {
        alias $WEBROOT/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Favicon
    location /favicon.ico {
        alias $WEBROOT/static/images/favicon.ico;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Robots.txt
    location /robots.txt {
        alias $WEBROOT/static/robots.txt;
        expires 1d;
        access_log off;
    }
    
    # Rate limiting zones
    limit_req_zone \$binary_remote_addr zone=api:10m rate=30r/m;
    limit_req_zone \$binary_remote_addr zone=admin:10m rate=10r/m;
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Admin panel with additional security
    location /admin/ {
        limit_req zone=admin burst=5 nodelay;
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        proxy_buffering off;
    }
    
    # Security: Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ /deployment/ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# 10. SSL konfigürasyonunu aktifleştir
log "SSL konfigürasyonu aktifleştiriliyor..."
ln -sf /etc/nginx/sites-available/ayyildizhaber-ssl /etc/nginx/sites-enabled/ayyildizhaber
nginx -t || error "SSL Nginx konfigürasyonu hatalı!"
systemctl reload nginx

# 11. HTTPS erişim testi
log "HTTPS erişim testi yapılıyor..."
sleep 3
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN/ || echo "000")
if [ "$HTTPS_STATUS" != "200" ]; then
    warning "HTTPS erişim başarısız (Status: $HTTPS_STATUS). Konfigürasyonu kontrol edin."
fi

# 12. Otomatik yenileme cron job
log "SSL otomatik yenileme cron job konfigüre ediliyor..."
cat > /etc/cron.d/certbot-renew << EOF
# SSL sertifikası otomatik yenileme - Her gün 03:00'da çalışır
0 3 * * * root /usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"

# SSL sertifikası kontrol - Her hafta rapor gönder
0 9 * * 1 root /var/www/ayyildizhaber/deployment/ssl-check.sh
EOF

# 13. SSL kontrol scripti
log "SSL kontrol scripti oluşturuluyor..."
cat > /var/www/ayyildizhaber/deployment/ssl-check.sh << 'EOF'
#!/bin/bash

# SSL Sertifikası Kontrol Script
DOMAIN="ayyildizajans.com"
EMAIL="ayyildizcasttr@gmail.com"

# Sertifika son kullanma tarihi
EXPIRY_DATE=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -enddate | cut -d= -f2)
EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_TIMESTAMP=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))

# Log
echo "$(date): SSL Certificate expires in $DAYS_UNTIL_EXPIRY days" >> /var/log/ayyildizhaber/ssl.log

# 30 günden az kaldıysa uyarı
if [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
    echo "WARNING: SSL certificate for $DOMAIN expires in $DAYS_UNTIL_EXPIRY days!" | mail -s "SSL Certificate Warning" $EMAIL 2>/dev/null || echo "Mail send failed"
fi

# SSL test
SSL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN/ || echo "000")
if [ "$SSL_STATUS" != "200" ]; then
    echo "ERROR: HTTPS not accessible (Status: $SSL_STATUS)" | mail -s "SSL Access Error" $EMAIL 2>/dev/null || echo "Mail send failed"
fi
EOF

chmod +x /var/www/ayyildizhaber/deployment/ssl-check.sh

# 14. Firewall SSL port açma
log "Firewall HTTPS port açılıyor..."
ufw allow 443/tcp

# 15. Son kontroller
log "SSL kurulum son kontrolleri yapılıyor..."

# Sertifika dosyaları kontrol
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    error "SSL sertifika dosyası bulunamadı!"
fi

# Nginx syntax kontrol
nginx -t || error "Nginx konfigürasyonu hatalı!"

# SSL Grade kontrol (opsiyonel)
log "SSL Labs test başlatılıyor (sonuç 2-3 dakika sonra hazır olacak)..."
curl -s "https://api.ssllabs.com/api/v3/analyze?host=$DOMAIN&startNew=on" > /dev/null

echo ""
echo "=== SSL KURULUM TAMAMLANDI! ==="
echo ""
log "🔒 SSL sertifikası başarıyla kuruldu!"
echo ""
echo "📋 SSL BİLGİLERİ:"
echo "• HTTPS URL: https://$DOMAIN"
echo "• HTTPS URL: https://$WWW_DOMAIN"
echo "• Sertifika sağlayıcısı: Let's Encrypt"
echo "• Otomatik yenileme: Aktif (günlük kontrol)"
echo "• SSL Grade test: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo ""
echo "📁 SSL DOSYALARI:"
echo "• Sertifika: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
echo "• Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
echo "• SSL Log: /var/log/ayyildizhaber/ssl.log"
echo ""
echo "🔧 YÖNETİM KOMUTLARI:"
echo "• SSL yenileme test: certbot renew --dry-run"
echo "• SSL kontrol: /var/www/ayyildizhaber/deployment/ssl-check.sh"
echo "• Nginx reload: systemctl reload nginx"
echo "• SSL logları: tail -f /var/log/letsencrypt/letsencrypt.log"
echo ""
warning "HTTP (port 80) trafiği artık HTTPS'e yönlendiriliyor"
log "✅ Site artık tam güvenli HTTPS ile çalışıyor!"