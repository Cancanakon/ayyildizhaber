#!/bin/bash

# Hızlı durum kontrolü ve log görüntüleme

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Ayyıldız Haber Ajansı Durum Raporu ===${NC}"
echo ""

# Supervisor durumu
echo -e "${YELLOW}Supervisor Durumu:${NC}"
supervisorctl status ayyildiz 2>/dev/null || echo "Supervisor yapılandırılmamış"
echo ""

# Nginx durumu
echo -e "${YELLOW}Nginx Durumu:${NC}"
systemctl is-active nginx 2>/dev/null || echo "Nginx durumu belirsiz"
echo ""

# HTTP testi
echo -e "${YELLOW}HTTP Test:${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Site çalışıyor (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ Site yanıt vermiyor (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Son loglar
echo -e "${YELLOW}Son Loglar (son 10 satır):${NC}"
if [ -f "/var/log/ayyildiz.log" ]; then
    tail -10 /var/log/ayyildiz.log
else
    echo "Log dosyası bulunamadı"
fi
echo ""

# Hata logları
echo -e "${YELLOW}Hata Logları (son 5 satır):${NC}"
if [ -f "/var/log/ayyildiz_error.log" ]; then
    tail -5 /var/log/ayyildiz_error.log
else
    echo "Hata log dosyası bulunamadı"
fi
echo ""

# Process kontrolü
echo -e "${YELLOW}Python Process:${NC}"
ps aux | grep -E "(python|gunicorn)" | grep -v grep || echo "Python process bulunamadı"
echo ""

echo -e "${GREEN}Durum kontrolü tamamlandı${NC}"
echo "Site: http://69.62.110.158"
EOF

chmod +x deployment/quick-status.sh