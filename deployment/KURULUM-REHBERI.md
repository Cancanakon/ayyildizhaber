# Ayyıldız Haber Ajansı - VPS Kurulum Rehberi

Bu rehber sıfır VPS sunucunuzda Ayyıldız Haber Ajansı'nı GitHub'dan kurmanız için hazırlanmıştır.

## Sistem Gereksinimleri

- **İşletim Sistemi**: Ubuntu 22.04 veya 24.04
- **RAM**: Minimum 2GB (4GB önerilir)
- **Disk**: Minimum 20GB
- **İnternet**: Sürekli internet bağlantısı
- **Erişim**: Root yetkisi

## Hızlı Kurulum (Tek Komut)

### 1. VPS'nizde Terminal Açın

SSH ile sunucunuza bağlanın:
```bash
ssh root@your-server-ip
```

### 2. Kurulum Scriptini İndirin ve Çalıştırın

```bash
# Script'i indirin
wget https://raw.githubusercontent.com/your-username/your-repo/main/deployment/vps-auto-install.sh

# Çalıştırılabilir yapın
chmod +x vps-auto-install.sh

# Kurulumu başlatın
./vps-auto-install.sh
```

### 3. Kurulum Sırasında İstenen Bilgiler

Script aşağıdaki bilgileri soracak:

1. **GitHub Repository URL'i**: 
   - Örnek: `https://github.com/kullanici-adi/ayyildiz-haber.git`

2. **Domain adınız (veya 'ip' yazın)**:
   - Domain varsa: `ayyildizajans.com`
   - Domain yoksa: `ip`

3. **Sunucu IP adresiniz**:
   - Örnek: `192.168.1.100`

4. **SSL için email adresiniz**:
   - Örnek: `admin@ayyildizajans.com`

5. **PostgreSQL veritabanı şifresi**:
   - Güvenli bir şifre girin (örnek: `MySecurePass123!`)

## Kurulum Süreci

Script otomatik olarak şu işlemleri yapacak:

1. ✅ Sistem paketlerini günceller
2. ✅ Python, PostgreSQL, Nginx kurulumu
3. ✅ Güvenlik duvarı yapılandırması
4. ✅ GitHub'dan proje indirme
5. ✅ Python sanal ortamı oluşturma
6. ✅ Gerekli paketleri yükleme
7. ✅ Veritabanı kurulumu
8. ✅ Web sunucusu yapılandırması
9. ✅ SSL sertifikası (domain için)
10. ✅ Servisleri başlatma

## Kurulum Sonrası

### Sitenize Erişim

Kurulum tamamlandıktan sonra:

- **IP ile erişim**: `http://your-server-ip`
- **Domain ile erişim**: `https://your-domain.com`
- **Admin panel**: `/admin`

### Varsayılan Giriş Bilgileri

- **Email**: `admin@gmail.com`
- **Şifre**: `admin123`

**ÖNEMLİ**: İlk girişten sonra şifreyi mutlaka değiştirin!

### Yönetim Komutları

```bash
# Durum kontrolü
ayyildiz-durum

# Uygulamayı yeniden başlat
ayyildiz-restart

# Yedek al
ayyildiz-yedek

# Canlı logları görüntüle
tail -f /var/log/ayyildiz.log

# Hata loglarını görüntüle
tail -f /var/log/ayyildiz_error.log
```

## Manuel Kurulum (Adım Adım)

Otomatik script çalışmazsa manuel kurulum:

### 1. Sistemi Güncelleyin

```bash
apt update && apt upgrade -y
```

### 2. Gerekli Paketleri Kurun

```bash
apt install -y python3 python3-pip python3-venv nginx postgresql \
postgresql-contrib supervisor git curl wget ufw certbot \
python3-certbot-nginx build-essential libpq-dev
```

### 3. Kullanıcı Oluşturun

```bash
useradd -m -s /bin/bash ayyildiz
usermod -aG sudo ayyildiz
echo "ayyildiz ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ayyildiz
```

### 4. Projeyi İndirin

```bash
cd /var/www
git clone YOUR-GITHUB-URL ayyildiz
chown -R ayyildiz:ayyildiz /var/www/ayyildiz
```

### 5. Python Ortamını Kurun

```bash
cd /var/www/ayyildiz
sudo -u ayyildiz python3 -m venv venv
sudo -u ayyildiz ./venv/bin/pip install --upgrade pip
sudo -u ayyildiz ./venv/bin/pip install -r requirements.txt
```

### 6. Veritabanını Kurun

```bash
systemctl start postgresql
systemctl enable postgresql
sudo -u postgres createuser ayyildiz
sudo -u postgres createdb ayyildiz_db -O ayyildiz
sudo -u postgres psql -c "ALTER USER ayyildiz PASSWORD 'your-password';"
```

### 7. Environment Dosyası Oluşturun

```bash
cat > /var/www/ayyildiz/.env << EOF
DATABASE_URL=postgresql://ayyildiz:your-password@localhost/ayyildiz_db
SESSION_SECRET=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_APP=main.py
EOF
```

### 8. Servisleri Yapılandırın

Supervisor ve Nginx yapılandırması için otomatik script'teki ayarları kullanın.

## Sorun Giderme

### Yaygın Sorunlar

1. **502 Bad Gateway**:
   ```bash
   ayyildiz-durum
   supervisorctl restart ayyildiz
   ```

2. **SSL Hatası**:
   ```bash
   certbot certificates
   certbot renew --dry-run
   ```

3. **Veritabanı Bağlantı Hatası**:
   ```bash
   systemctl status postgresql
   sudo -u postgres psql -c "SELECT version();"
   ```

4. **Python Paket Hatası**:
   ```bash
   cd /var/www/ayyildiz
   sudo -u ayyildiz ./venv/bin/pip install --upgrade flask
   ```

### Log Dosyaları

- **Uygulama logları**: `/var/log/ayyildiz.log`
- **Hata logları**: `/var/log/ayyildiz_error.log`
- **Nginx logları**: `/var/log/nginx/error.log`
- **Nginx erişim logları**: `/var/log/nginx/access.log`

## Güvenlik Önerileri

1. **Admin şifresini değiştirin**
2. **SSH portunu değiştirin**:
   ```bash
   nano /etc/ssh/sshd_config
   # Port 22 -> Port 2222
   systemctl restart sshd
   ufw allow 2222
   ```

3. **Fail2ban kurun**:
   ```bash
   apt install fail2ban
   systemctl enable fail2ban
   ```

4. **Düzenli yedekleme**:
   ```bash
   # Otomatik yedekleme zaten kurulu (günlük 02:00)
   crontab -l
   ```

## Destek

Kurulum sırasında sorun yaşarsanız:

1. Hata mesajını tam olarak kaydedin
2. Log dosyalarını kontrol edin
3. `ayyildiz-durum` çıktısını inceleyin
4. Gerekirse GitHub repository'de issue açın

## Özellikler

Kurulum sonrası aktif özellikler:

- ✅ Otomatik TRT Haber çekme (15 dakikada bir)
- ✅ Döviz, altın, kripto para verileri
- ✅ Hava durumu bilgileri
- ✅ Namaz vakitleri
- ✅ Reklam yönetim sistemi
- ✅ Kişiselleştirilmiş haber önerileri
- ✅ Canlı YouTube yayını
- ✅ Mobil uyumlu tasarım
- ✅ SEO optimizasyonu
- ✅ Otomatik yedekleme

## Güncelleme

Projeyi güncellemek için:

```bash
cd /var/www/ayyildiz
sudo -u ayyildiz git pull origin main
ayyildiz-restart
```