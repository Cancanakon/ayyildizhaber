@echo off
REM Ayyıldız Haber Ajansı - Windows CMD Deploy Scripti
REM Bu scripti Windows CMD'de çalıştırın

echo === Ayyıldız Haber Ajansı VPS Deploy Başlıyor ===
echo.

set VPS_IP=69.62.110.158
set VPS_USER=root
set PROJECT_PATH=/var/www/ayyildizhaber

echo Deploy paketi hazırlanıyor...

REM Geçici dizin oluştur
set TEMP_DIR=%TEMP%\ayyildizhaber_%RANDOM%
mkdir "%TEMP_DIR%"
set TAR_FILE=%TEMP_DIR%\ayyildizhaber-deploy.tar.gz

REM Windows tar komutu ile paket oluştur
tar --exclude=__pycache__ --exclude=*.pyc --exclude=.git --exclude=venv --exclude=cache --exclude=*.log --exclude=node_modules --exclude=.DS_Store --exclude=attached_assets --exclude=clean-deployment --exclude=deployment --exclude=*.tar.gz -czf "%TAR_FILE%" .

if errorlevel 1 (
    echo HATA: Tar komutu çalışmadı!
    echo Lütfen Windows 10+ kullandığınızdan emin olun
    pause
    exit /b 1
)

echo Deploy paketi oluşturuldu
echo.

echo Dosyalar VPS'ye gönderiliyor...
scp "%TAR_FILE%" %VPS_USER%@%VPS_IP%:/tmp/

if errorlevel 1 (
    echo HATA: SCP komutu çalışmadı!
    echo OpenSSH Client yüklü değil. PuTTY pscp deneniyor...
    pscp -batch "%TAR_FILE%" %VPS_USER%@%VPS_IP%:/tmp/
    if errorlevel 1 (
        echo HATA: Ne scp ne de pscp bulunamadı!
        echo Lütfen OpenSSH Client veya PuTTY yükleyin
        pause
        exit /b 1
    )
)

echo.
echo VPS'de deploy işlemleri başlatılıyor...

REM SSH ile VPS'de komutları çalıştır
ssh %VPS_USER%@%VPS_IP% "set -e && echo 'Uygulama servisi durduruluyor...' && systemctl stop ayyildizhaber || true && echo 'Eski dosyalar temizleniyor...' && rm -rf /var/www/ayyildizhaber/* && echo 'Yeni dosyalar çıkarılıyor...' && cd /var/www/ayyildizhaber && tar -xzf /tmp/ayyildizhaber-deploy.tar.gz && rm /tmp/ayyildizhaber-deploy.tar.gz && echo 'Python paketleri yükleniyor...' && source venv/bin/activate && pip install --upgrade pip && if [ -f requirements-vps.txt ]; then pip install -r requirements-vps.txt; else pip install flask flask-sqlalchemy flask-login werkzeug gunicorn psycopg2-binary apscheduler beautifulsoup4 requests trafilatura lxml feedparser python-dateutil email-validator; fi && echo 'Çevre değişkenleri ayarlanıyor...' && echo 'DATABASE_URL=postgresql://ayyildizhaber:ayyildizhaber123@localhost/ayyildizhaber' > .env && echo 'SESSION_SECRET=ayyildizhaber-super-secret-key-2025' >> .env && echo 'FLASK_ENV=production' >> .env && echo 'PYTHONPATH=/var/www/ayyildizhaber' >> .env && echo 'Veritabanı tabloları oluşturuluyor...' && export DATABASE_URL=postgresql://ayyildizhaber:ayyildizhaber123@localhost/ayyildizhaber && export SESSION_SECRET=ayyildizhaber-super-secret-key-2025 && export FLASK_ENV=production && export PYTHONPATH=/var/www/ayyildizhaber && python3 -c 'import sys; sys.path.insert(0, \"/var/www/ayyildizhaber\"); from app import app, db; app.app_context().push(); db.create_all(); print(\"Veritabanı tabloları oluşturuldu\")' && echo 'Dosya izinleri ayarlanıyor...' && chown -R www-data:www-data /var/www/ayyildizhaber && chmod -R 755 /var/www/ayyildizhaber && mkdir -p static/uploads && chown -R www-data:www-data static/uploads && chmod -R 775 static/uploads && echo 'Systemd servisi aktifleştiriliyor...' && systemctl daemon-reload && systemctl enable ayyildizhaber && systemctl start ayyildizhaber && echo 'Nginx yeniden başlatılıyor...' && systemctl restart nginx && echo 'Servis durumu kontrol ediliyor...' && sleep 3 && systemctl status ayyildizhaber --no-pager -l"

if errorlevel 1 (
    echo HATA: SSH deploy komutu başarısız oldu!
    echo PuTTY plink deneniyor...
    echo set -e > "%TEMP_DIR%\deploy.sh"
    echo echo 'Uygulama servisi durduruluyor...' >> "%TEMP_DIR%\deploy.sh"
    echo systemctl stop ayyildizhaber ^|^| true >> "%TEMP_DIR%\deploy.sh"
    echo echo 'Deploy işlemleri devam ediyor...' >> "%TEMP_DIR%\deploy.sh"
    plink -batch %VPS_USER%@%VPS_IP% < "%TEMP_DIR%\deploy.sh"
    if errorlevel 1 (
        echo HATA: Ne ssh ne de plink bulunamadı!
        echo Lütfen OpenSSH Client veya PuTTY yükleyin
        pause
        exit /b 1
    )
)

REM Geçici dosyaları temizle
rmdir /s /q "%TEMP_DIR%"

echo.
echo === Deploy Tamamlandı ===
echo.
echo 🌐 Siteniz artık çalışıyor:
echo    http://69.62.110.158
echo    http://www.ayyildizajans.com
echo.
echo 🔧 Admin Panel:
echo    http://69.62.110.158/admin
echo    Email: admin@gmail.com
echo    Şifre: admin123
echo.
echo 📊 Log kontrol:
echo    ssh root@69.62.110.158
echo    systemctl status ayyildizhaber
echo    tail -f /var/log/ayyildizhaber/error.log
echo.
echo 🔄 Güncelleme için bu scripti tekrar çalıştırabilirsiniz
echo.
pause