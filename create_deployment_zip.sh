#!/bin/bash

# Ayyıldız Haber Ajansı - Deployment ZIP Oluşturucu
# Sadece gerekli dosyaları içerir

echo "Deployment ZIP dosyası oluşturuluyor..."

# Geçici dizin oluştur
mkdir -p /tmp/ayyildizhaber-deployment
cd /tmp/ayyildizhaber-deployment

# Ana proje dosyalarını kopyala
cp -r /workspaces/*/ad_routes.py . 2>/dev/null || cp ad_routes.py .
cp -r /workspaces/*/admin_config_routes.py . 2>/dev/null || cp admin_config_routes.py .
cp -r /workspaces/*/admin_routes.py . 2>/dev/null || cp admin_routes.py .
cp -r /workspaces/*/app.py . 2>/dev/null || cp app.py .
cp -r /workspaces/*/main.py . 2>/dev/null || cp main.py .
cp -r /workspaces/*/models.py . 2>/dev/null || cp models.py .
cp -r /workspaces/*/routes.py . 2>/dev/null || cp routes.py .
cp -r /workspaces/*/pyproject.toml . 2>/dev/null || cp pyproject.toml .
cp -r /workspaces/*/replit.md . 2>/dev/null || cp replit.md .

# Klasörleri kopyala
cp -r /workspaces/*/deployment . 2>/dev/null || cp -r deployment .
cp -r /workspaces/*/services . 2>/dev/null || cp -r services .
cp -r /workspaces/*/static . 2>/dev/null || cp -r static .
cp -r /workspaces/*/templates . 2>/dev/null || cp -r templates .
cp -r /workspaces/*/utils . 2>/dev/null || cp -r utils .
cp -r /workspaces/*/config . 2>/dev/null || cp -r config .

# Gereksiz dosyaları temizle
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true
rm -rf attached_assets cache cookies.txt uv.lock 2>/dev/null || true

# ZIP oluştur
zip -r ayyildizhaber-deployment.zip . -x "*.pyc" "*/__pycache__/*" "*/cache/*" "*/attached_assets/*"

echo "ZIP dosyası oluşturuldu: /tmp/ayyildizhaber-deployment/ayyildizhaber-deployment.zip"
echo "Boyut: $(du -h ayyildizhaber-deployment.zip | cut -f1)"
echo "İçerik:"
unzip -l ayyildizhaber-deployment.zip | head -20