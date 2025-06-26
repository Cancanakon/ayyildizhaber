#!/bin/bash

# Nginx SSL Configuration Fix Script
# Bu script SSL hatalarını düzeltir ve güvenli bir şekilde test eder

echo "=== Nginx SSL Configuration Fix ==="
echo "Başlangıç zamanı: $(date)"

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hata durumunda çıkış
set -e

# Root yetkisi kontrolü
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Bu script root yetkileriyle çalıştırılmalı!${NC}"
    echo "Kullanım: sudo bash nginx-test-fix.sh"
    exit 1
fi

# Nginx kurulu mu kontrol et
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}Nginx kurulu değil!${NC}"
    exit 1
fi

# Mevcut konfigürasyonu yedekle
BACKUP_DIR="/opt/nginx-backup-$(date +%Y%m%d-%H%M%S)"
echo -e "${YELLOW}Mevcut nginx konfigürasyonu yedekleniyor: $BACKUP_DIR${NC}"
mkdir -p "$BACKUP_DIR"
cp -r /etc/nginx/ "$BACKUP_DIR/" 2>/dev/null || true

# Sites dizinlerini oluştur
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Mevcut ayyildizhaber konfigürasyonunu kaldır
if [ -f "/etc/nginx/sites-enabled/ayyildizhaber" ]; then
    echo -e "${YELLOW}Mevcut konfigürasyon kaldırılıyor...${NC}"
    rm -f "/etc/nginx/sites-enabled/ayyildizhaber"
fi

# SSL olmadan temel konfigürasyonu kopyala
echo -e "${YELLOW}SSL olmadan güvenli konfigürasyon uygulanıyor...${NC}"
cp "$(dirname "$0")/nginx-fix.conf" /etc/nginx/sites-available/ayyildizhaber

# Konfigürasyonu etkinleştir
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/

# Nginx ana konfigürasyonunu kontrol et ve düzelt
echo -e "${YELLOW}Ana nginx.conf kontrol ediliyor...${NC}"
if ! grep -q "include /etc/nginx/sites-enabled" /etc/nginx/nginx.conf; then
    # sites-enabled dahil etme satırını ekle
    sed -i '/http {/a\\tinclude /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi

# Varsayılan site konfigürasyonunu kaldır
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    echo -e "${YELLOW}Varsayılan site konfigürasyonu kaldırılıyor...${NC}"
    rm -f "/etc/nginx/sites-enabled/default"
fi

# Nginx konfigürasyonunu test et
echo -e "${YELLOW}Nginx konfigürasyonu test ediliyor...${NC}"
if nginx -t; then
    echo -e "${GREEN}✓ Nginx konfigürasyonu geçerli!${NC}"
    
    # Nginx'i yeniden başlat
    echo -e "${YELLOW}Nginx yeniden başlatılıyor...${NC}"
    systemctl reload nginx
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx başarıyla çalışıyor!${NC}"
        echo -e "${GREEN}✓ HTTP (port 80) üzerinden site erişilebilir${NC}"
        echo ""
        echo -e "${YELLOW}SSL sertifikası eklemek için:${NC}"
        echo "1. sudo bash ssl-setup.sh komutunu çalıştırın"
        echo "2. Domain DNS ayarlarının doğru olduğundan emin olun"
        echo ""
    else
        echo -e "${RED}✗ Nginx başlatılamadı!${NC}"
        systemctl status nginx
        exit 1
    fi
else
    echo -e "${RED}✗ Nginx konfigürasyonu hatalı!${NC}"
    echo -e "${YELLOW}Yedek konfigürasyon geri yükleniyor...${NC}"
    
    # Yedekten geri yükle
    if [ -d "$BACKUP_DIR/nginx" ]; then
        cp -r "$BACKUP_DIR/nginx/"* /etc/nginx/
        systemctl reload nginx
        echo -e "${YELLOW}Yedek konfigürasyon geri yüklendi${NC}"
    fi
    exit 1
fi

echo ""
echo -e "${GREEN}=== Nginx SSL Düzeltme Tamamlandı ===${NC}"
echo "Site adresi: http://69.62.110.158"
echo "Domain: http://ayyildizajans.com"
echo ""
echo -e "${YELLOW}SSL eklemek için ssl-setup.sh scriptini kullanabilirsiniz${NC}"