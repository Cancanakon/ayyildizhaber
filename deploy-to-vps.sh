#!/bin/bash

# Ayyıldız Haber Ajansı - VPS'ye Deploy Scripti
# Bu scripti bilgisayarınızda çalıştırın

set -e

VPS_IP="69.62.110.158"
VPS_USER="root"
PROJECT_PATH="/var/www/ayyildizhaber"

echo "=== Ayyıldız Haber Ajansı VPS Deploy Başlıyor ==="

# Geçici deploy paketi oluştur
echo "Deploy paketi hazırlanıyor..."
TEMP_DIR=$(mktemp -d)
TAR_FILE="$TEMP_DIR/ayyildizhaber-deploy.tar.gz"

# Projenin tüm dosyalarını paketle (gereksiz dosyalar hariç)
tar --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='venv' \
    --exclude='cache' \
    --exclude='*.log' \
    --exclude='node_modules' \
    --exclude='.DS_Store' \
    --exclude='attached_assets' \
    --exclude='clean-deployment' \
    --exclude='deployment' \
    --exclude='*.tar.gz' \
    -czf "$TAR_FILE" .

echo "Deploy paketi oluşturuldu: $(du -h $TAR_FILE | cut -f1)"

# VPS'ye dosyaları gönder
echo "Dosyalar VPS'ye gönderiliyor..."
scp "$TAR_FILE" $VPS_USER@$VPS_IP:/tmp/

# VPS'de deploy işlemlerini gerçekleştir
echo "VPS'de deploy işlemleri başlatılıyor..."
ssh $VPS_USER@$VPS_IP << 'ENDSSH'
set -e

echo "Uygulama servisi durduruluyor..."
systemctl stop ayyildizhaber || true

echo "Eski dosyalar temizleniyor..."
rm -rf /var/www/ayyildizhaber/*

echo "Yeni dosyalar çıkarılıyor..."
cd /var/www/ayyildizhaber
tar -xzf /tmp/ayyildizhaber-deploy.tar.gz
rm /tmp/ayyildizhaber-deploy.tar.gz

echo "Python paketleri yükleniyor..."
source venv/bin/activate
pip install --upgrade pip

# VPS için requirements dosyasını kullan
if [ -f requirements-vps.txt ]; then
    pip install -r requirements-vps.txt
else
    pip install flask flask-sqlalchemy flask-login werkzeug gunicorn psycopg2-binary apscheduler beautifulsoup4 requests trafilatura lxml feedparser python-dateutil email-validator
fi

echo "Çevre değişkenleri ayarlanıyor..."
cat > .env << 'EOF'
DATABASE_URL=postgresql://ayyildizhaber:ayyildizhaber123@localhost/ayyildizhaber
SESSION_SECRET=ayyildizhaber-super-secret-key-2025
FLASK_ENV=production
PYTHONPATH=/var/www/ayyildizhaber
EOF

echo "Veritabanı tabloları oluşturuluyor..."
export DATABASE_URL=postgresql://ayyildizhaber:ayyildizhaber123@localhost/ayyildizhaber
export SESSION_SECRET=ayyildizhaber-super-secret-key-2025
export FLASK_ENV=production
export PYTHONPATH=/var/www/ayyildizhaber

python3 -c "
import sys
sys.path.insert(0, '/var/www/ayyildizhaber')
from app import app, db
with app.app_context():
    db.create_all()
    print('Veritabanı tabloları oluşturuldu')
"

echo "Dosya izinleri ayarlanıyor..."
chown -R www-data:www-data /var/www/ayyildizhaber
chmod -R 755 /var/www/ayyildizhaber

# Static ve upload klasörlerini oluştur
mkdir -p static/uploads
chown -R www-data:www-data static/uploads
chmod -R 775 static/uploads

echo "Systemd servisi aktifleştiriliyor..."
systemctl daemon-reload
systemctl enable ayyildizhaber
systemctl start ayyildizhaber

echo "Nginx yeniden başlatılıyor..."
systemctl restart nginx

echo "Servis durumu kontrol ediliyor..."
sleep 3
systemctl status ayyildizhaber --no-pager -l

ENDSSH

# Geçici dosyaları temizle
rm -rf "$TEMP_DIR"

echo ""
echo "=== Deploy Tamamlandı ==="
echo ""
echo "🌐 Siteniz artık çalışıyor:"
echo "   http://69.62.110.158"
echo "   http://www.ayyildizajans.com"
echo ""
echo "🔧 Admin Panel:"
echo "   http://69.62.110.158/admin"
echo "   Email: admin@gmail.com"
echo "   Şifre: admin123"
echo ""
echo "📊 Log kontrol:"
echo "   ssh root@69.62.110.158"
echo "   systemctl status ayyildizhaber"
echo "   tail -f /var/log/ayyildizhaber/error.log"
echo ""
echo "🔄 Güncelleme için bu scripti tekrar çalıştırabilirsiniz"