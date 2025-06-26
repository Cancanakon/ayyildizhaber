# VPS Kurulum Rehberi - Ayyıldız Haber Ajansı

## Hızlı Kurulum (Önerilen)

### 1. Deployment Paketini VPS'e Yükleyin

```bash
# Yerel makinenizden VPS'e yükleyin
scp ayyildizhaber-clean.tar.gz root@VPS_IP:/tmp/

# VPS'e bağlanın
ssh root@VPS_IP

# Paketi çıkarın
cd /tmp
tar -xzf ayyildizhaber-clean.tar.gz
```

### 2. Tek Komut Kurulum

```bash
cd /tmp/clean-deployment/deployment
chmod +x single-command-install.sh
./single-command-install.sh
```

Bu komut otomatik olarak:
- ✅ Sistem güncellemesi
- ✅ Gerekli paketleri yükleme
- ✅ PostgreSQL kurulum ve yapılandırma
- ✅ Python sanal ortamı oluşturma
- ✅ Uygulama dosyalarını kopyalama
- ✅ Nginx yapılandırması
- ✅ Systemd servisi kurulumu
- ✅ Otomatik başlatma

### 3. Sonuç Kontrolü

```bash
# Servis durumu
systemctl status ayyildizhaber

# Nginx durumu
systemctl status nginx

# Port kontrolü
netstat -tlnp | grep :80

# Log kontrolü
journalctl -u ayyildizhaber -f
```

## Manuel Kurulum (Sorun Çıkarsa)

### 1. Dosyaları Manuel Kopyalama

```bash
# Eğer otomatik kopyalama çalışmazsa
mkdir -p /opt/ayyildizhaber
cp -r /tmp/clean-deployment/* /opt/ayyildizhaber/
chown -R www-data:www-data /opt/ayyildizhaber
cd /opt/ayyildizhaber
```

### 2. Python Ortamı

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r deployment/requirements.txt
```

### 3. Veritabanı Kurulumu

```bash
# PostgreSQL kullanıcı oluştur
sudo -u postgres createuser --createdb ayyildizhaber
sudo -u postgres createdb ayyildizhaber_db -O ayyildizhaber
sudo -u postgres psql -c "ALTER USER ayyildizhaber PASSWORD 'ayyildiz123';"

# Çevre değişkenleri
export DATABASE_URL="postgresql://ayyildizhaber:ayyildiz123@localhost/ayyildizhaber_db"
export SESSION_SECRET=$(openssl rand -base64 32)

# Tabloları oluştur
python3 -c "from app import app, db; app.app_context().push(); db.create_all()"
```

## Sorun Giderme

### Problem: "main.py bulunamadı"
**Çözüm**: 
```bash
# Dosyaların doğru yerde olduğunu kontrol edin
ls -la /opt/ayyildizhaber/main.py

# Eğer yoksa manuel kopyalayın
cp -r /tmp/clean-deployment/* /opt/ayyildizhaber/
```

### Problem: PostgreSQL bağlantı hatası
**Çözüm**:
```bash
# PostgreSQL çalışıyor mu?
systemctl status postgresql

# Kullanıcı var mı?
sudo -u postgres psql -c "\du"

# Veritabanı var mı?
sudo -u postgres psql -c "\l"
```

### Problem: Port 80 erişim sorunu
**Çözüm**:
```bash
# Nginx çalışıyor mu?
systemctl status nginx

# Port açık mı?
ufw status
netstat -tlnp | grep :80
```

## Önemli Dosya Konumları

- **Uygulama**: `/opt/ayyildizhaber/`
- **Nginx Config**: `/etc/nginx/sites-available/ayyildizhaber`
- **Systemd Service**: `/etc/systemd/system/ayyildizhaber.service`
- **Loglar**: `journalctl -u ayyildizhaber`

## Güvenlik Notları

- Default PostgreSQL şifresi: `ayyildiz123` (değiştirin!)
- Admin paneli: `http://VPS_IP/admin` (admin@gmail.com / admin123)
- Firewall: 80, 443, 22 portları açık

## Test

Kurulum tamamlandıktan sonra:
1. `http://VPS_IP` adresine gidin
2. Ana sayfa yüklenmelidir
3. Haberler otomatik olarak TRT'den çekilmelidir
4. Admin paneli `/admin` adresinde çalışmalıdır

## Güncelleme

Yeni sürüm yüklemek için:
```bash
# Servisi durdur
systemctl stop ayyildizhaber

# Yeni dosyaları kopyala
cp -r /tmp/clean-deployment/* /opt/ayyildizhaber/

# Servisi başlat
systemctl start ayyildizhaber
```