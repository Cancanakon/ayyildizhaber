#!/bin/bash

# Ayyıldız Haber Ajansı - GitHub'dan Güncelleme Script
# Mevcut VPS'de çalışan sistemi güncellemek için

set -e

PROJECT_DIR="/var/www/ayyildizhaber"
BACKUP_DIR="/var/backups/ayyildizhaber-$(date +%Y%m%d-%H%M%S)"

echo "=== Ayyıldız Haber Ajansı GitHub Güncelleme ==="

# Uygulamayı durdur
echo "1/7 - Uygulama durduruluyor..."
sudo supervisorctl stop ayyildizhaber

# Mevcut kodu yedekle
echo "2/7 - Mevcut kod yedekleniyor..."
sudo mkdir -p /var/backups
sudo cp -r $PROJECT_DIR $BACKUP_DIR
echo "Yedek oluşturuldu: $BACKUP_DIR"

# GitHub'dan en son kodu çek
echo "3/7 - GitHub'dan kod güncelleniyor..."
cd $PROJECT_DIR
sudo git fetch origin
sudo git reset --hard origin/main
sudo git pull origin main

# Sahiplik izinlerini düzelt
echo "4/7 - İzinler düzenleniyor..."
sudo chown -R www-data:www-data $PROJECT_DIR
sudo chmod -R 755 $PROJECT_DIR

# Python bağımlılıklarını güncelle
echo "5/7 - Python paketleri güncelleniyor..."
sudo -u www-data python3 -m pip install -r requirements.txt --upgrade

# Veritabanını güncelle
echo "6/7 - Veritabanı kontrol ediliyor..."
sudo -u www-data python3 -c "
import sys
sys.path.append('$PROJECT_DIR')
from app import app, db
with app.app_context():
    db.create_all()
    print('Veritabanı güncellendi')
"

# Uygulamayı yeniden başlat
echo "7/7 - Uygulama başlatılıyor..."
sudo supervisorctl start ayyildizhaber
sudo supervisorctl status ayyildizhaber

# Nginx'i yeniden yükle
sudo nginx -t && sudo systemctl reload nginx

echo ""
echo "✅ Güncelleme tamamlandı!"
echo "📁 Yedek: $BACKUP_DIR"
echo "🌐 Website: http://$(curl -s ifconfig.me)"
echo "🔗 API Base URL: http://$(curl -s ifconfig.me)/api/v1"
echo ""
echo "API Test:"
echo "  curl -H \"X-API-Key: ayyildizhaber_mobile_2025\" \"http://$(curl -s ifconfig.me)/api/v1/info\""
echo ""
echo "Kontrol komutları:"
echo "  sudo supervisorctl status ayyildizhaber"
echo "  sudo tail -f /var/log/supervisor/ayyildizhaber.log"
echo "  sudo systemctl status nginx"