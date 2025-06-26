#!/bin/bash

echo "=== Hızlı VPS Düzeltme Scripti ==="

# 1. Uygulama dizinini kontrol et
if [ ! -d "/opt/ayyildizhaber" ]; then
    echo "Uygulama dizini oluşturuluyor..."
    mkdir -p /opt/ayyildizhaber
    cp -r /tmp/vps-deployment/* /opt/ayyildizhaber/
fi

cd /opt/ayyildizhaber

# 2. Python sanal ortamını kontrol et
if [ ! -d "venv" ]; then
    echo "Python sanal ortamı oluşturuluyor..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install Flask Flask-SQLAlchemy Flask-Login psycopg2-binary gunicorn requests beautifulsoup4 lxml trafilatura APScheduler python-dateutil email-validator feedparser Werkzeug
else
    source venv/bin/activate
fi

# 3. PostgreSQL kullanıcı ve veritabanı kontrol
DB_USER="ayyildizhaber"
DB_NAME="ayyildizhaber_db"
DB_PASS="ayyildiz123"

sudo -u postgres createuser --createdb $DB_USER 2>/dev/null || true
sudo -u postgres createdb $DB_NAME -O $DB_USER 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER $DB_USER PASSWORD '$DB_PASS';" 2>/dev/null || true

# 4. Çevre değişkenleri
export DATABASE_URL="postgresql://$DB_USER:$DB_PASS@localhost/$DB_NAME"
export SESSION_SECRET="$(openssl rand -base64 32)"

cat > .env << EOF
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost/$DB_NAME
SESSION_SECRET=$SESSION_SECRET
FLASK_ENV=production
FLASK_DEBUG=False
EOF

# 5. Veritabanı tabloları oluştur
echo "Veritabanı tabloları oluşturuluyor..."
python3 -c "
import os
import sys
os.environ['DATABASE_URL'] = '$DATABASE_URL'
os.environ['SESSION_SECRET'] = '$SESSION_SECRET'
try:
    from app import app, db
    with app.app_context():
        db.create_all()
        print('✅ Veritabanı tabloları oluşturuldu')
except Exception as e:
    print(f'Veritabanı hatası: {e}')
"

# 6. Dosya izinleri
chown -R www-data:www-data /opt/ayyildizhaber
chmod -R 755 /opt/ayyildizhaber

# 7. Systemd servisi oluştur
cat > /etc/systemd/system/ayyildizhaber.service << EOF
[Unit]
Description=Ayyıldız Haber Ajansı
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/ayyildizhaber
Environment=DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost/$DB_NAME
Environment=SESSION_SECRET=$SESSION_SECRET
Environment=FLASK_ENV=production
ExecStart=/opt/ayyildizhaber/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 --timeout 120 main:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 8. HTTP-only Nginx yapılandırması
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
upstream ayyildizhaber_app {
    server 127.0.0.1:5000 fail_timeout=0;
}

server {
    listen 80;
    server_name www.ayyildizajans.com ayyildizajans.com 69.62.110.158;
    
    location / {
        proxy_pass http://ayyildizhaber_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
    
    location /static/ {
        alias /opt/ayyildizhaber/static/;
        expires 30d;
    }
    
    location /uploads/ {
        alias /opt/ayyildizhaber/static/uploads/;
        expires 7d;
    }
}
EOF

# 9. Nginx'i etkinleştir
ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 10. Servisleri başlat
systemctl daemon-reload
systemctl enable ayyildizhaber
systemctl start ayyildizhaber
nginx -t && systemctl reload nginx

# 11. Durum kontrolü
echo ""
echo "=== DURUM KONTROLÜ ==="
systemctl is-active --quiet ayyildizhaber && echo "✅ Ayyıldız Haber çalışıyor" || echo "❌ Uygulama sorunu"
systemctl is-active --quiet nginx && echo "✅ Nginx çalışıyor" || echo "❌ Nginx sorunu"
systemctl is-active --quiet postgresql && echo "✅ PostgreSQL çalışıyor" || echo "❌ PostgreSQL sorunu"

echo ""
echo "=== PORT KONTROLÜ ==="
ss -tlnp | grep :80 > /dev/null && echo "✅ Port 80 açık" || echo "❌ Port 80 kapalı"
ss -tlnp | grep :5000 > /dev/null && echo "✅ Port 5000 açık" || echo "❌ Port 5000 kapalı"

echo ""
echo "=== SİTE TESTİ ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost | grep 200 > /dev/null && echo "✅ Site çalışıyor" || echo "❌ Site erişim sorunu"

echo ""
echo "=== ERİŞİM BİLGİLERİ ==="
echo "🌐 Site: http://www.ayyildizajans.com"
echo "🌐 IP: http://69.62.110.158"
echo "🔧 Admin: http://www.ayyildizajans.com/admin"
echo "👤 Giriş: admin@gmail.com / admin123"

echo ""
echo "=== LOG KONTROL KOMUTLARI ==="
echo "journalctl -u ayyildizhaber -f"
echo "systemctl status ayyildizhaber"
echo "systemctl status nginx"