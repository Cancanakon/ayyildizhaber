#!/bin/bash

# Canlı Yayın Sistemi ile Beraber Deployment
# Usage: ./deploy-live-stream.sh

SERVER_IP="69.62.110.158"
USERNAME="root"

echo "🎬 Canlı Yayın Sistemi Güncelleniyor..."

# Bilgisayarınızdan dosyaları hazırla
tar -czf live-stream-update.tar.gz \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='venv' \
    --exclude='cache' \
    --exclude='*.log' \
    --exclude='*.sh' \
    .

echo "📤 Dosyalar sunucuya gönderiliyor..."

# Sunucuya gönder
scp live-stream-update.tar.gz $USERNAME@$SERVER_IP:/tmp/

ssh $USERNAME@$SERVER_IP << 'ENDSSH'
# Backup yap
cp -r /var/www/ayyildizajans /var/www/ayyildizajans_backup_$(date +%Y%m%d_%H%M%S)

# Güncelleme uygula
cd /var/www/ayyildizajans
tar -xzf /tmp/live-stream-update.tar.gz --overwrite

# Virtual environment aktif et
source venv/bin/activate

# Yeni paketleri yükle
pip install -r requirements.txt --quiet

# Veritabanı tabloları oluştur/güncelle
python3 -c "
from app import db, app
with app.app_context():
    db.create_all()
    print('✅ Database tables updated')
"

# Canlı yayın route'unu app.py'ye ekle (eğer yoksa)
if ! grep -q "live_stream" app.py; then
    echo "
# Import live stream routes
from live_stream_routes import live_stream_bp
app.register_blueprint(live_stream_bp, url_prefix='/admin/live-stream')
" >> app.py
    echo "✅ Live stream routes registered"
fi

# File permissions düzelt
chown -R www-data:www-data /var/www/ayyildizajans
chmod -R 755 /var/www/ayyildizajans

# Servisleri yeniden başlat
systemctl restart gunicorn
systemctl restart nginx

echo "🎉 Canlı Yayın Sistemi Güncellendi!"

# Test et
sleep 3
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:5000

# Cleanup
rm /tmp/live-stream-update.tar.gz

echo "✅ Güncelleme tamamlandı!"
echo "🌐 Admin Panel: http://$(hostname -I | awk '{print $1}')/admin"
echo "📺 Canlı Yayın Yönetimi: http://$(hostname -I | awk '{print $1}')/admin/live-stream"
ENDSSH

# Yerel cleanup
rm live-stream-update.tar.gz

echo "🎯 Deployment başarıyla tamamlandı!"
echo "🌐 Site: http://$SERVER_IP"
echo "📺 Admin'den canlı yayın URL'sini değiştirebilirsiniz"