#!/bin/bash

# Ayyıldız Haber Ajansı - SSL Durumu Kontrol Script
# Bu script SSL sertifikası durumunu detaylı olarak gösterir

DOMAIN="ayyildizajans.com"
WWW_DOMAIN="www.ayyildizajans.com"

echo "=== SSL Sertifikası Durum Raporu ==="
echo "Domain: $DOMAIN"
echo "Tarih: $(date)"
echo ""

# 1. Sertifika dosya varlığı
echo "📁 Sertifika Dosyaları:"
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "✅ Fullchain: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    echo "✅ Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
else
    echo "❌ SSL sertifikası bulunamadı!"
    exit 1
fi

echo ""

# 2. Sertifika detayları
echo "📋 Sertifika Detayları:"
CERT_INFO=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -text 2>/dev/null)
ISSUER=$(echo "$CERT_INFO" | grep "Issuer:" | cut -d: -f2- | xargs)
SUBJECT=$(echo "$CERT_INFO" | grep "Subject:" | cut -d: -f2- | xargs)
VALID_FROM=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -startdate | cut -d= -f2)
VALID_UNTIL=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -enddate | cut -d= -f2)

echo "Sağlayıcı: $ISSUER"
echo "Subject: $SUBJECT"
echo "Geçerlilik Başlangıcı: $VALID_FROM"
echo "Geçerlilik Sonu: $VALID_UNTIL"

# 3. Kalan süre hesaplama
EXPIRY_TIMESTAMP=$(date -d "$VALID_UNTIL" +%s)
CURRENT_TIMESTAMP=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))

echo ""
echo "⏰ Kalan Süre: $DAYS_LEFT gün"

if [ $DAYS_LEFT -lt 7 ]; then
    echo "🔴 UYARI: Sertifika 7 günden az süre sonra sona eriyor!"
elif [ $DAYS_LEFT -lt 30 ]; then
    echo "🟡 DİKKAT: Sertifika 30 günden az süre sonra sona eriyor"
else
    echo "✅ Sertifika geçerli"
fi

echo ""

# 4. SAN (Subject Alternative Names)
echo "🌐 Kapsanan Domainler:"
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -text | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^[[:space:]]*//' | tr ',' '\n' | sed 's/DNS://g' | sed 's/^[[:space:]]*/  ✅ /'

echo ""

# 5. HTTPS erişim testi
echo "🔍 HTTPS Erişim Testi:"
for domain in $DOMAIN $WWW_DOMAIN; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 https://$domain/ 2>/dev/null || echo "000")
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "  ✅ https://$domain - Erişilebilir (HTTP $HTTP_STATUS)"
    else
        echo "  ❌ https://$domain - Erişilemiyor (HTTP $HTTP_STATUS)"
    fi
done

echo ""

# 6. SSL Labs Grade (varsa)
echo "🏆 SSL Labs Grade:"
if command -v jq >/dev/null 2>&1; then
    GRADE=$(curl -s "https://api.ssllabs.com/api/v3/analyze?host=$DOMAIN" | jq -r '.endpoints[0].grade' 2>/dev/null || echo "unknown")
    if [ "$GRADE" != "null" ] && [ "$GRADE" != "unknown" ]; then
        echo "  Grade: $GRADE"
    else
        echo "  Test sonucu henüz hazır değil. Manuel test: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
    fi
else
    echo "  jq kurulu değil. Manuel test: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
fi

echo ""

# 7. Nginx SSL konfigürasyon kontrol
echo "⚙️ Nginx SSL Konfigürasyonu:"
if nginx -t 2>/dev/null; then
    echo "  ✅ Nginx konfigürasyonu geçerli"
else
    echo "  ❌ Nginx konfigürasyonu hatalı!"
fi

# SSL protokol kontrol
if grep -q "ssl_protocols" /etc/nginx/sites-enabled/ayyildizhaber; then
    SSL_PROTOCOLS=$(grep "ssl_protocols" /etc/nginx/sites-enabled/ayyildizhaber | head -1 | cut -d';' -f1 | sed 's/.*ssl_protocols //')
    echo "  SSL Protokolleri: $SSL_PROTOCOLS"
else
    echo "  ⚠️ SSL protokol ayarı bulunamadı"
fi

echo ""

# 8. Certbot otomatik yenileme
echo "🔄 Otomatik Yenileme:"
if crontab -l 2>/dev/null | grep -q certbot; then
    echo "  ✅ Cron job aktif"
    echo "  Zamanlama: $(crontab -l 2>/dev/null | grep certbot | head -1)"
else
    echo "  ❌ Otomatik yenileme cron job bulunamadı!"
fi

# Dry run test
echo "  Test yenileme çalıştırılıyor..."
if certbot renew --dry-run --quiet 2>/dev/null; then
    echo "  ✅ Yenileme testi başarılı"
else
    echo "  ❌ Yenileme testi başarısız!"
fi

echo ""

# 9. Log dosyaları
echo "📄 Log Dosyaları:"
if [ -f "/var/log/letsencrypt/letsencrypt.log" ]; then
    LAST_RENEWAL=$(grep -i "Successfully received certificate" /var/log/letsencrypt/letsencrypt.log | tail -1 | cut -d' ' -f1-2)
    echo "  Son yenileme: $LAST_RENEWAL"
    echo "  Certbot log: /var/log/letsencrypt/letsencrypt.log"
else
    echo "  ⚠️ Certbot log dosyası bulunamadı"
fi

if [ -f "/var/log/ayyildizhaber/ssl.log" ]; then
    echo "  SSL kontrol log: /var/log/ayyildizhaber/ssl.log"
fi

echo ""
echo "=== Rapor Sonu ==="