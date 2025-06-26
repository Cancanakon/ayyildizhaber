#!/bin/bash

# 502 Bad Gateway Hatası Düzeltme Scripti
echo "=== 502 Bad Gateway Hatası Düzeltiliyor ==="

# Flask uygulamasının durumunu kontrol et
echo "1. Flask uygulaması kontrol ediliyor..."
if ! pgrep -f "gunicorn.*main:app" > /dev/null; then
    echo "Flask uygulaması çalışmıyor, başlatılıyor..."
    
    cd /opt/ayyildizhaber
    
    # Gunicorn ile uygulamayı başlat
    nohup gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 120 main:app > /var/log/gunicorn.log 2>&1 &
    
    sleep 3
    
    if pgrep -f "gunicorn.*main:app" > /dev/null; then
        echo "✓ Flask uygulaması başlatıldı"
    else
        echo "✗ Flask uygulaması başlatılamadı"
        echo "Log kontrol edin: tail -f /var/log/gunicorn.log"
        exit 1
    fi
else
    echo "✓ Flask uygulaması zaten çalışıyor"
fi

# Port 5000'in dinlenip dinlenmediğini kontrol et
echo "2. Port 5000 kontrol ediliyor..."
if netstat -tuln | grep -q ":5000 "; then
    echo "✓ Port 5000 dinleniyor"
else
    echo "✗ Port 5000 dinlenmiyor"
    echo "Flask uygulaması yeniden başlatılıyor..."
    pkill -f "gunicorn.*main:app"
    sleep 2
    cd /opt/ayyildizhaber
    nohup gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 120 main:app > /var/log/gunicorn.log 2>&1 &
    sleep 3
fi

# Nginx konfigürasyonunu test et
echo "3. Nginx konfigürasyonu test ediliyor..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx konfigürasyonu geçerli"
    systemctl reload nginx
    echo "✓ Nginx yeniden yüklendi"
else
    echo "✗ Nginx konfigürasyonu hatalı"
    exit 1
fi

# Bağlantıyı test et
echo "4. Bağlantı test ediliyor..."
sleep 2

if curl -s -o /dev/null -w "%{http_code}" http://localhost:5000 | grep -q "200\|302\|404"; then
    echo "✓ Flask uygulamasına bağlantı başarılı"
else
    echo "✗ Flask uygulamasına bağlantı başarısız"
    echo "Log kontrol edin:"
    echo "tail -f /var/log/gunicorn.log"
    exit 1
fi

echo ""
echo "=== 502 Hatası Düzeltildi ==="
echo "Site şu adreslerde erişilebilir olmalı:"
echo "- http://69.62.110.158"
echo "- http://ayyildizajans.com"
echo ""
echo "Eğer hala sorun varsa:"
echo "- sudo systemctl status nginx"
echo "- tail -f /var/log/gunicorn.log"
echo "- tail -f /var/log/nginx/error.log"