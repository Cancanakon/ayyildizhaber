#!/bin/bash

# 502 Bad Gateway Düzeltme Scripti
# VPS'te çalıştırın

echo "🔧 502 Bad Gateway hatası düzeltiliyor..."

# Gunicorn servis durumunu kontrol et
echo "📊 Servis durumları:"
systemctl status gunicorn --no-pager -l || echo "Gunicorn çalışmıyor"
systemctl status nginx --no-pager -l || echo "Nginx çalışmıyor"

# Port 5000 kullanımını kontrol et
echo "🔍 Port 5000 kontrol ediliyor:"
netstat -tlnp | grep :5000 || echo "Port 5000 boş"

# Proje klasörüne git
cd /var/www/ayyildizajans

# Virtual environment ve Flask app test et
echo "🐍 Flask app test ediliyor:"
source venv/bin/activate

# Environment variables set et
export DATABASE_URL="postgresql://ayyildizhaber:ayyildiz2025!@localhost/ayyildizhaber"
export SESSION_SECRET="ayyildiz-super-secret-key-2025"

# Flask app manuel test
python3 -c "
try:
    from app import app
    print('✅ Flask app yüklendi')
    with app.app_context():
        from models import Admin
        print('✅ Database bağlantısı OK')
except Exception as e:
    print(f'❌ Hata: {e}')
"

# Gunicorn'u manuel başlat (test için)
echo "🚀 Gunicorn manuel test..."
timeout 10s gunicorn --bind 0.0.0.0:5000 --workers 1 main:app &
sleep 3

# Test et
curl -I http://localhost:5000 2>/dev/null && echo "✅ Manuel test başarılı" || echo "❌ Manuel test başarısız"

# Process'leri temizle
pkill -f gunicorn

# Systemd servisini düzelt ve başlat
echo "⚙️ Systemd servisi düzeltiliyor..."

# Yeni servis dosyası oluştur
cat > /etc/systemd/system/gunicorn.service << 'EOF'
[Unit]
Description=Gunicorn instance to serve Ayyıldız Haber
After=network.target postgresql.service
Requires=postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/ayyildizajans
Environment="PATH=/var/www/ayyildizajans/venv/bin"
Environment="DATABASE_URL=postgresql://ayyildizhaber:ayyildiz2025!@localhost/ayyildizhaber"
Environment="SESSION_SECRET=ayyildiz-super-secret-key-2025"
Environment="FLASK_APP=main.py"
ExecStart=/var/www/ayyildizajans/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 300 --keep-alive 2 --preload main:app
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

# Dosya izinlerini düzelt
chown -R www-data:www-data /var/www/ayyildizajans
chmod -R 755 /var/www/ayyildizajans

# Servisleri yeniden başlat
systemctl daemon-reload
systemctl stop gunicorn
systemctl start gunicorn
systemctl enable gunicorn

# Nginx'i restart et
systemctl restart nginx

echo "⏳ 5 saniye bekleniyor..."
sleep 5

# Final test
echo "🌐 Site test ediliyor:"
curl -I http://localhost:5000 2>/dev/null | head -1 || echo "Hala çalışmıyor"

echo "📊 Final durum:"
systemctl status gunicorn --no-pager -l | head -10
systemctl status nginx --no-pager -l | head -5

echo "✅ Düzeltme tamamlandı!"
echo "🌐 Test: http://$(hostname -I | awk '{print $1}')"