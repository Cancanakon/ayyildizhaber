#!/bin/bash

# Tam Proje Deployment Scripti - Bilgisayardan VPS'ye
# Usage: ./deploy-complete.sh

SERVER_IP="69.62.110.158"
USERNAME="root"

echo "🚀 Ayyıldız Haber Ajansı - Tam Deployment Başlatılıyor..."

# Proje dosyalarını hazırla
echo "📦 Proje dosyaları paketleniyor..."
tar -czf ayyildiz-complete.tar.gz \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='venv' \
    --exclude='cache' \
    --exclude='*.log' \
    --exclude='*.sh' \
    --exclude='*.tar.gz' \
    .

echo "📤 Dosyalar sunucuya gönderiliyor..."

# Sunucuya gönder
scp ayyildiz-complete.tar.gz $USERNAME@$SERVER_IP:/tmp/

echo "🔧 Sunucuda kurulum başlatılıyor..."

ssh $USERNAME@$SERVER_IP << 'ENDSSH'
# Proje klasörüne git
cd /var/www/ayyildizajans

# Dosyaları extract et
tar -xzf /tmp/ayyildiz-complete.tar.gz --overwrite

# Virtual environment aktif et
source venv/bin/activate

# Python paketlerini yükle
pip install -r requirements.txt

# Static klasörler oluştur
mkdir -p static/uploads static/admin static/images

# Veritabanı tabloları oluştur
python3 -c "
from app import db, app
with app.app_context():
    db.create_all()
    print('✅ Database tables created')
"

# Dosya izinlerini düzelt
chown -R www-data:www-data /var/www/ayyildizajans
chmod -R 755 /var/www/ayyildizajans
chmod -R 777 static/uploads

# Gunicorn servisini başlat
systemctl start gunicorn
systemctl enable gunicorn

# Nginx'i yeniden başlat
systemctl restart nginx

echo "✅ Deployment tamamlandı!"

# Servis durumlarını kontrol et
echo "📊 Servis Durumları:"
systemctl status gunicorn --no-pager -l | head -5
systemctl status nginx --no-pager -l | head -5

# Site erişimi test et
echo "🌐 Site erişimi test ediliyor..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:5000

# Cleanup
rm /tmp/ayyildiz-complete.tar.gz

echo "🎉 Site hazır!"
echo "📱 Site: http://$(hostname -I | awk '{print $1}')"
echo "🔧 Admin: http://$(hostname -I | awk '{print $1}')/admin"
echo "📺 Admin login: admin@gmail.com / admin123"
ENDSSH

# Yerel cleanup
rm ayyildiz-complete.tar.gz

echo "✅ Deployment başarıyla tamamlandı!"
echo "🌐 Site: http://$SERVER_IP"
echo "🔧 Admin Panel: http://$SERVER_IP/admin"