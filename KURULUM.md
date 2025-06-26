# Ayyıldız Haber Ajansı - VPS Kurulum Rehberi

## Hızlı Kurulum (2 Adım)

### 1. VPS Hazırlama

VPS'nizde terminal açın ve çalıştırın:

```bash
wget https://raw.githubusercontent.com/your-repo/ayyildizhaber/main/install.sh
chmod +x install.sh
./install.sh
```

Bu script:
- Ubuntu 24.04 sistem güncellemesi
- PostgreSQL + Nginx + Python kurulumu
- Güvenlik ayarları
- Veritabanı oluşturma
- Servis yapılandırması

### 2. Proje Yükleme

Bilgisayarınızda proje klasöründe:

```bash
chmod +x deploy.sh
./deploy.sh
```

Bu script:
- Tüm proje dosyalarını sunucuya gönderir
- Python paketlerini yükler
- Veritabanı tablolarını oluşturur
- Servisleri başlatır

## Sonuç

Kurulum tamamlandıktan sonra:

- **Site**: http://69.62.110.158
- **Domain**: http://www.ayyildizajans.com
- **Admin Panel**: http://69.62.110.158/admin
- **Giriş**: admin@gmail.com / admin123

## Sorun Giderme

### Site açılmıyor
```bash
ssh root@69.62.110.158
systemctl status gunicorn
systemctl status nginx
systemctl restart gunicorn
```

### Veritabanı hatası
```bash
ssh root@69.62.110.158
sudo -u postgres psql ayyildizhaber -c "SELECT version();"
```

### Güncelleme
Gelecekte değişiklik yaptığınızda tekrar `./deploy.sh` çalıştırın.

## Teknik Detaylar

- **OS**: Ubuntu 24.04
- **Web Server**: Nginx
- **App Server**: Gunicorn
- **Database**: PostgreSQL
- **Python**: 3.12 + Virtual Environment
- **Domain**: www.ayyildizajans.com
- **IP**: 69.62.110.158