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
        // Sadece ana sayfada popup göster
        const isHomePage = window.location.pathname === '/' || window.location.pathname === '/index';
        
        if (!isHomePage) return;
        
        const popupOverlay = document.getElementById('popup-ad-overlay');
        const popupCloseBtn = document.getElementById('popup-close-btn');
        
        if (popupOverlay) {
            // 2 saniye sonra popup'ı göster
            setTimeout(() => {
                popupOverlay.style.display = 'flex';
                popupOverlay.style.opacity = '0';
                
                // Fade in efekti
                setTimeout(() => {
                    popupOverlay.style.opacity = '1';
                }, 100);
                
                // Impression track et
                const adId = popupOverlay.getAttribute('data-ad-id');
                if (adId) {
                    this.trackAdImpression(parseInt(adId));
                }
            }, 2000);
        }
        
        // Popup kapatma butonu
        if (popupCloseBtn) {
            popupCloseBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                this.closePopup();
            });
        }
        
        // Popup'a tıklandığında kapatma (sadece overlay'e tıklanırsa)
        if (popupOverlay) {
            popupOverlay.addEventListener('click', (e) => {
                if (e.target === popupOverlay) {
                    // Sadece overlay'in kendisine tıklanırsa kapat
                    // this.closePopup(); // Kaldırıldı - sadece X butonu ile kapanacak
                }
            });
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
            popupOverlay.style.opacity = '0';
            
            setTimeout(() => {
                popupOverlay.style.display = 'none';
            }, 300);
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

window.closePopupAd = function() {
    if (window.adManager) {
        window.adManager.closePopup();
    }
};

// Ad Manager'ı başlat
window.adManager = new AdManager();