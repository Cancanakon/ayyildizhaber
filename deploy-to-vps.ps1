# Ayyıldız Haber Ajansı - Windows PowerShell Deploy Scripti
# Bu scripti Windows PowerShell'de çalıştırın

param(
    [string]$VpsIp = "69.62.110.158",
    [string]$VpsUser = "root",
    [string]$ProjectPath = "/var/www/ayyildizhaber"
)

Write-Host "=== Ayyıldız Haber Ajansı VPS Deploy Başlıyor ===" -ForegroundColor Green

# Geçici dizin oluştur
$TempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
$TarFile = Join-Path $TempDir "ayyildizhaber-deploy.tar.gz"

Write-Host "Deploy paketi hazırlanıyor..." -ForegroundColor Yellow

# Windows'ta tar komutu (Windows 10+ built-in)
try {
    $excludeItems = @(
        "__pycache__",
        "*.pyc",
        ".git",
        "venv",
        "cache",
        "*.log",
        "node_modules",
        ".DS_Store",
        "attached_assets",
        "clean-deployment",
        "deployment",
        "*.tar.gz"
    )
    
    # Exclude parametrelerini hazırla
    $excludeParams = $excludeItems | ForEach-Object { "--exclude=$_" }
    
    # Tar komutu çalıştır
    $tarArgs = @("--exclude=__pycache__", "--exclude=*.pyc", "--exclude=.git", "--exclude=venv", "--exclude=cache", "--exclude=*.log", "--exclude=node_modules", "--exclude=.DS_Store", "--exclude=attached_assets", "--exclude=clean-deployment", "--exclude=deployment", "--exclude=*.tar.gz", "-czf", $TarFile, ".")
    
    & tar @tarArgs
    
    if ($LASTEXITCODE -eq 0) {
        $fileSize = (Get-Item $TarFile).Length / 1MB
        Write-Host "Deploy paketi oluşturuldu: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
    } else {
        throw "Tar komutu başarısız oldu"
    }
} catch {
    Write-Host "HATA: Tar komutu çalışmadı. 7-Zip kullanılıyor..." -ForegroundColor Red
    
    # 7-Zip alternatifi
    $7zipPath = Get-Command "7z" -ErrorAction SilentlyContinue
    if ($7zipPath) {
        & 7z a -tgzip "$TarFile" "." -x!__pycache__ -x!*.pyc -x!.git -x!venv -x!cache -x!*.log -x!node_modules -x!.DS_Store -x!attached_assets -x!clean-deployment -x!deployment -x!*.tar.gz
    } else {
        Write-Host "HATA: Ne tar ne de 7-Zip bulunamadı!" -ForegroundColor Red
        Write-Host "Lütfen Windows 10+ kullanın veya 7-Zip yükleyin" -ForegroundColor Red
        exit 1
    }
}

# SCP ile dosya gönder
Write-Host "Dosyalar VPS'ye gönderiliyor..." -ForegroundColor Yellow
try {
    & scp $TarFile "${VpsUser}@${VpsIp}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP komutu başarısız oldu"
    }
} catch {
    Write-Host "HATA: SCP komutu çalışmadı. PuTTY pscp kullanılıyor..." -ForegroundColor Red
    
    # PuTTY pscp alternatifi
    $pscpPath = Get-Command "pscp" -ErrorAction SilentlyContinue
    if ($pscpPath) {
        & pscp -batch $TarFile "${VpsUser}@${VpsIp}:/tmp/"
    } else {
        Write-Host "HATA: Ne scp ne de pscp bulunamadı!" -ForegroundColor Red
        Write-Host "Lütfen OpenSSH Client veya PuTTY yükleyin" -ForegroundColor Red
        exit 1
    }
}

# SSH ile VPS'de deploy işlemleri
Write-Host "VPS'de deploy işlemleri başlatılıyor..." -ForegroundColor Yellow

$sshScript = @"
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
"@

try {
    # SSH komutu çalıştır
    $sshScript | & ssh "${VpsUser}@${VpsIp}" 'bash -s'
    
    if ($LASTEXITCODE -ne 0) {
        throw "SSH deploy komutu başarısız oldu"
    }
} catch {
    Write-Host "HATA: SSH komutu çalışmadı. PuTTY plink kullanılıyor..." -ForegroundColor Red
    
    # PuTTY plink alternativi
    $plinkPath = Get-Command "plink" -ErrorAction SilentlyContinue
    if ($plinkPath) {
        $sshScript | & plink -batch "${VpsUser}@${VpsIp}" 'bash -s'
    } else {
        Write-Host "HATA: Ne ssh ne de plink bulunamadı!" -ForegroundColor Red
        Write-Host "Lütfen OpenSSH Client veya PuTTY yükleyin" -ForegroundColor Red
        exit 1
    }
}

# Geçici dosyaları temizle
Remove-Item -Path $TempDir -Recurse -Force

Write-Host ""
Write-Host "=== Deploy Tamamlandı ===" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Siteniz artık çalışıyor:" -ForegroundColor Cyan
Write-Host "   http://69.62.110.158" -ForegroundColor White
Write-Host "   http://www.ayyildizajans.com" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Admin Panel:" -ForegroundColor Cyan
Write-Host "   http://69.62.110.158/admin" -ForegroundColor White
Write-Host "   Email: admin@gmail.com" -ForegroundColor White
Write-Host "   Şifre: admin123" -ForegroundColor White
Write-Host ""
Write-Host "📊 Log kontrol:" -ForegroundColor Cyan
Write-Host "   ssh root@69.62.110.158" -ForegroundColor White
Write-Host "   systemctl status ayyildizhaber" -ForegroundColor White
Write-Host "   tail -f /var/log/ayyildizhaber/error.log" -ForegroundColor White
Write-Host ""
Write-Host "🔄 Güncelleme için bu scripti tekrar çalıştırabilirsiniz" -ForegroundColor Yellow