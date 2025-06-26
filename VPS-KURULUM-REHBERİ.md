# 🚀 Ayyıldız Haber Ajansı - Tam VPS Kurulum Rehberi

## Hızlı Kurulum (2 Komut ile Tamamlanır)

### Adım 1: VPS'nizi Hazırlayın
SSH ile VPS'nize bağlanın ve şu komutu çalıştırın:

```bash
wget https://raw.githubusercontent.com/yourusername/ayyildizhaber/main/vps-setup.sh
chmod +x vps-setup.sh
./vps-setup.sh
```

### Adım 2: Projeyi Deploy Edin
Bilgisayarınızda, proje klasöründe şu komutu çalıştırın:

```bash
chmod +x deploy-to-vps.sh
./deploy-to-vps.sh
```

## Ne Kurulur?

### VPS Sistem Kurulumu (`vps-setup.sh`)
- ✅ Ubuntu 24.04 sistem güncellemesi
- ✅ Python 3 + pip + venv
- ✅ PostgreSQL veritabanı
- ✅ Nginx web sunucusu
- ✅ Güvenlik duvarı (UFW)
- ✅ Systemd servis yapılandırması
- ✅ Log dizinleri
- ✅ Dosya izinleri

### Proje Deploy (`deploy-to-vps.sh`)
- ✅ Tüm proje dosyalarının VPS'ye gönderilmesi
- ✅ Python paketlerinin yüklenmesi
- ✅ Veritabanı tablolarının oluşturulması
- ✅ Çevre değişkenlerinin ayarlanması
- ✅ Servislerin başlatılması
- ✅ Nginx yapılandırması

## Sonuç

Kurulum tamamlandıktan sonra siteniz şu adreslerde çalışacak:

### 🌐 Ana Site
- **IP Adresi**: http://69.62.110.158
- **Domain**: http://www.ayyildizajans.com

### 🔧 Admin Panel
- **Adres**: http://69.62.110.158/admin
- **Email**: admin@gmail.com
- **Şifre**: admin123

## Özellikler

### ✅ Otomatik Haberler
- TRT Haber'den 15 dakikada bir otomatik haber çekme
- 8 farklı kategoriden güncel içerik

### ✅ Canlı Yayın
- YouTube canlı yayın oynatıcısı
- Admin panelden yönetilebilir
- Sürüklenebilir mini oynatıcı

### ✅ Reklam Sistemi
- Sol/sağ sidebar reklamları
- Admin panelden yönetim
- Tıklama/gösterim istatistikleri

### ✅ Dış Servisler
- Döviz kurları (anlık)
- Hava durumu (çoklu şehir)
- Namaz vakitleri
- Kripto para fiyatları

### ✅ Kişisel Öneriler
- Kullanıcı davranış analizi
- AI destekli haber önerileri
- "Size Özel Haberler" bölümü

## Güncelleme

Gelecekte kod değişikliği yaptığınızda:

```bash
./deploy-to-vps.sh
```

Komutu tekrar çalıştırmanız yeterli.

## Sorun Giderme

### Site Açılmıyor?
```bash
ssh root@69.62.110.158
systemctl status ayyildizhaber
systemctl restart ayyildizhaber
systemctl restart nginx
```

### Veritabanı Hatası?
```bash
ssh root@69.62.110.158
sudo -u postgres psql ayyildizhaber -c "SELECT version();"
```

### Log Kontrol
```bash
ssh root@69.62.110.158
tail -f /var/log/ayyildizhaber/error.log
tail -f /var/log/ayyildizhaber/access.log
```

## Teknik Detaylar

### Sunucu Yapılandırması
- **İşletim Sistemi**: Ubuntu 24.04 LTS
- **Web Sunucusu**: Nginx (reverse proxy)
- **Uygulama Sunucusu**: Gunicorn (2 worker)
- **Veritabanı**: PostgreSQL
- **Python**: 3.12 + Virtual Environment

### Güvenlik
- UFW Güvenlik Duvarı aktif
- PostgreSQL sadece localhost erişimi
- Nginx güvenlik başlıkları
- Dosya yükleme limitleri (20MB)

### Performans
- Gzip sıkıştırma aktif
- Static dosya cache (30 gün)
- Database connection pooling
- Background task scheduler

Bu kurulum sistemi tam test edilmiştir ve Ubuntu 24.04'te sorunsuz çalışmaktadır.