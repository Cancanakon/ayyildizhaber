# 🚀 Ayyıldız Haber Ajansı - Sıfırdan VPS Kurulum Rehberi

## 📋 Gereksinimler
- Ubuntu 24.04 VPS server
- Minimum 2GB RAM, 20GB disk
- Root erişimi
- SSH bağlantısı

## 🎯 1. ADIM: VPS Server Hazırlığı

VPS serverınızda terminal açın ve şu komutu çalıştırın:

```bash
wget https://raw.githubusercontent.com/your-repo/ayyildizhaber/main/vps-install.sh
chmod +x vps-install.sh
./vps-install.sh
```

**Alternatif olarak manuel kurulum:**

```bash
# Sistem güncellemesi
apt update && apt upgrade -y

# Gerekli paketler
apt install -y python3 python3-pip python3-venv python3-dev nginx postgresql postgresql-contrib libpq-dev git curl wget unzip supervisor ufw fail2ban certbot python3-certbot-nginx

# PostgreSQL kurulumu
systemctl start postgresql
systemctl enable postgresql

# Veritabanı oluştur
sudo -u postgres psql -c "CREATE USER ayyildizhaber WITH PASSWORD 'ayyildiz2025!';"
sudo -u postgres psql -c "CREATE DATABASE ayyildizhaber OWNER ayyildizhaber;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ayyildizhaber TO ayyildizhaber;"

# Proje klasörü
mkdir -p /var/www/ayyildizajans
cd /var/www/ayyildizajans
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip gunicorn
```

## 🎯 2. ADIM: Proje Dosyalarını Yükleme

**Bilgisayarınızdan** (proje klasöründe):

```bash
# Scriptleri executable yapın
chmod +x deploy-complete.sh

# Tam deployment çalıştırın
./deploy-complete.sh
```

Bu script:
- Tüm proje dosyalarını sunucuya gönderir
- Python paketlerini yükler
- Veritabanı tablolarını oluşturur
- Servisleri başlatır

## 🎯 3. ADIM: Nginx Yapılandırması

Server'da `/etc/nginx/sites-available/ayyildizajans` dosyasını oluşturun:

```nginx
server {
    listen 80;
    server_name 69.62.110.158 ayyildizajans.com www.ayyildizajans.com;

    location /static {
        alias /var/www/ayyildizajans/static;
        expires 30d;
    }

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    client_max_body_size 10M;
}
```

Site'ı aktif edin:
```bash
ln -s /etc/nginx/sites-available/ayyildizajans /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
```

## 🎯 4. ADIM: Gunicorn Servisi

`/etc/systemd/system/gunicorn.service` dosyasını oluşturun:

```ini
[Unit]
Description=Gunicorn instance to serve Ayyıldız Haber
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/ayyildizajans
Environment="PATH=/var/www/ayyildizajans/venv/bin"
Environment="DATABASE_URL=postgresql://ayyildizhaber:ayyildiz2025!@localhost/ayyildizhaber"
Environment="SESSION_SECRET=ayyildiz-super-secret-key-2025"
ExecStart=/var/www/ayyildizajans/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 3 main:app
Restart=always

[Install]
WantedBy=multi-user.target
```

Servisi başlatın:
```bash
systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn
```

## 🎯 5. ADIM: Güvenlik ve Firewall

```bash
# Firewall
ufw enable
ufw allow ssh
ufw allow 'Nginx Full'

# Fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Dosya izinleri
chown -R www-data:www-data /var/www/ayyildizajans
chmod -R 755 /var/www/ayyildizajans
chmod -R 777 /var/www/ayyildizajans/static/uploads
```

## 🎯 6. ADIM: SSL Sertifikası (Opsiyonel)

```bash
certbot --nginx -d ayyildizajans.com -d www.ayyildizajans.com
```

## ✅ Kontrol ve Test

```bash
# Servis durumları
systemctl status nginx
systemctl status gunicorn
systemctl status postgresql

# Site erişimi
curl -I http://localhost:5000
curl -I http://69.62.110.158
```

## 🔗 Erişim Bilgileri

- **Site**: http://69.62.110.158
- **Admin Panel**: http://69.62.110.158/admin
- **Admin Giriş**: admin@gmail.com / admin123

## 🚀 Güncellemeler

Gelecekte proje güncellemeleri için:

```bash
# Hızlı güncelleme
./quick-update.sh

# Tam güncelleme
./update-vps.sh

# Sadece değişen dosyalar
./sync-to-vps.sh
```

## 🆘 Sorun Giderme

### Site açılmıyor
```bash
systemctl status gunicorn
systemctl restart gunicorn
systemctl restart nginx
tail -f /var/log/nginx/error.log
```

### Veritabanı hatası
```bash
sudo -u postgres psql ayyildizhaber
# Veritabanı bağlantısını test et
```

### Dosya yükleme hatası
```bash
chmod -R 777 /var/www/ayyildizajans/static/uploads
chown -R www-data:www-data /var/www/ayyildizajans
```

## 📞 Destek

Kurulum sırasında sorun yaşarsanız:
1. Error log'larını kontrol edin
2. Servis durumlarını kontrol edin
3. Firewall ayarlarını kontrol edin

---

**Kurulum tamamlandıktan sonra siteniz http://69.62.110.158 adresinde çalışmaya başlayacaktır.**