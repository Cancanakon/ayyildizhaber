#!/bin/bash

# Ayyıldız Haber Ajansı - Hızlı Başlatma
# Sadece gerekli servisleri başlatır

echo "Ayyıldız Haber Ajansı - Hızlı Başlatma"

# PostgreSQL başlat
sudo systemctl start postgresql

# Uygulama servisini başlat
sudo systemctl start ayyildizhaber

# Nginx başlat
sudo systemctl start nginx

# Durumları kontrol et
echo "=== SERVİS DURUMLARI ==="
echo -n "PostgreSQL: "
systemctl is-active postgresql

echo -n "Uygulama: "
systemctl is-active ayyildizhaber

echo -n "Nginx: "
systemctl is-active nginx

echo ""
echo "Site erişimi: http://$(curl -s ifconfig.me 2>/dev/null)"