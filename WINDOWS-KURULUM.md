# Windows'tan VPS Kurulum Rehberi

## Seçenek 1: WSL Kullanımı (En Kolay)

Windows'ta WSL (Windows Subsystem for Linux) yükleyin:

```cmd
wsl --install
```

Yeniden başlattıktan sonra:

```bash
# WSL içinde
cd /mnt/c/Users/YourName/path/to/project
./deploy-to-vps.sh
```

## Seçenek 2: Manuel Kurulum

### Adım 1: VPS Hazırlama
SSH ile VPS'nize bağlanın (PuTTY kullanabilirsiniz):

```bash
# VPS'de çalıştırın
cd /var/www/ayyildizhaber
rm -rf *
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install flask flask-sqlalchemy flask-login werkzeug gunicorn psycopg2-binary apscheduler beautifulsoup4 requests trafilatura lxml feedparser python-dateutil email-validator
```

### Adım 2: Dosya Yükleme
1. **Proje Sıkıştırma**: WinRAR/7-Zip ile projeyi `ayyildizhaber.zip` olarak sıkıştırın
2. **Dosya Yükleme**: FileZilla/WinSCP ile `/tmp/ayyildizhaber.zip` olarak yükleyin

### Adım 3: VPS'de Kurulum
```bash
# VPS'de devam
cd /var/www/ayyildizhaber
unzip /tmp/ayyildizhaber.zip
rm /tmp/ayyildizhaber.zip

# Çevre değişkenleri
echo 'DATABASE_URL=postgresql://ayyildizhaber:ayyildizhaber123@localhost/ayyildizhaber' > .env
echo 'SESSION_SECRET=ayyildizhaber-super-secret-key-2025' >> .env
echo 'FLASK_ENV=production' >> .env

# Virtual environment aktif
source venv/bin/activate

# Veritabanı tabloları
export DATABASE_URL=postgresql://ayyildizhaber:ayyildizhaber123@localhost/ayyildizhaber
export SESSION_SECRET=ayyildizhaber-super-secret-key-2025
python3 -c "
import sys
sys.path.insert(0, '/var/www/ayyildizhaber')
from app import app, db
with app.app_context():
    db.create_all()
    print('Veritabanı hazır')
"

# İzinler ve servis
chown -R www-data:www-data /var/www/ayyildizhaber
chmod -R 755 /var/www/ayyildizhaber
mkdir -p static/uploads
chmod -R 775 static/uploads
systemctl restart ayyildizhaber
systemctl restart nginx
```

## Sonuç
- Site: http://69.62.110.158
- Admin: http://69.62.110.158/admin
- Giriş: admin@gmail.com / admin123

## Gerekli Araçlar
- **SSH Client**: PuTTY (https://putty.org)
- **File Transfer**: FileZilla (https://filezilla-project.org) veya WinSCP
- **Alternatif**: WSL yükleyip Linux komutlarını kullanın