# Ayyıldız Haber Ajansı

Türkiye'nin modern dijital haber platformu. TRT Haber entegrasyonu, canlı yayın, reklam sistemi ve kişiselleştirilmiş haber önerileri ile tam özellikli haber sitesi.

## Özellikler

- **Otomatik Haber Çekme**: TRT Haber'den 15 dakikada bir güncel haberler
- **8 Kategori**: Gündem, Ekonomi, Spor, Teknoloji, Sağlık, Kültür-Sanat, Dünya, Politika
- **Canlı Yayın**: YouTube entegrasyonu ile canlı yayın sistemi
- **Reklam Yönetimi**: Sol/sağ sidebar reklamları ve popup reklamlar
- **Kişisel Öneriler**: AI destekli kullanıcı davranış analizi
- **Dış Servisler**: Döviz, hava durumu, namaz vakitleri, kripto para
- **Responsive Tasarım**: Mobil uyumlu modern arayüz
- **Admin Panel**: Tam yönetim sistemi

## VPS Kurulum

### GitHub Token ile Kurulum

VPS'nizde (Ubuntu 24.04):

```bash
# 1. Kurulum scriptini indirin
wget https://raw.githubusercontent.com/yourusername/ayyildizhaber/main/github-token-install.sh
chmod +x github-token-install.sh

# 2. GitHub token ile çalıştırın
./github-token-install.sh GITHUB_TOKEN GITHUB_USER REPO_NAME

# Örnek:
./github-token-install.sh ghp_xxxxxxxxxxxx myusername ayyildizhaber
```

### GitHub Token Nasıl Alınır

1. GitHub.com → Settings → Developer settings
2. Personal access tokens → Tokens (classic)
3. Generate new token → Select repo permissions
4. Token'ı kopyalayın ve yukarıdaki komutta kullanın

### Kurulum Sonrası

- **Ana Site**: http://your-server-ip
- **Admin Panel**: http://your-server-ip/admin
- **Giriş**: admin@gmail.com / admin123

## Sistem Gereksinimleri

- Ubuntu 24.04 LTS
- 2GB+ RAM
- 20GB+ Disk
- Python 3.12+
- PostgreSQL 16+
- Nginx

## Teknoloji Stack

- **Backend**: Python Flask
- **Database**: PostgreSQL
- **Web Server**: Nginx + Gunicorn
- **Task Scheduler**: APScheduler
- **Frontend**: Bootstrap 5 + Vanilla JS
- **Process Manager**: Supervisor

## Güncelleme

```bash
cd /var/www/ayyildizhaber
git pull
supervisorctl restart ayyildizhaber
```

## Lisans

MIT License