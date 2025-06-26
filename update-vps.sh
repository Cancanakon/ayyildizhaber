#!/bin/bash

echo "=== VPS Güncelleme Scripti ==="

# Güncellenen dosyaları VPS'e yükle
echo "Güncellenmiş dosyalar VPS'e yükleniyor..."

# Ana uygulama dosyalarını güncelle
scp -r templates/ root@69.62.110.158:/opt/ayyildizhaber/
scp -r static/ root@69.62.110.158:/opt/ayyildizhaber/
scp app.py root@69.62.110.158:/opt/ayyildizhaber/
scp ad_routes.py root@69.62.110.158:/opt/ayyildizhaber/

# VPS'e bağlan ve uygulamayı yeniden başlat
ssh root@69.62.110.158 << 'EOF'
echo "VPS'de değişiklikler uygulanıyor..."

cd /opt/ayyildizhaber

# Dosya izinleri
chown -R www-data:www-data .
chmod -R 755 .

# Servisi yeniden başlat
systemctl restart ayyildizhaber
systemctl reload nginx

echo "✅ Güncelleme tamamlandı"
echo "🌐 Site: http://www.ayyildizajans.com"
echo "🌐 IP: http://69.62.110.158"

# Servis durumu kontrol
systemctl status ayyildizhaber --no-pager -l
EOF

echo "VPS güncelleme tamamlandı!"