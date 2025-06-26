#!/bin/bash

# Hızlı VPS Düzeltme Scripti
# Mevcut VPS'nizde virtual environment eksikse bu scripti çalıştırın

set -e

echo "=== VPS Python Environment Düzeltiliyor ==="

# Uygulama dizinine git
cd /var/www/ayyildizhaber

# Servisi durdur
echo "Servis durduruluyor..."
systemctl stop ayyildizhaber || true

# Python virtual environment oluştur (eksikse)
if [ ! -d "venv" ]; then
    echo "Python virtual environment oluşturuluyor..."
    python3 -m venv venv
fi

# Virtual environment'ı aktifleştir
source venv/bin/activate

# Pip güncellemesi
echo "Pip güncelleniyor..."
pip install --upgrade pip

# Temel paketleri yükle
echo "Temel paketler yükleniyor..."
pip install gunicorn flask flask-sqlalchemy flask-login werkzeug psycopg2-binary

# Sahiplik ayarları
echo "Dosya izinleri ayarlanıyor..."
chown -R www-data:www-data /var/www/ayyildizhaber
chmod -R 755 /var/www/ayyildizhaber

# Upload klasörü oluştur
mkdir -p static/uploads
chown -R www-data:www-data static/uploads
chmod -R 775 static/uploads

# Servisi yeniden başlat
echo "Servis yeniden başlatılıyor..."
systemctl daemon-reload
systemctl enable ayyildizhaber
systemctl start ayyildizhaber
systemctl restart nginx

echo "VPS hazır! Şimdi deploy scriptinizi çalıştırabilirsiniz."