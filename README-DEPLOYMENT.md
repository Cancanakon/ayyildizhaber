# VPS Güncelleme Kılavuzu

## Bilgisayarınızdan VPS'ye Güncelleme Yöntemleri

### 1. Tam Güncelleme (Önerilen)
```bash
./update-vps.sh
```
- Tüm dosyalarınızı bilgisayarınızdan sunucuya gönderir
- Otomatik yedekleme yapar
- Python paketlerini günceller
- Servisleri yeniden başlatır
- Sistem durumunu kontrol eder

### 2. Hızlı Güncelleme
```bash
./quick-update.sh
```
- Sadece kod dosyalarını gönderir
- En hızlı güncelleme yöntemi
- Otomatik backup

### 3. Akıllı Senkronizasyon
```bash
./sync-to-vps.sh
```
- Sadece değişen dosyaları gönderir
- Rsync kullanır
- Minimum veri transferi

### 4. Canlı Yayın Sistemi İçin Özel
```bash
./deploy-live-stream.sh
```
- Canlı yayın özelliklerini günceller
- Veritabanı tablolarını kontrol eder
- Route kayıtlarını yapar

## Kullanım Adımları

1. **SSH Anahtarınızı Kontrol Edin**
   ```bash
   ssh root@69.62.110.158
   ```

2. **Güncelleme Scriptini Çalıştırın**
   ```bash
   ./update-vps.sh
   ```

3. **Sonucu Kontrol Edin**
   - Site: http://69.62.110.158
   - Admin: http://69.62.110.158/admin

## Güvenlik Notları

- Her güncelleme otomatik backup yapar
- Hata durumunda önceki versiyona dönüş mümkün
- Servisler graceful restart yapar
- Kullanıcı kesintisi minimum

## Sorun Giderme

Eğer güncelleme sırasında hata alırsanız:

1. **SSH bağlantı hatası**: Anahtarınızı kontrol edin
2. **Permission hatası**: Script'lere execute permission verin: `chmod +x *.sh`
3. **Servis hatası**: Manuel restart yapın: `ssh root@69.62.110.158 'systemctl restart gunicorn'`

## Yedek Dosyalar

Yedekler `/var/www/` altında saklanır:
- ayyildizajans_backup_YYYYMMDD_HHMMSS formatında
- Disk dolması durumunda eski yedekleri silebilirsiniz