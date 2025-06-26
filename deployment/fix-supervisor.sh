#!/bin/bash

# Supervisor hatasını düzelt ve sistemi çalıştır

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[HATA] $1${NC}"
    exit 1
}

log "Supervisor sorunu çözülüyor..."

# 1. Supervisor'ı tamamen yeniden kur
log "Supervisor yeniden kuruluyor..."
apt remove --purge supervisor -y 2>/dev/null || true
apt autoremove -y
apt install supervisor -y

# 2. Supervisor'ı başlat
log "Supervisor servisi başlatılıyor..."
systemctl enable supervisor
systemctl start supervisor
sleep 3

# 3. Yeni config dosyası oluştur
log "Ayyıldız config dosyası oluşturuluyor..."
cat > /etc/supervisor/conf.d/ayyildiz.conf << EOF
[program:ayyildiz]
command=/var/www/ayyildiz/start.sh
directory=/var/www/ayyildiz
user=ayyildiz
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/ayyildiz.log
stderr_logfile=/var/log/ayyildiz_error.log
environment=PATH="/var/www/ayyildiz/venv/bin:/usr/local/bin:/usr/bin:/bin"
EOF

# 4. Supervisor'ı yeniden yükle
log "Supervisor yapılandırması yeniden yükleniyor..."
supervisorctl reread
supervisorctl update

# 5. Uygulamayı başlat
log "Uygulama başlatılıyor..."
supervisorctl start ayyildiz

# 6. Durum kontrolü
log "Durum kontrol ediliyor..."
sleep 5

SUPERVISOR_STATUS=$(supervisorctl status ayyildiz | grep -o "RUNNING" || echo "NOT_RUNNING")
echo "Supervisor Status: $SUPERVISOR_STATUS"

# 7. HTTP testi
log "HTTP testi yapılıyor..."
for i in {1..10}; do
    if curl -s http://127.0.0.1:5000 > /dev/null; then
        log "✅ Uygulama başarıyla çalışıyor!"
        break
    else
        log "Test $i/10: Bekleniyor..."
        sleep 3
    fi
    
    if [ $i -eq 10 ]; then
        log "⚠️ HTTP yanıt alamadı ama supervisor çalışıyor"
    fi
done

# 8. Final durum
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}    SUPERVISOR DÜZELTİLDİ                      ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

supervisorctl status ayyildiz
echo ""
echo -e "${GREEN}Web Sitesi:${NC} http://69.62.110.158"
echo -e "${GREEN}Loglar:${NC} tail -f /var/log/ayyildiz.log"
echo -e "${GREEN}Hata Logları:${NC} tail -f /var/log/ayyildiz_error.log"
echo ""

# Test sonucu
HTTP_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000 || echo "000")
if [ "$HTTP_TEST" = "200" ]; then
    log "🎉 Site başarıyla çalışıyor: http://69.62.110.158"
else
    log "⚠️ Site henüz yanıt vermiyor (HTTP: $HTTP_TEST)"
    log "Logları kontrol edin: tail -f /var/log/ayyildiz.log"
fi

echo ""
log "Supervisor düzeltmesi tamamlandı!"
EOF

chmod +x deployment/fix-supervisor.sh