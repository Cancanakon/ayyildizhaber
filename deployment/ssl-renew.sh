#!/bin/bash

# Ayyıldız Haber Ajansı - SSL Sertifikası Yenileme Script
# Bu script SSL sertifikasını yeniler ve gerekli servisleri yeniden başlatır

set -e

DOMAIN="ayyildizajans.com"
LOG_FILE="/var/log/ayyildizhaber/ssl-renew.log"

# Log fonksiyonu
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a $LOG_FILE
}

log "SSL sertifikası yenileme başlıyor..."

# 1. Mevcut sertifika kontrol
DAYS_LEFT=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -checkend $((30*24*3600)) && echo "30+" || echo "less than 30")

if [ "$DAYS_LEFT" = "30+" ]; then
    log "SSL sertifikası henüz yenilenmesi gerekmiyor (30+ gün kaldı)"
    exit 0
fi

log "SSL sertifikası 30 günden az süre kaldı, yenileniyor..."

# 2. Certbot yenileme
if certbot renew --quiet --no-self-upgrade; then
    log "SSL sertifikası başarıyla yenilendi"
    
    # 3. Nginx reload
    if nginx -t; then
        systemctl reload nginx
        log "Nginx başarıyla yeniden yüklendi"
    else
        log "ERROR: Nginx konfigürasyon hatası!"
        exit 1
    fi
    
    # 4. Test
    if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN/ | grep -q "200"; then
        log "HTTPS erişim testi başarılı"
    else
        log "WARNING: HTTPS erişim testi başarısız"
    fi
    
else
    log "ERROR: SSL sertifikası yenilenemedi!"
    exit 1
fi

log "SSL sertifikası yenileme tamamlandı"