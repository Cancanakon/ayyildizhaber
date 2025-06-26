# Ayyıldız Haber Ajansı - Kusursuz Kurulum Rehberi

## Özellikler
- Tüm yaşanan hatalardan öğrenilerek hazırlanmıştır
- SSL problemlerini tamamen çözer
- 502 Bad Gateway hatalarını önler
- Gunicorn kurulum sorunlarını çözer
- PostgreSQL yapılandırmasını otomatik halleder
- Güvenlik yapılandırması dahil

## Tek Komut Kurulum

```bash
# 1. Dosyaları sunucuya yükleyin
scp -r deployment/ root@YOUR_SERVER_IP:/tmp/

# 2. Sunucuda kurulumu başlatın
ssh root@YOUR_SERVER_IP
cd /tmp/deployment
chmod +x perfect-install.sh
./perfect-install.sh
```

## Manuel Kurulum

### Ön Gereksinimler
- Ubuntu 24.04 LTS
- Root erişimi
- En az 2GB RAM
- En az 20GB disk alanı

### Adım Adım Kurulum

```bash
# 1. Dosyaları indirin
wget https://github.com/your-repo/ayyildizhaber/archive/main.zip
unzip main.zip
cd ayyildizhaber-main/deployment

# 2. Kurulum scriptini çalıştırın
sudo chmod +x perfect-install.sh
sudo ./perfect-install.sh
```

## Kurulum Sonrası

### Site Erişimi
- Ana Site: http://YOUR_SERVER_IP
- Admin Panel: http://YOUR_SERVER_IP/admin
- Varsayılan admin: admin@gmail.com / admin123

### SSL Sertifikası Ekleme

```bash
# 1. Domain DNS'ini sunucu IP'sine yönlendirin
# 2. SSL sertifikası oluşturun
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# 3. Otomatik yenileme aktifleştirin
sudo crontab -e
# Şu satırı ekleyin:
# 0 12 * * * /usr/bin/certbot renew --quiet
```

## Servis Yönetimi

```bash
# Servisi başlat/durdur/yeniden başlat
sudo systemctl start ayyildizhaber
sudo systemctl stop ayyildizhaber
sudo systemctl restart ayyildizhaber

# Servis durumunu kontrol et
sudo systemctl status ayyildizhaber

# Logları görüntüle
sudo journalctl -u ayyildizhaber -f
```

## Sorun Giderme

### 502 Bad Gateway
```bash
# Flask uygulaması çalışıyor mu?
sudo systemctl status ayyildizhaber

# Port dinleniyor mu?
sudo netstat -tuln | grep :5000

# Yeniden başlat
sudo systemctl restart ayyildizhaber
```

### SSL Hatası
```bash
# Nginx konfigürasyonunu test et
sudo nginx -t

# SSL sertifikasını kontrol et
sudo certbot certificates

# Nginx'i yeniden yükle
sudo systemctl reload nginx
```

### Veritabanı Bağlantısı
```bash
# PostgreSQL çalışıyor mu?
sudo systemctl status postgresql

# Veritabanına bağlan
sudo -u postgres psql ayyildizhaber_db

# Bağlantıyı test et
sudo -u postgres psql -c "\l" | grep ayyildizhaber
```

## Log Dosyaları

```bash
# Uygulama logları
sudo journalctl -u ayyildizhaber -f

# Nginx logları
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# PostgreSQL logları
sudo tail -f /var/log/postgresql/postgresql-*.log
```

## Güvenlik

Kurulum otomatik olarak şunları yapılandırır:
- UFW firewall (22, 80, 443 portları açık)
- Nginx güvenlik başlıkları
- PostgreSQL yerel erişim
- SSL sertifikası hazır altyapısı

## Önemli Dosyalar

```bash
/opt/ayyildizhaber/           # Ana uygulama dizini
/etc/systemd/system/ayyildizhaber.service  # Systemd servisi
/etc/nginx/sites-available/ayyildizhaber   # Nginx konfigürasyonu
/opt/ayyildizhaber/.env       # Çevre değişkenleri
```

## Yedekleme

```bash
# Veritabanı yedeği
sudo -u postgres pg_dump ayyildizhaber_db > backup.sql

# Dosya yedeği
sudo tar -czf ayyildizhaber-backup.tar.gz /opt/ayyildizhaber/

# Nginx konfigürasyonu yedeği
sudo cp /etc/nginx/sites-available/ayyildizhaber nginx-backup.conf
```

## Destek

Sorun yaşarsanız:
1. Log dosyalarını kontrol edin
2. Servis durumlarını kontrol edin
3. Port durumlarını kontrol edin
4. Güvenlik duvarı ayarlarını kontrol edin