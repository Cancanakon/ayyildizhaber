#!/bin/bash

# VPS Sync Script - Sadece değişen dosyaları gönder
# Usage: ./sync-to-vps.sh

SERVER_IP="69.62.110.158"
USERNAME="root"
REMOTE_PATH="/var/www/ayyildizajans"

echo "🔄 Dosya senkronizasyonu başlatılıyor..."

# Rsync ile sadece değişen dosyaları gönder
rsync -avz --delete \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.git/' \
    --exclude='venv/' \
    --exclude='cache/' \
    --exclude='*.log' \
    --exclude='migrations/' \
    ./ $USERNAME@$SERVER_IP:$REMOTE_PATH/

echo "📁 Dosyalar senkronize edildi, servisleri yeniden başlatıyor..."

# Uzak sunucuda servisleri yeniden başlat
ssh $USERNAME@$SERVER_IP << 'ENDSSH'
cd /var/www/ayyildizajans
source venv/bin/activate

# Sadece yeni paketler varsa yükle
pip install -r requirements.txt --quiet

# Servisleri graceful restart
sudo systemctl reload gunicorn || sudo systemctl restart gunicorn
sudo systemctl reload nginx

echo "✅ Servisler yeniden başlatıldı"
echo "🌐 Site durumu:"
curl -s -o /dev/null -w "%{http_code}" http://localhost:5000
ENDSSH

echo "🎉 VPS senkronizasyonu tamamlandı!"
echo "🌐 Site: http://$SERVER_IP"