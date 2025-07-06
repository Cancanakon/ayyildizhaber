#!/bin/bash

# Ayyıldız Haber Ajansı - Hızlı Kurulum Script'i
# Ubuntu 24.04 için basitleştirilmiş kurulum

# Kullanım: ./quick-install.sh GITHUB_USER GITHUB_TOKEN
# Örnek: ./quick-install.sh johndoe ghp_1234567890abcdef

set -e

if [ $# -ne 2 ]; then
    echo "Kullanım: $0 GITHUB_USER GITHUB_TOKEN"
    echo "Örnek: $0 johndoe ghp_1234567890abcdef"
    echo ""
    echo "GitHub Token almak için:"
    echo "1. GitHub.com → Settings → Developer settings → Personal access tokens"
    echo "2. 'Generate new token (classic)' tıklayın"
    echo "3. 'repo' permission'unu seçin"
    exit 1
fi

GITHUB_USER="$1"
GITHUB_TOKEN="$2"
GITHUB_REPO="ayyildizhaber"
PROJECT_DIR="/var/www/ayyildizhaber"

echo "🚀 Ayyıldız Haber Ajansı Hızlı Kurulum Başlıyor..."
echo "📱 API sistemi dahil - mobil uygulama hazır"
echo "⏱️  Tahmini süre: 15 dakika"
echo ""

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    echo "❌ Bu script root olarak çalıştırılmalıdır"
    echo "Çalıştırın: sudo $0 $1 $2"
    exit 1
fi

# GitHub repository test
echo "🔍 GitHub repository test ediliyor..."
if ! curl -s -f -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO" > /dev/null; then
    echo "❌ GitHub repository erişimi başarısız!"
    echo "Kontrol edin:"
    echo "  - Repository adı: $GITHUB_USER/$GITHUB_REPO"
    echo "  - Token geçerli mi?"
    echo "  - Repository private ise token'da 'repo' permission var mı?"
    exit 1
fi
echo "✅ GitHub repository erişimi başarılı"

# Sistem güncellemesi
echo "📦 Sistem paketleri güncelleniyor..."
apt update -qq && apt upgrade -y -qq

# Gerekli paketleri yükle
echo "🔧 Gerekli paketler yükleniyor..."
apt install -y -qq \
    python3 python3-pip python3-venv \
    postgresql postgresql-contrib \
    nginx supervisor \
    git curl wget unzip

# PostgreSQL kurulumu
echo "🗄️  PostgreSQL yapılandırılıyor..."
systemctl start postgresql
systemctl enable postgresql

# Veritabanı kullanıcısı ve veritabanı oluştur
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS ayyildizhaber;
DROP USER IF EXISTS ayyildizhaber;
CREATE USER ayyildizhaber WITH PASSWORD 'ayyildizhaber2025!';
CREATE DATABASE ayyildizhaber OWNER ayyildizhaber;
GRANT ALL PRIVILEGES ON DATABASE ayyildizhaber TO ayyildizhaber;
\q
EOF

# Projeyi klonla
echo "📥 GitHub'dan kod indiriliyor..."
rm -rf $PROJECT_DIR
mkdir -p /var/www
cd /var/www
git clone "https://$GITHUB_TOKEN@github.com/$GITHUB_USER/$GITHUB_REPO.git"
cd $PROJECT_DIR

# Python sanal ortam
echo "🐍 Python sanal ortamı hazırlanıyor..."
python3 -m venv venv
source venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements.txt

# Ortam değişkenleri ve veritabanı
echo "🔧 Veritabanı başlatılıyor..."
export DATABASE_URL="postgresql://ayyildizhaber:ayyildizhaber2025!@localhost/ayyildizhaber"
export SESSION_SECRET="ayyildizhaber-secret-$(date +%s)"
python3 -c "from app import app, db; app.app_context().push(); db.create_all(); print('✅ Veritabanı tabloları oluşturuldu')"

# Nginx yapılandırması
echo "🌐 Nginx yapılandırılıyor..."
cat > /etc/nginx/sites-available/ayyildizhaber << 'EOF'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
    
    location /static/ {
        alias /var/www/ayyildizhaber/static/;
        expires 30d;
    }
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/javascript;
}
EOF

ln -sf /etc/nginx/sites-available/ayyildizhaber /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Supervisor yapılandırması
echo "⚙️  Supervisor yapılandırılıyor..."
cat > /etc/supervisor/conf.d/ayyildizhaber.conf << EOF
[program:ayyildizhaber]
command=$PROJECT_DIR/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 3 --timeout 300 main:app
directory=$PROJECT_DIR
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/ayyildizhaber.log
environment=DATABASE_URL="postgresql://ayyildizhaber:ayyildizhaber2025!@localhost/ayyildizhaber",SESSION_SECRET="ayyildizhaber-secret-$(date +%s)",FLASK_ENV="production"
EOF

# Dosya izinleri
echo "🔐 Dosya izinleri ayarlanıyor..."
chown -R www-data:www-data $PROJECT_DIR
chmod -R 755 $PROJECT_DIR
mkdir -p $PROJECT_DIR/static/uploads
chown -R www-data:www-data $PROJECT_DIR/static/uploads
chmod -R 775 $PROJECT_DIR/static/uploads

# Log dosyası
touch /var/log/ayyildizhaber.log
chown www-data:www-data /var/log/ayyildizhaber.log

# Servisleri başlat
echo "🚀 Servisler başlatılıyor..."
systemctl reload supervisor
supervisorctl reread
supervisorctl update
supervisorctl start ayyildizhaber

nginx -t
systemctl restart nginx
systemctl enable nginx

# Firewall
echo "🔒 Güvenlik duvarı yapılandırılıyor..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# IP adresini al
SERVER_IP=$(curl -s ifconfig.me || echo "SUNUCU_IP")

echo ""
echo "🎉 KURULUM BAŞARIYLA TAMAMLANDI!"
echo ""
echo "🌐 Website Erişimi:"
echo "   http://$SERVER_IP"
echo ""
echo "🔧 Admin Panel:"
echo "   http://$SERVER_IP/admin"
echo "   Email: admin@gmail.com"
echo "   Şifre: admin123"
echo ""
echo "📱 Mobile API:"
echo "   Base URL: http://$SERVER_IP/api/v1"
echo "   API Key: ayyildizhaber_mobile_2025"
echo ""
echo "🧪 API Test:"
echo "   curl -H \"X-API-Key: ayyildizhaber_mobile_2025\" \"http://$SERVER_IP/api/v1/info\""
echo ""
echo "📊 Sistem Kontrol:"
echo "   supervisorctl status ayyildizhaber"
echo "   tail -f /var/log/ayyildizhaber.log"
echo ""
echo "🔄 Güncelleme için:"
echo "   cd $PROJECT_DIR"
echo "   git pull https://$GITHUB_TOKEN@github.com/$GITHUB_USER/$GITHUB_REPO.git"
echo "   supervisorctl restart ayyildizhaber"
echo ""
echo "✅ Artık mobil uygulama geliştirmeye başlayabilirsiniz!"
echo "📚 API dokümantasyonu: $PROJECT_DIR/API_DOCUMENTATION.md"