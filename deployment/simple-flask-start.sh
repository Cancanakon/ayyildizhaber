#!/bin/bash

# Basit Flask Başlatma Scripti - Gunicorn olmadan
echo "=== Flask Uygulaması Basit Başlatma ==="

cd /opt/ayyildizhaber

# Mevcut Python proseslerini durdur
pkill -f "python.*main.py"
pkill -f "python.*app.py"
sleep 2

# Python path'ini kontrol et
export PYTHONPATH="/opt/ayyildizhaber:$PYTHONPATH"

# Flask uygulamasını doğrudan başlat
echo "Flask uygulaması başlatılıyor..."

# main.py varsa onu çalıştır
if [ -f "main.py" ]; then
    nohup python3 main.py > /var/log/flask-app.log 2>&1 &
elif [ -f "app.py" ]; then
    nohup python3 app.py > /var/log/flask-app.log 2>&1 &
else
    echo "main.py veya app.py bulunamadı!"
    exit 1
fi

# Başlatma kontrolü
sleep 3

if pgrep -f "python.*main.py\|python.*app.py" > /dev/null; then
    echo "✓ Flask uygulaması başlatıldı"
    
    # Port kontrolü
    sleep 2
    if netstat -tuln | grep -q ":5000"; then
        echo "✓ Port 5000 dinleniyor"
        
        # Test bağlantısı
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:5000 | grep -q "200\|302\|404"; then
            echo "✓ Flask uygulaması erişilebilir"
        else
            echo "! Flask uygulaması henüz hazır değil, 10 saniye bekleyin"
        fi
    else
        echo "✗ Port 5000 dinlenmiyor"
        echo "Log kontrol edin: tail -f /var/log/flask-app.log"
    fi
else
    echo "✗ Flask uygulaması başlatılamadı"
    echo "Log kontrol edin: tail -f /var/log/flask-app.log"
    exit 1
fi

echo ""
echo "=== Flask Uygulaması Çalışıyor ==="
echo "Log dosyası: tail -f /var/log/flask-app.log"
echo "Process ID: $(pgrep -f 'python.*main.py\|python.*app.py')"