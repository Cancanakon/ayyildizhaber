# Ayyıldız Haber Ajansı - VPS Kurulum Rehberi
## Ubuntu 24.04 için Kapsamlı Kurulum Kılavuzu

Bu rehber, Ayyıldız Haber Ajansı projesini GitHub'dan Ubuntu 24.04 VPS sunucunuza nasıl kuracağınızı detaylı olarak anlatır.

## 🚀 Sistem Gereksinimleri

- **İşletim Sistemi**: Ubuntu 24.04 LTS
- **RAM**: Minimum 2GB (4GB önerilen)
- **Disk**: Minimum 10GB boş alan
- **Network**: İnternet bağlantısı
- **Port**: 80 ve 443 açık olmalı

## 📋 Ön Hazırlık

### 1. GitHub Repository Hazırlığı

1. GitHub'da yeni bir **private repository** oluşturun:
   ```
   Repository Name: ayyildizhaber
   Description: Ayyıldız Haber Ajansı - Turkish News Website
   Visibility: Private (önerilen)
   ```

2. Bu Replit projesindeki tüm dosyaları GitHub repository'ye yükleyin

3. **GitHub Personal Access Token** oluşturun:
   - GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - "Generate new token (classic)" tıklayın
   - **Permissions**: `repo` (full access) seçin
   - Token'ı güvenli bir yerde saklayın

### 2. VPS Sunucu Hazırlığı

```bash
# Root olarak giriş yapın
sudo su -

# Sistem güncellemesi
apt update && apt upgrade -y

# Temel araçları yükleyin
apt install -y curl wget git
```

## 🔧 Otomatik Kurulum

### Yöntem 1: Tek Komut ile Kurulum (GitHub Token ile)

1. **github-vps-install.sh** dosyasını VPS'e indirin:
```bash
wget https://raw.githubusercontent.com/KULLANICI_ADI/ayyildizhaber/main/github-vps-install.sh
```

2. Script'i düzenleyin:
```bash
nano github-vps-install.sh
```

3. Aşağıdaki satırları kendi bilgilerinizle değiştirin:
```bash
GITHUB_USER="SIZIN_GITHUB_KULLANICI_ADINIZ"
GITHUB_REPO="ayyildizhaber"
GITHUB_TOKEN="SIZIN_GITHUB_TOKEN_INIZ"
```

4. Kurulumu başlatın:
```bash
chmod +x github-vps-install.sh
./github-vps-install.sh
```

### Yöntem 2: Manuel Adım Adım Kurulum

Eğer otomatik kurulum'da sorun yaşarsanız:

```bash
# 1. Gerekli paketleri yükle
apt install -y python3 python3-pip python3-venv postgresql postgresql-contrib nginx supervisor

# 2. PostgreSQL kullanıcı oluştur
sudo -u postgres createuser --interactive --pwprompt ayyildizhaber
sudo -u postgres createdb --owner=ayyildizhaber ayyildizhaber

# 3. Projeyi klonla
mkdir -p /var/www
cd /var/www
git clone https://GITHUB_TOKEN@github.com/KULLANICI_ADI/ayyildizhaber.git
cd ayyildizhaber

# 4. Python sanal ortam
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 5. Veritabanı yapılandır
export DATABASE_URL="postgresql://ayyildizhaber:SIFRE@localhost/ayyildizhaber"
export SESSION_SECRET="gizli-anahtar-$(date +%s)"
python3 -c "from app import app, db; app.app_context().push(); db.create_all()"

# 6. Nginx yapılandır
# github-vps-install.sh'teki nginx config'i kopyalayın

# 7. Supervisor yapılandır
# github-vps-install.sh'teki supervisor config'i kopyalayın

# 8. Servisleri başlat
systemctl restart nginx
supervisorctl restart ayyildizhaber
```

## 🔑 Kurulum Sonrası Erişim Bilgileri

### Website
- **Ana Sayfa**: `http://SUNUCU_IP`
- **Domain**: `http://www.ayyildizajans.com` (DNS ayarlandıysa)

### Admin Panel
- **URL**: `http://SUNUCU_IP/admin`
- **Email**: `admin@gmail.com`
- **Şifre**: `admin123`

### API Erişimi
- **Base URL**: `http://SUNUCU_IP/api/v1`
- **API Key**: `ayyildizhaber_mobile_2025`
- **Header**: `X-API-Key: ayyildizhaber_mobile_2025`

## 📱 API Test Komutları

Kurulumdan sonra API'yi test etmek için:

```bash
# API bilgisi
curl -H "X-API-Key: ayyildizhaber_mobile_2025" "http://SUNUCU_IP/api/v1/info"

# Haberler (ilk 5)
curl -H "X-API-Key: ayyildizhaber_mobile_2025" "http://SUNUCU_IP/api/v1/news?per_page=5"

# Kategoriler
curl -H "X-API-Key: ayyildizhaber_mobile_2025" "http://SUNUCU_IP/api/v1/categories"

# Homepage data
curl -H "X-API-Key: ayyildizhaber_mobile_2025" "http://SUNUCU_IP/api/v1/homepage"

# Döviz widget'ı
curl -H "X-API-Key: ayyildizhaber_mobile_2025" "http://SUNUCU_IP/api/v1/widgets/currency"

# Arama
curl -H "X-API-Key: ayyildizhaber_mobile_2025" "http://SUNUCU_IP/api/v1/search?q=teknoloji"
```

## 🔄 Güncelleme İşlemleri

### GitHub'dan Güncelleme

```bash
# Proje dizinine git
cd /var/www/ayyildizhaber

# Uygulamayı durdur
sudo supervisorctl stop ayyildizhaber

# GitHub'dan güncelle
sudo git pull https://GITHUB_TOKEN@github.com/KULLANICI_ADI/ayyildizhaber.git

# Bağımlılıkları güncelle
sudo -u www-data ./venv/bin/pip install -r requirements.txt --upgrade

# Veritabanını güncelle
sudo -u www-data ./venv/bin/python3 -c "from app import app, db; app.app_context().push(); db.create_all()"

# İzinleri düzelt
sudo chown -R www-data:www-data /var/www/ayyildizhaber

# Uygulamayı başlat
sudo supervisorctl start ayyildizhaber
```

### Otomatik Güncelleme Script

**update-from-github.sh** scriptini kullanarak:

```bash
# Script'i çalıştırabilir yapın
chmod +x /var/www/ayyildizhaber/update-from-github.sh

# Güncellemeyi çalıştırın
sudo /var/www/ayyildizhaber/update-from-github.sh
```

## 🛠️ Sistem Yönetimi

### Log Dosyaları
```bash
# Uygulama logları
tail -f /var/log/ayyildizhaber.log

# Nginx logları
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Supervisor logları
sudo supervisorctl tail -f ayyildizhaber
```

### Servis Kontrolü
```bash
# Uygulama durumu
sudo supervisorctl status ayyildizhaber

# Uygulamayı yeniden başlat
sudo supervisorctl restart ayyildizhaber

# Nginx durumu
sudo systemctl status nginx

# PostgreSQL durumu
sudo systemctl status postgresql
```

### Performans İzleme
```bash
# Sistem kaynakları
htop

# Disk kullanımı
df -h

# RAM kullanımı
free -h

# Network bağlantıları
netstat -tlnp
```

## 🔒 Güvenlik Önerileri

### 1. Firewall Yapılandırması
```bash
# UFW etkinleştir
sudo ufw enable

# SSH erişimi
sudo ufw allow ssh

# Web trafiği
sudo ufw allow 'Nginx Full'

# Gereksiz portları kapat
sudo ufw deny 5432  # PostgreSQL
```

### 2. Admin Şifresini Değiştir
Kurulumdan sonra admin panelinden şifrenizi değiştirin.

### 3. API Key Güvenliği
Production'da API key'i daha güvenli bir değerle değiştirin.

### 4. Database Backup
```bash
# Veritabanı yedekleme script'i
#!/bin/bash
BACKUP_DIR="/var/backups/ayyildizhaber"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
sudo -u postgres pg_dump ayyildizhaber > $BACKUP_DIR/backup_$DATE.sql
gzip $BACKUP_DIR/backup_$DATE.sql

# Eski yedekleri temizle (30 günden eski)
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete
```

## 🌐 Domain Ayarları

### DNS Kayıtları
```
A Record: www.ayyildizajans.com → SUNUCU_IP
A Record: ayyildizajans.com → SUNUCU_IP
```

### SSL Sertifikası (Let's Encrypt)
```bash
# Certbot yükle
sudo apt install certbot python3-certbot-nginx

# SSL sertifikası al
sudo certbot --nginx -d ayyildizajans.com -d www.ayyildizajans.com

# Otomatik yenileme
sudo crontab -e
# Şu satırı ekleyin:
0 12 * * * /usr/bin/certbot renew --quiet
```

## 🐛 Sorun Giderme

### Yaygın Sorunlar

1. **Uygulama başlamıyor**
   ```bash
   sudo supervisorctl tail ayyildizhaber
   # Log'ları kontrol edin
   ```

2. **Veritabanı bağlantı hatası**
   ```bash
   sudo systemctl status postgresql
   sudo -u postgres psql -c "\l"
   ```

3. **Nginx 502 Bad Gateway**
   ```bash
   sudo systemctl status nginx
   curl http://localhost:5000  # Uygulama localhost'ta çalışıyor mu?
   ```

4. **API çalışmıyor**
   ```bash
   curl -H "X-API-Key: ayyildizhaber_mobile_2025" "http://localhost:5000/api/v1/info"
   ```

### Destek

Sorun yaşarsanız:
1. Log dosyalarını kontrol edin
2. Sistem kaynaklarını kontrol edin
3. Github issues'a başvurun

## 📚 Kaynaklar

- **API Dokümantasyonu**: `/var/www/ayyildizhaber/API_DOCUMENTATION.md`
- **Kurulum Script'i**: `github-vps-install.sh`
- **Güncelleme Script'i**: `update-from-github.sh`
- **Project Dosyası**: `replit.md`

---

## 🎯 Kurulum Özeti

1. ✅ Ubuntu 24.04 VPS hazırlayın
2. ✅ GitHub repository oluşturun ve token alın
3. ✅ `github-vps-install.sh` scriptini indirip düzenleyin
4. ✅ Script'i çalıştırın
5. ✅ Admin panel ve API'yi test edin
6. ✅ Domain ve SSL ayarlarını yapın
7. ✅ Mobil uygulama geliştirmeye başlayın

**Kurulum süresi**: 12-18 dakika
**Toplam dosya boyutu**: ~50MB
**Sistem gereksinimleri**: 2GB RAM, 10GB disk

Artık websitesi ve API sistemi hazır! Mobil uygulama geliştirmeye başlayabilirsiniz.