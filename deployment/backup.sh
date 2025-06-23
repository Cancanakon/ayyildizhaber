#!/bin/bash

# Ayyıldız Haber Ajansı - Otomatik Backup Script
# Bu script veritabanı ve dosyaların yedeğini alır

set -e

# Konfigürasyon
BACKUP_DIR="/var/backups/ayyildizhaber"
APP_DIR="/var/www/ayyildizhaber"
DB_NAME="ayyildizhaber"
DB_USER="ayyildizhaber_user"
RETENTION_DAYS=30

# Backup dizini oluştur
mkdir -p $BACKUP_DIR

# Tarih formatı
DATE=$(date +%Y%m%d_%H%M%S)

echo "=== Ayyıldız Haber Backup Başlıyor - $DATE ==="

# 1. Veritabanı Backup
echo "Veritabanı yedeği alınıyor..."
PGPASSWORD="SecurePassword123!" pg_dump -h localhost -U $DB_USER $DB_NAME > $BACKUP_DIR/db_backup_$DATE.sql

# 2. Uygulama Dosyaları Backup
echo "Uygulama dosyaları yedeği alınıyor..."
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='cache' \
    -C /var/www ayyildizhaber

# 3. Static Files Backup
echo "Static dosyalar yedeği alınıyor..."
tar -czf $BACKUP_DIR/static_backup_$DATE.tar.gz -C $APP_DIR static

# 4. Eski backupları temizle
echo "Eski backuplar temizleniyor (${RETENTION_DAYS} gün ve üzeri)..."
find $BACKUP_DIR -name "*.sql" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

# 5. Backup boyutu raporu
echo "Backup raporu:"
echo "- Veritabanı: $(ls -lh $BACKUP_DIR/db_backup_$DATE.sql | awk '{print $5}')"
echo "- Uygulama: $(ls -lh $BACKUP_DIR/app_backup_$DATE.tar.gz | awk '{print $5}')"
echo "- Static: $(ls -lh $BACKUP_DIR/static_backup_$DATE.tar.gz | awk '{print $5}')"

# 6. Log
echo "$(date): Backup completed successfully" >> /var/log/ayyildizhaber/backup.log

echo "=== Backup Tamamlandı ==="