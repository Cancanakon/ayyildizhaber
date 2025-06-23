#!/bin/bash

# Nginx configuration fix script
# Bu script mevcut problemli Nginx konfigürasyonunu düzeltir

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

log "Nginx configuration fix başlatılıyor..."

# Mevcut problemli config'i kaldır
log "Problemli Nginx konfigürasyonu kaldırılıyor..."
rm -f /etc/nginx/sites-enabled/ayyildizhaber
rm -f /etc/nginx/sites-available/ayyildizhaber

# Doğru config'i kopyala
log "Doğru Nginx konfigürasyonu kopyalanıyor..."
if [ -f "/opt/ayyildizhaber/deployment/nginx-site.conf" ]; then
    cp /opt/ayyildizhaber/deployment/nginx-site.conf /etc/nginx/sites-available/ayyildizhaber
elif [ -f "/var/www/ayyildizhaber/deployment/nginx-site.conf" ]; then
    cp /var/www/ayyildizhaber/deployment/nginx-site.conf /etc/nginx/sites-available/ayyildizhaber
else
    error "nginx-site.conf dosyası bulunamadı!"
fi

# Symlink oluştur
log "Nginx site aktifleştiriliyor..."
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Nginx test
log "Nginx konfigürasyonu test ediliyor..."
nginx -t

if [ $? -eq 0 ]; then
    log "Nginx konfigürasyonu başarılı!"
    systemctl reload nginx
    log "Nginx reload edildi"
else
    error "Nginx konfigürasyonu hala hatalı!"
fi

log "Nginx fix tamamlandı!"