#!/usr/bin/env python3
"""
Production Flask Starter
Gunicorn olmadan Flask uygulamasını production modunda başlatır
"""

import os
import sys
import signal
import time
from threading import Thread

# Proje dizinini Python path'ine ekle
project_dir = '/opt/ayyildizhaber'
if project_dir not in sys.path:
    sys.path.insert(0, project_dir)

# Çalışma dizinini değiştir
os.chdir(project_dir)

def signal_handler(sig, frame):
    """Graceful shutdown handler"""
    print('\nFlask uygulaması durduruluyor...')
    sys.exit(0)

def start_flask_app():
    """Flask uygulamasını başlat"""
    try:
        # Signal handler'ları ayarla
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        print("Flask uygulaması başlatılıyor...")
        print(f"Proje dizini: {project_dir}")
        print(f"Python path: {sys.path[0]}")
        
        # Flask uygulamasını import et
        from app import app
        
        # Production ayarları
        app.config['DEBUG'] = False
        app.config['ENV'] = 'production'
        
        print("Flask uygulaması port 5000'de başlatılıyor...")
        
        # Flask uygulamasını başlat
        app.run(
            host='0.0.0.0',
            port=5000,
            debug=False,
            use_reloader=False,
            threaded=True
        )
        
    except Exception as e:
        print(f"Hata: Flask uygulaması başlatılamadı: {e}")
        sys.exit(1)

if __name__ == '__main__':
    start_flask_app()