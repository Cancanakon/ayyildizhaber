/**
 * Reklam Yönetim Sistemi
 * Sidebar ve popup reklamlar için tam kontrol
 */

class AdManager {
    constructor() {
        this.init();
    }

    init() {
        // DOM yüklendikten sonra çalıştır
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.setupAds());
        } else {
            this.setupAds();
        }
    }

    setupAds() {
        console.log('Ad Manager başlatılıyor...');
        
        // Sidebar reklamları kur
        this.setupSidebarAds();
        
        // Popup reklamları kur (sadece ana sayfada)
        this.setupPopupAds();
        
        // Reklam impression'larını takip et
        this.trackAdImpressions();
        
        console.log('Ad Manager hazır');
    }

    setupSidebarAds() {
        // Tüm sidebar reklamları bul
        const sidebarAds = document.querySelectorAll('.vertical-banner-ad');
        
        sidebarAds.forEach(ad => {
            const closeBtn = ad.querySelector('.ad-close-btn');
            const adLink = ad.querySelector('a');
            const adId = ad.getAttribute('data-ad-id');
            
            // Kapatma butonu event listener
            if (closeBtn) {
                closeBtn.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    this.closeAd(ad);
                });
            }
            
            // Reklam tıklama event listener
            if (adLink && adId) {
                adLink.addEventListener('click', (e) => {
                    this.trackAdClick(parseInt(adId));
                });
            }
        });
    }

    setupPopupAds() {
        // Tüm sayfalarda popup göster
        const popupOverlay = document.getElementById('popup-ad-overlay');
        const popupCloseBtn = document.getElementById('popup-close-btn');
        const popupBackdrop = document.querySelector('.popup-ad-backdrop');
        
        if (popupOverlay) {
            // 3 saniye sonra popup'ı göster
            setTimeout(() => {
                this.showPopup(popupOverlay);
                
                // Impression track et
                const adId = popupOverlay.getAttribute('data-ad-id');
                if (adId) {
                    this.trackAdImpression(parseInt(adId));
                }
            }, 3000);
        }
        
        // Popup kapatma butonu
        if (popupCloseBtn) {
            popupCloseBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                this.closePopup();
            });
        }
        
        // Backdrop'a tıklandığında kapatma
        if (popupBackdrop) {
            popupBackdrop.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                this.closePopup();
            });
        }
        
        // ESC tuşu ile kapatma
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && popupOverlay && popupOverlay.classList.contains('show')) {
                this.closePopup();
            }
        });
    }
    
    showPopup(popupOverlay) {
        if (popupOverlay) {
            popupOverlay.style.display = 'flex';
            // Kısa bir gecikme sonra show class'ı ekle (CSS transition için)
            setTimeout(() => {
                popupOverlay.classList.add('show');
            }, 50);
        }
    }

    trackAdImpressions() {
        // Sayfa yüklendiğinde sidebar reklamları için impression track et
        const sidebarAds = document.querySelectorAll('.vertical-banner-ad[data-ad-id]');
        
        sidebarAds.forEach(ad => {
            const adId = ad.getAttribute('data-ad-id');
            if (adId) {
                this.trackAdImpression(parseInt(adId));
            }
        });
    }

    closeAd(adElement) {
        // Reklam elementini gizle
        adElement.style.opacity = '0';
        adElement.style.transform = 'translateX(-100%)';
        
        setTimeout(() => {
            adElement.style.display = 'none';
        }, 300);
    }

    closePopup() {
        const popupOverlay = document.getElementById('popup-ad-overlay');
        if (popupOverlay) {
            popupOverlay.classList.remove('show');
            
            // CSS transition tamamlandıktan sonra display:none yap
            setTimeout(() => {
                popupOverlay.style.display = 'none';
            }, 400);
        }
    }

    trackAdClick(adId) {
        fetch('/api/track-ad-click', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ ad_id: adId })
        }).then(response => {
            if (response.ok) {
                console.log(`Reklam tıklandı: ${adId}`);
            }
        }).catch(error => {
            console.error('Reklam tıklama takibi hatası:', error);
        });
    }

    trackAdImpression(adId) {
        fetch('/api/track-ad-impression', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ ad_id: adId })
        }).then(response => {
            if (response.ok) {
                console.log(`Reklam görüntülendi: ${adId}`);
            }
        }).catch(error => {
            console.error('Reklam görüntüleme takibi hatası:', error);
        });
    }
}

// Global fonksiyonlar (backward compatibility için)
window.trackAdClick = function(adId) {
    if (window.adManager) {
        window.adManager.trackAdClick(adId);
    }
};

window.closeAd = function(adId) {
    const adElement = document.querySelector(`[data-ad-id="${adId}"]`);
    if (adElement) {
        adElement.style.display = 'none';
        console.log(`Reklam kapatıldı: ${adId}`);
    }
};

window.closePopupAd = function() {
    if (window.adManager) {
        window.adManager.closePopup();
    }
};

// Ad Manager'ı başlat
window.adManager = new AdManager();