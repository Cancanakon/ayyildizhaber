#!/bin/bash

# Proje Deployment Scripti - Bilgisayardan VPS'ye
# Kullanım: ./deploy.sh

SERVER_IP="69.62.110.158"
USERNAME="root"

echo "Ayyıldız Haber Ajansı deployment başlatılıyor..."

# Proje dosyalarını paketleme
echo "Proje dosyaları paketleniyor..."
tar -czf project.tar.gz \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='venv' \
    --exclude='cache' \
    --exclude='*.log' \
    --exclude='*.tar.gz' \
    --exclude='install.sh' \
    --exclude='deploy.sh' \
    .

echo "Dosyalar sunucuya gönderiliyor..."
scp project.tar.gz $USERNAME@$SERVER_IP:/tmp/

echo "Sunucuda kurulum başlatılıyor..."
ssh $USERNAME@$SERVER_IP << 'ENDSSH'
# Proje klasörüne git
cd /var/www/ayyildizajans

# Dosyaları çıkar
tar -xzf /tmp/project.tar.gz

# Virtual environment aktif et
source venv/bin/activate

# Python paketlerini yükle
pip install -r requirements.txt

# Klasörler oluştur
mkdir -p static/uploads static/admin

# Veritabanı tablolarını oluştur
export DATABASE_URL="postgresql://ayyildizhaber:ayyildiz2025!@localhost/ayyildizhaber"
export SESSION_SECRET="ayyildiz-haber-2025-secret-key"

python3 -c "
from app import db, app
with app.app_context():
    db.create_all()
    print('Veritabanı tabloları oluşturuldu')
"

# Dosya izinlerini düzelt
chown -R www-data:www-data /var/www/ayyildizajans
chmod -R 755 /var/www/ayyildizajans
chmod -R 777 static/uploads

# Gunicorn servisini başlat
systemctl start gunicorn
systemctl restart nginx

echo "Deployment tamamlandı!"

# Test
sleep 3
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000)
echo "HTTP Test: $HTTP_CODE"

# Servis durumları
echo "Gunicorn: $(systemctl is-active gunicorn)"
echo "Nginx: $(systemctl is-active nginx)"

# Cleanup
rm /tmp/project.tar.gz

echo "Site hazır: http://$(hostname -I | awk '{print $1}')"
echo "Admin: http://$(hostname -I | awk '{print $1}')/admin"
ENDSSH

# Yerel cleanup
rm project.tar.gz

echo "Deployment başarıyla tamamlandı!"
echo "Site: http://$SERVER_IP"
echo "Admin: http://$SERVER_IP/admin"
echo "Giriş: admin@gmail.com / admin123"