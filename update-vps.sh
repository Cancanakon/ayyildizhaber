#!/bin/bash

# VPS Update Script - Server sıfırlamadan güncelleme
# Usage: ./update-vps.sh [server_ip] [username]

set -e

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVER_IP=${1:-"69.62.110.158"}
USERNAME=${2:-"root"}
APP_DIR="/var/www/ayyildizajans"

echo -e "${BLUE}🚀 VPS Güncelleme Başlatılıyor...${NC}"
echo -e "${YELLOW}Server: ${SERVER_IP}${NC}"
echo -e "${YELLOW}Kullanıcı: ${USERNAME}${NC}"

# Geçici dosya oluştur
TEMP_FILE=$(mktemp)
echo "#!/bin/bash" > $TEMP_FILE

# Güncelleme komutlarını hazırla
cat >> $TEMP_FILE << 'EOF'
set -e

cd /var/www/ayyildizajans

echo "🔄 Mevcut dosyalar yedekleniyor..."
cp -r /var/www/ayyildizajans /var/www/ayyildizajans_backup_$(date +%Y%m%d_%H%M%S)
echo "Yedek oluşturuldu: ayyildizajans_backup_$(date +%Y%m%d_%H%M%S)"

echo "🐍 Python dependencies güncelleniyor..."
source venv/bin/activate
pip install -r requirements.txt --quiet

echo "📁 Static dosyalar güncelleniyor..."
# Admin panel assets
if [ ! -d "static/admin" ]; then
    mkdir -p static/admin/css static/admin/js
fi

echo "🗃️ Veritabanı migration kontrol..."
# Flask migration varsa çalıştır
if [ -f "migrations/alembic.ini" ]; then
    flask db upgrade
else
    echo "Migration dosyası bulunamadı, atlaniyor..."
fi

echo "♻️ Gunicorn servisi yeniden başlatılıyor..."
sudo systemctl restart gunicorn
sudo systemctl restart nginx

echo "✅ Servis durumu kontrol ediliyor..."
sudo systemctl status gunicorn --no-pager -l
sudo systemctl status nginx --no-pager -l

echo "🎉 Güncelleme tamamlandı!"
echo "📊 Sistem durumu:"
ps aux | grep gunicorn | grep -v grep
curl -I http://localhost:5000 2>/dev/null | head -1 || echo "Lokal test başarısız"

echo "🌐 Site erişimi test ediliyor..."
curl -I http://$(hostname -I | awk '{print $1}') 2>/dev/null | head -1 || echo "Dış erişim test başarısız"
EOF

echo -e "${GREEN}📤 Güncelleme scripti sunucuya gönderiliyor...${NC}"

# Önce dosyaları sunucuya gönder
echo -e "${GREEN}📤 Proje dosyaları sunucuya gönderiliyor...${NC}"

# Dosyaları sıkıştır (gereksiz dosyaları hariç tut)
tar -czf /tmp/ayyildiz_update.tar.gz \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='venv' \
    --exclude='cache' \
    --exclude='*.log' \
    --exclude='update-vps.sh' \
    --exclude='quick-update.sh' \
    --exclude='sync-to-vps.sh' \
    .

# Dosyaları ve scripti sunucuya gönder
scp /tmp/ayyildiz_update.tar.gz $USERNAME@$SERVER_IP:/tmp/
scp $TEMP_FILE $USERNAME@$SERVER_IP:/tmp/update_script.sh

echo -e "${GREEN}🔧 Sunucuda güncelleme çalıştırılıyor...${NC}"

ssh $USERNAME@$SERVER_IP << 'ENDSSH'
# Güncelleme scriptini çalıştır
chmod +x /tmp/update_script.sh

# Dosyaları extract et
cd /tmp
tar -xzf ayyildiz_update.tar.gz -C /var/www/ayyildizajans/ --overwrite

# Update scriptini çalıştır
/tmp/update_script.sh

# Geçici dosyaları temizle
rm /tmp/update_script.sh /tmp/ayyildiz_update.tar.gz
ENDSSH

# Yerel geçici dosyayı temizle
rm /tmp/ayyildiz_update.tar.gz

# Geçici dosyayı temizle
rm $TEMP_FILE

echo -e "${GREEN}✅ VPS güncelleme tamamlandı!${NC}"
echo -e "${BLUE}🌐 Site kontrol: http://$SERVER_IP${NC}"

# Son durum kontrolü
echo -e "${YELLOW}📊 Sunucu durumu son kontrol...${NC}"
ssh $USERNAME@$SERVER_IP 'echo "=== Disk Kullanımı ===" && df -h / && echo "=== Memory Kullanımı ===" && free -h && echo "=== Load Average ===" && uptime'

echo -e "${GREEN}🎯 Güncelleme başarıyla tamamlandı!${NC}"