# Ayyıldız Haber Ajansı - Tek Komut Kurulum Rehberi

## 🚀 Hızlı Kurulum

### Ön Hazırlık
1. VPS'nizi sıfırlayın (Ubuntu 24.04 önerili)
2. Root erişimi sağlayın
3. Proje dosyalarını hazırlayın

### Adım 1: Proje Dosyalarını VPS'e Yükleyin

```bash
# Local bilgisayarınızdan VPS'e dosya gönderme
scp -r * root@VPS_IP:/opt/ayyildizhaber/
```

### Adım 2: Tek Komut Kurulum

VPS'nizde:

```bash
cd /opt/ayyildizhaber/deployment
chmod +x single-command-install.sh
sudo ./single-command-install.sh
```

## ✅ Kurulum Sonucu

Başarılı kurulum sonrası:

- **Ana Site**: `http://VPS_IP`
- **Admin Panel**: `http://VPS_IP/admin`
- **Varsayılan Admin**: `admin@gmail.com` / `admin123`
- **Veritabanı Şifresi**: `ayyildiz123`

## 🔧 Kurulum Detayları

Script otomatik olarak şunları yapar:

1. **Sistem Güncellemesi**: Ubuntu paketlerini günceller
2. **Gerekli Paketler**: Python, PostgreSQL, Nginx kurulumu
3. **Güvenlik**: UFW firewall yapılandırması
4. **Veritabanı**: PostgreSQL kullanıcı ve database oluşturma
5. **Python Ortamı**: Virtual environment ve paket kurulumu
6. **Nginx**: HTTP-only reverse proxy yapılandırması
7. **Systemd**: Otomatik başlatma servisi
8. **Test**: Bağlantı ve port kontrolleri

## 🛠️ Servis Yönetimi

```bash
# Servisi yönetme
sudo systemctl start ayyildizhaber
sudo systemctl stop ayyildizhaber
sudo systemctl restart ayyildizhaber
sudo systemctl status ayyildizhaber

# Logları görüntüleme
sudo journalctl -u ayyildizhaber -f
sudo tail -f /var/log/nginx/error.log
```

## 🔒 SSL Sertifikası Ekleme (İsteğe Bağlı)

Site HTTP olarak çalışır. SSL eklemek için:

```bash
# 1. Domain DNS'ini VPS IP'sine yönlendirin
# 2. SSL sertifikası oluşturun
sudo certbot --nginx -d yourdomain.com

# 3. Otomatik yenileme
sudo crontab -e
# Şu satırı ekleyin:
# 0 12 * * * /usr/bin/certbot renew --quiet
```

## 🔍 Sorun Giderme

### Site Açılmıyor
```bash
# Servis durumunu kontrol et
sudo systemctl status ayyildizhaber
sudo systemctl status nginx

# Portları kontrol et
sudo netstat -tuln | grep :80
sudo netstat -tuln | grep :5000

# Yeniden başlat
sudo systemctl restart ayyildizhaber nginx
```

### Veritabanı Hatası
```bash
# PostgreSQL durumu
sudo systemctl status postgresql

# Veritabanı bağlantısı test
sudo -u postgres psql -c "\l" | grep ayyildizhaber
```

## 📁 Önemli Dosyalar

- `/opt/ayyildizhaber/` - Ana uygulama dizini
- `/etc/systemd/system/ayyildizhaber.service` - Systemd servisi
- `/etc/nginx/sites-available/ayyildizhaber` - Nginx konfigürasyonu
- `/opt/ayyildizhaber/.env` - Çevre değişkenleri

## 🎯 Özellikler

- ✅ TRT Haber otomatik çekme
- ✅ Admin panel
- ✅ Kullanıcı takibi
- ✅ Reklam sistemi
- ✅ Döviz/altın/kripto fiyatları
- ✅ Hava durumu
- ✅ Namaz vakitleri
- ✅ YouTube canlı yayın
- ✅ Kişiselleştirilmiş haber önerileri

## 💡 İpuçları

- Script çalışan sistemden öğrenilmiştir
- HTTP-only olarak güvenli çalışır
- SSL sonradan kolayca eklenebilir
- Otomatik yeniden başlatma özelliği vardır
- Log dosyaları sürekli izlenebilir