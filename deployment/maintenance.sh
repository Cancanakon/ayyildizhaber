#!/bin/bash

# Ayyıldız Haber Ajansı - Haftalık Maintenance Script
# Bu script sistem temizliği ve optimizasyon yapar

set -e

echo "=== Ayyıldız Haber Maintenance Başlıyor - $(date) ==="

# 1. Cache temizliği
echo "Cache temizliği yapılıyor..."
find /var/www/ayyildizhaber/cache -name "*.json" -mtime +1 -delete
find /tmp -name "*.tmp" -user www-data -mtime +1 -delete

# 2. Log rotation
echo "Log dosyaları temizleniyor..."
find /var/log/ayyildizhaber -name "*.log" -size +100M -exec truncate -s 50M {} \;

# 3. Veritabanı optimizasyonu
echo "Veritabanı optimizasyonu yapılıyor..."
sudo -u postgres psql ayyildizhaber << EOF
VACUUM ANALYZE;
REINDEX DATABASE ayyildizhaber;
EOF

# 4. Sistem güncellemesi kontrolü
echo "Sistem güncellemeleri kontrol ediliyor..."
apt update -qq
UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
if [ $UPDATES -gt 1 ]; then
    echo "Güvenlik güncellemeleri mevcut: $((UPDATES-1)) paket"
    apt upgrade -y --only-upgrade $(apt list --upgradable 2>/dev/null | grep -E "(security|important)" | cut -d/ -f1 | tr '\n' ' ')
fi

# 5. Disk kullanımı kontrolü
echo "Disk kullanımı kontrol ediliyor..."
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "UYARI: Disk kullanımı %$DISK_USAGE - Temizlik gerekebilir"
fi

# 6. Servis health check
echo "Servis sağlığı kontrol ediliyor..."
systemctl is-active --quiet ayyildizhaber || systemctl restart ayyildizhaber
systemctl is-active --quiet nginx || systemctl restart nginx
systemctl is-active --quiet postgresql || systemctl restart postgresql

# 7. SSL sertifikası yenileme
echo "SSL sertifikası kontrol ediliyor..."
certbot renew --quiet --nginx

# 8. Güvenlik güncellemeleri
echo "Fail2ban IP listesi temizleniyor..."
fail2ban-client reload

# 9. Rapor
echo "$(date): Maintenance completed successfully" >> /var/log/ayyildizhaber/maintenance.log

echo "=== Maintenance Tamamlandı ==="