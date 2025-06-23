# Ayyıldız Haber Ajansı - Ubuntu 22.04 VPS Kurulum Rehberi

Bu rehber, Ayyıldız Haber Ajansı web uygulamasını Ubuntu 22.04 VPS sunucusunda production ortamında nasıl kuracağınızı detaylı olarak açıklar.

## 🚀 Hızlı Kurulum

### Ön Gereksinimler
- Ubuntu 22.04 LTS VPS
- En az 2GB RAM
- En az 20GB disk alanı
- Root erişimi
- Domain adı (opsiyonel ama önerilen)

### 1. Tek Komutla Kurulum

```bash
# 1. Projeyi sunucuya indirin
git clone https://github.com/yourusername/ayyildizhaber.git /var/www/ayyildizhaber
cd /var/www/ayyildizhaber

# 2. Kurulum scriptini çalıştırın
sudo chmod +x deployment/install.sh
sudo bash deployment/install.sh
```

## 📋 Manuel Kurulum Adımları

### 1. Sistem Güncellemesi
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Gerekli Paketlerin Kurulumu
```bash
sudo apt install -y python3 python3-pip python3-venv python3-dev \
    postgresql postgresql-contrib nginx git curl wget \
    supervisor fail2ban ufw certbot python3-certbot-nginx \
    build-essential libpq-dev libxml2-dev libxslt1-dev
```

### 3. PostgreSQL Veritabanı Kurulumu
```bash
# PostgreSQL başlat
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Veritabanı oluştur
sudo -u postgres psql << EOF
CREATE USER ayyildizhaber_user WITH PASSWORD 'SecurePassword123!';
CREATE DATABASE ayyildizhaber OWNER ayyildizhaber_user;
GRANT ALL PRIVILEGES ON DATABASE ayyildizhaber TO ayyildizhaber_user;
\q
EOF
```

### 4. Uygulama Kurulumu
```bash
# Dizinleri oluştur
sudo mkdir -p /var/www/ayyildizhaber
sudo mkdir -p /var/log/ayyildizhaber
sudo mkdir -p /var/run/ayyildizhaber

# Python sanal ortamı
cd /var/www/ayyildizhaber
sudo python3 -m venv venv
sudo chown -R www-data:www-data /var/www/ayyildizhaber

# Sanal ortamı aktifleştir ve paketleri yükle
sudo -u www-data -H bash -c '
source venv/bin/activate
pip install --upgrade pip
pip install -r deployment/requirements.txt
'
```

### 5. Environment Konfigürasyonu
```bash
sudo tee /var/www/ayyildizhaber/.env << EOF
DATABASE_URL=postgresql://ayyildizhaber_user:SecurePassword123!@localhost/ayyildizhaber
FLASK_ENV=production
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
SESSION_SECRET=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
EOF

sudo chmod 600 /var/www/ayyildizhaber/.env
sudo chown www-data:www-data /var/www/ayyildizhaber/.env
```

### 6. Systemd Service Kurulumu
```bash
sudo cp deployment/ayyildizhaber.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ayyildizhaber.service
sudo systemctl start ayyildizhaber.service
```

### 7. Nginx Konfigürasyonu
```bash
sudo cp deployment/nginx.conf /etc/nginx/sites-available/ayyildizhaber
sudo ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

### 8. Firewall Konfigürasyonu
```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
```

### 9. SSL Sertifikası (Let's Encrypt)
```bash
sudo certbot --nginx -d ayyildizajans.com -d www.ayyildizajans.com
```

## 🔧 Yapılandırma

### Veritabanı Migration
```bash
cd /var/www/ayyildizhaber
sudo -u www-data -H bash -c '
source venv/bin/activate
python3 -c "from app import app, db; app.app_context().push(); db.create_all()"
'
```

### Admin Kullanıcısı Oluşturma
```bash
cd /var/www/ayyildizhaber
sudo -u www-data -H bash -c '
source venv/bin/activate
python3 -c "
from app import app, db
from models import Admin
with app.app_context():
    admin = Admin(username='admin', email='admin@ayyildizajans.com')
    admin.set_password('YeniGüçlüŞifre123!')
    admin.is_super_admin = True
    db.session.add(admin)
    db.session.commit()
    print('Admin kullanıcısı oluşturuldu')
"
'
```

## 📊 Monitoring ve Bakım

### Log Dosyalarını İzleme
```bash
# Uygulama logları
sudo tail -f /var/log/ayyildizhaber/error.log

# Nginx logları
sudo tail -f /var/log/nginx/error.log

# Sistem logları
sudo journalctl -u ayyildizhaber.service -f
```

### Servis Komutları
```bash
# Servisi yeniden başlat
sudo systemctl restart ayyildizhaber.service

# Servis durumunu kontrol et
sudo systemctl status ayyildizhaber.service

# Nginx yeniden yükle
sudo systemctl reload nginx
```

### Backup ve Restoration
```bash
# Manuel backup
sudo bash /var/www/ayyildizhaber/deployment/backup.sh

# Otomatik backup (cron)
echo "0 2 * * * /var/www/ayyildizhaber/deployment/backup.sh" | sudo crontab -

# Veritabanını restore et
sudo -u postgres psql ayyildizhaber < backup_file.sql
```

## 🔒 Güvenlik

### Fail2Ban Konfigürasyonu
```bash
sudo tee /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true

[nginx-http-auth]
enabled = true
logpath = /var/log/nginx/error.log
EOF

sudo systemctl restart fail2ban
```

### Firewall Kuralları
```bash
# Sadece gerekli portları aç
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw deny 5000/tcp   # Flask development port (production'da kapalı)
```

## 🚨 Sorun Giderme

### Yaygın Problemler

#### 1. Servis Başlamıyor
```bash
# Log kontrol et
sudo journalctl -u ayyildizhaber.service

# Manuel başlatma dene
cd /var/www/ayyildizhaber
sudo -u www-data -H bash -c 'source venv/bin/activate && python3 main.py'
```

#### 2. Veritabanı Bağlantı Hatası
```bash
# PostgreSQL durumunu kontrol et
sudo systemctl status postgresql

# Bağlantıyı test et
sudo -u postgres psql -c "SELECT version();"
```

#### 3. Static Files Yüklenmiyor
```bash
# Nginx konfigürasyonunu test et
sudo nginx -t

# Dosya izinlerini kontrol et
ls -la /var/www/ayyildizhaber/static/
```

### Performance Optimizasyonu

#### 1. Gunicorn Worker Sayısını Ayarlama
```bash
# CPU core sayısına göre ayarlayın (workers = 2 × CPU cores + 1)
sudo nano /var/www/ayyildizhaber/deployment/gunicorn.conf.py
```

#### 2. PostgreSQL Optimizasyonu
```bash
sudo nano /etc/postgresql/14/main/postgresql.conf

# Önerilen ayarlar:
# shared_buffers = 256MB
# effective_cache_size = 1GB
# work_mem = 4MB
```

#### 3. Nginx Cache
```bash
# Static files için cache header'ları zaten nginx.conf'ta mevcut
# Ek cache ayarları ekleyebilirsiniz
```

## 📞 Destek

### Log Toplama
```bash
# Sistem bilgilerini topla
sudo bash -c '
echo "=== Sistem Bilgileri ===" > /tmp/debug.log
uname -a >> /tmp/debug.log
df -h >> /tmp/debug.log
free -h >> /tmp/debug.log
systemctl status ayyildizhaber.service >> /tmp/debug.log
tail -50 /var/log/ayyildizhaber/error.log >> /tmp/debug.log
'
```

### Günlük Kontroller
```bash
# Disk kullanımı
df -h

# Memory kullanımı
free -h

# Aktif bağlantılar
ss -tuln | grep :5000

# Process durumu
ps aux | grep gunicorn
```

Bu rehber ile Ayyıldız Haber Ajansı'nı production ortamında güvenli ve performanslı şekilde çalıştırabilirsiniz.