#!/bin/bash

# Hızlı VPS Güncelleme - Tek komut ile güncelleme
# Usage: ./quick-update.sh

SERVER_IP="69.62.110.158"
USERNAME="root"

echo "🚀 Hızlı güncelleme başlatılıyor..."

# Dosyaları sıkıştır ve gönder (bilgisayarınızdan)
tar -czf update.tar.gz \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='venv' \
    --exclude='cache' \
    --exclude='*.log' \
    --exclude='update*.sh' \
    --exclude='quick*.sh' \
    --exclude='sync*.sh' \
    .

echo "📦 Dosyalar hazırlandı, sunucuya gönderiliyor..."

# Sunucuya gönder ve güncelle
scp update.tar.gz $USERNAME@$SERVER_IP:/tmp/

ssh $USERNAME@$SERVER_IP << 'ENDSSH'
# Backup yap
cp -r /var/www/ayyildizajans /var/www/ayyildizajans_backup_$(date +%Y%m%d_%H%M%S)

# Güncelleme uygula
cd /var/www/ayyildizajans
tar -xzf /tmp/update.tar.gz --overwrite

# Dependencies güncelle
source venv/bin/activate
pip install -r requirements.txt --quiet

# Servisleri yeniden başlat
sudo systemctl restart gunicorn
sudo systemctl restart nginx

echo "✅ Güncelleme tamamlandı!"
curl -I http://localhost 2>/dev/null | head -1

rm /tmp/update.tar.gz
ENDSSH

rm update.tar.gz

echo "🎉 VPS güncelleme başarıyla tamamlandı!"
echo "🌐 Site: http://$SERVER_IP"