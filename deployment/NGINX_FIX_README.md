# Nginx SSL Configuration Fix

## Problem
```
2025/06/26 09:46:41 [emerg] 10939#10939: no "ssl_certificate" is defined for the "listen ... ssl" directive in /etc/nginx/sites-enabled/ayyildizhaber:9
nginx: configuration file /etc/nginx/nginx.conf test failed
```

## Solution Steps

### Step 1: Emergency Fix (Immediate)
```bash
# Sunucuda bu komutu çalıştırın
sudo bash /opt/ayyildizhaber/deployment/emergency-ssl-fix.sh
```

Bu script:
- Hatalı SSL konfigürasyonunu geçici olarak devre dışı bırakır
- HTTP-only güvenli konfigürasyon uygular
- Nginx'i yeniden başlatır
- Site'yi http://69.62.110.158 ve http://ayyildizajans.com üzerinden erişilebilir yapar

### Step 2: SSL Sertifika Kontrolü
```bash
# SSL sertifikalarının varlığını kontrol edin
ls -la /etc/letsencrypt/live/ayyildizajans.com/
```

### Step 3: SSL Konfigürasyonu (Sertifikalar Varsa)
```bash
# Eğer sertifikalar mevcutsa:
sudo cp /opt/ayyildizhaber/deployment/nginx-ssl.conf /etc/nginx/sites-available/ayyildizhaber
sudo ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 4: Yeni SSL Sertifikası (Sertifikalar Yoksa)
```bash
# SSL sertifikası oluşturmak için:
sudo bash /opt/ayyildizhaber/deployment/ssl-setup.sh
```

## Files Created
- `nginx-fix.conf` - SSL olmadan güvenli HTTP konfigürasyonu
- `nginx-test-fix.sh` - Test ve uygulama scripti
- `emergency-ssl-fix.sh` - Acil durum düzeltme scripti

## Current Status
Site şu anda HTTP üzerinden çalışacak:
- http://69.62.110.158
- http://ayyildizajans.com

SSL sertifikaları eklendikten sonra HTTPS aktif edilebilir.

## Test Commands
```bash
# Nginx durumu
sudo systemctl status nginx

# Konfigürasyon testi
sudo nginx -t

# Site erişimi
curl -I http://69.62.110.158
curl -I http://ayyildizajans.com
```