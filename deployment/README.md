# Ayyıldız Haber Ajansı - VPS Deployment Guide

Bu rehber Ubuntu 24.04 VPS sunucunuzda Ayyıldız Haber Ajansı'nı kurmanız için hazırlanmıştır.

## Hızlı Kurulum (Önerilen)

```bash
# 1. Dosyaları sunucunuza yükleyin
scp -r . user@your-server-ip:/home/user/ayyildiz/

# 2. Sunucuda deployment klasörüne gidin
cd /home/user/ayyildiz/deployment

# 3. Tek komutla kurulum yapın
chmod +x quick-install.sh
./quick-install.sh
```

## Manuel Kurulum

```bash
cd deployment
chmod +x ubuntu24-deploy.sh
./ubuntu24-deploy.sh
```

## Kurulum Sırasında İstenen Bilgiler

1. **Domain adı**: Domain'iniz (örn: ayyildizajans.com) veya 'ip' yazın
2. **Sunucu IP adresi**: VPS'inizin IP adresi
3. **Email adresi**: SSL sertifikası için
4. **Database şifresi**: PostgreSQL için güvenli bir şifre

## Kurulum Sonrası

### Admin Paneli
- URL: `https://yourdomain.com/admin` veya `http://your-ip/admin`
- Varsayılan giriş: `admin@gmail.com` / `admin123`
- **ÖNEMLİ**: İlk girişten sonra şifreyi değiştirin!

### Yönetim Komutları

```bash
# Durum kontrolü
sudo /usr/local/bin/ayyildiz-status.sh

# Uygulamayı yeniden başlat
sudo supervisorctl restart ayyildiz

# Nginx'i yeniden başlat
sudo systemctl restart nginx

# Logları görüntüle
sudo tail -f /var/log/ayyildiz.log

# Manuel yedekleme
sudo /usr/local/bin/ayyildiz-backup.sh
```

## Özellikler

- ✅ Otomatik SSL sertifikası (Let's Encrypt)
- ✅ PostgreSQL veritabanı
- ✅ Günlük otomatik yedekleme
- ✅ Supervisor ile process yönetimi
- ✅ Nginx reverse proxy
- ✅ Güvenlik başlıkları
- ✅ Firewall konfigürasyonu
- ✅ Hem IP hem domain desteği

## Dosya Konumları

- **Uygulama**: `/var/www/ayyildiz`
- **Nginx config**: `/etc/nginx/sites-available/ayyildiz`
- **Supervisor config**: `/etc/supervisor/conf.d/ayyildiz.conf`
- **Environment**: `/var/www/ayyildiz/.env`
- **Yedekler**: `/var/backups/ayyildiz`
- **Loglar**: `/var/log/ayyildiz.log`

## Sorun Giderme

### Uygulama çalışmıyor
```bash
sudo supervisorctl status ayyildiz
sudo supervisorctl restart ayyildiz
```

### Nginx hatası
```bash
sudo nginx -t
sudo systemctl status nginx
```

### Database bağlantı hatası
```bash
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"
```

### SSL sertifikası problemi
```bash
sudo certbot certificates
sudo certbot renew --dry-run
```

## Güvenlik Notları

1. Varsayılan admin şifresini mutlaka değiştirin
2. SSH port'u değiştirmeyi düşünün
3. Fail2ban kurulumunu yapın
4. Düzenli yedekleme kontrolü yapın

## Destek

Kurulum sırasında sorun yaşarsanız:
1. Hata mesajını tam olarak kaydedin
2. `/var/log/ayyildiz.log` dosyasını kontrol edin
3. `sudo /usr/local/bin/ayyildiz-status.sh` çıktısını inceleyin