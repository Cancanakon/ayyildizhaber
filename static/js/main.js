// Ayyıldız Haber Ajansı - Main JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Initialize all components
    initializeBreakingNews();
    initializeLazyLoading();
    initializeScrollEffects();
    initializeSearchForm();
    updateDateTime();
    initializeImageFallback();
    createBackToTopButton();
    loadFontSizePreference();
    initializeStoriesScroll();
    
    // Initialize live player after a short delay to ensure DOM is ready
    setTimeout(initializeLivePlayer, 100);
    
    // Setup video error detection
    setTimeout(setupVideoErrorDetection, 2000);
    
    // Update date/time every minute
    setInterval(updateDateTime, 60000);
});

// Initialize Stories Scroll
function initializeStoriesScroll() {
    const storiesWrapper = document.querySelector('.stories-wrapper');
    if (!storiesWrapper) return;
    
    // Add scroll navigation for desktop
    if (window.innerWidth > 768) {
        createStoriesNavigation();
    }
    
    // Add touch scroll for mobile
    let isScrolling = false;
    let scrollX = 0;
    let startX = 0;
    
    storiesWrapper.addEventListener('touchstart', (e) => {
        isScrolling = true;
        startX = e.touches[0].clientX - storiesWrapper.scrollLeft;
    });
    
    storiesWrapper.addEventListener('touchmove', (e) => {
        if (!isScrolling) return;
        e.preventDefault();
        scrollX = e.touches[0].clientX - startX;
        storiesWrapper.scrollLeft = scrollX;
    });
    
    storiesWrapper.addEventListener('touchend', () => {
        isScrolling = false;
    });
}

function createStoriesNavigation() {
    const container = document.querySelector('.stories-scroll-container');
    const wrapper = document.querySelector('.stories-wrapper');
    
    if (!container || !wrapper) return;
    
    // Create navigation buttons
    const prevBtn = document.createElement('button');
    prevBtn.className = 'stories-nav-btn stories-nav-prev';
    prevBtn.innerHTML = '<i class="fas fa-chevron-left"></i>';
    prevBtn.style.cssText = `
        position: absolute;
        left: 10px;
        top: 50%;
        transform: translateY(-50%);
        background: white;
        border: 2px solid var(--primary-red);
        color: var(--primary-red);
        width: 40px;
        height: 40px;
        border-radius: 50%;
        cursor: pointer;
        z-index: 10;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        transition: all 0.3s ease;
    `;
    
    const nextBtn = document.createElement('button');
    nextBtn.className = 'stories-nav-btn stories-nav-next';
    nextBtn.innerHTML = '<i class="fas fa-chevron-right"></i>';
    nextBtn.style.cssText = prevBtn.style.cssText.replace('left: 10px', 'right: 10px');
    
    // Add hover effects
    [prevBtn, nextBtn].forEach(btn => {
        btn.addEventListener('mouseenter', () => {
            btn.style.background = 'var(--primary-red)';
            btn.style.color = 'white';
        });
        btn.addEventListener('mouseleave', () => {
            btn.style.background = 'white';
            btn.style.color = 'var(--primary-red)';
        });
    });
    
    // Add click handlers
    prevBtn.addEventListener('click', () => {
        wrapper.scrollBy({ left: -300, behavior: 'smooth' });
    });
    
    nextBtn.addEventListener('click', () => {
        wrapper.scrollBy({ left: 300, behavior: 'smooth' });
    });
    
    container.appendChild(prevBtn);
    container.appendChild(nextBtn);
    
    // Update button visibility based on scroll position
    const updateNavButtons = () => {
        const maxScroll = wrapper.scrollWidth - wrapper.clientWidth;
        prevBtn.style.opacity = wrapper.scrollLeft <= 0 ? '0.5' : '1';
        nextBtn.style.opacity = wrapper.scrollLeft >= maxScroll ? '0.5' : '1';
    };
    
    wrapper.addEventListener('scroll', updateNavButtons);
    updateNavButtons();
}

// Breaking News Ticker
function initializeBreakingNews() {
    const ticker = document.querySelector('.news-ticker');
    if (ticker) {
        // Pause animation on hover
        ticker.addEventListener('mouseenter', () => {
            ticker.style.animationPlayState = 'paused';
        });
        
        ticker.addEventListener('mouseleave', () => {
            ticker.style.animationPlayState = 'running';
        });
    }
}

// Lazy Loading for Images
function initializeLazyLoading() {
    const images = document.querySelectorAll('img[data-src]');
    
    const imageObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const img = entry.target;
                img.src = img.dataset.src;
                img.classList.remove('lazy');
                imageObserver.unobserve(img);
            }
        });
    });
    
    images.forEach(img => imageObserver.observe(img));
}

// Scroll Effects
function initializeScrollEffects() {
    const elements = document.querySelectorAll('.fade-in, .slide-up');
    
    const scrollObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate');
            }
        });
    }, {
        threshold: 0.1
    });
    
    elements.forEach(el => scrollObserver.observe(el));
}

// Search Form Enhancement
function initializeSearchForm() {
    const searchForm = document.querySelector('.search-form');
    const searchInput = document.querySelector('.search-form input');
    
    if (searchForm && searchInput) {
        searchForm.addEventListener('submit', function(e) {
            const query = searchInput.value.trim();
            if (query.length < 3) {
                e.preventDefault();
                alert('Arama için en az 3 karakter girmelisiniz.');
                return false;
            }
        });
        
        // Search suggestions (if implemented)
        searchInput.addEventListener('input', debounce(function() {
            const query = this.value.trim();
            if (query.length >= 3) {
                // fetchSearchSuggestions(query);
            }
        }, 300));
    }
}

// Update Date and Time
function updateDateTime() {
    const dateElement = document.querySelector('.current-date');
    if (dateElement) {
        const now = new Date();
        const options = {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        };
        
        const turkishDate = now.toLocaleDateString('tr-TR', options);
        const time = now.toLocaleTimeString('tr-TR', {
            hour: '2-digit',
            minute: '2-digit'
        });
        
        dateElement.textContent = `${turkishDate} - ${time}`;
    }
}

// Utility Functions
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Share News Function
function shareNews(title, url) {
    if (navigator.share) {
        navigator.share({
            title: title,
            url: url
        }).catch(console.error);
    } else {
        // Fallback - copy to clipboard
        navigator.clipboard.writeText(url).then(() => {
            alert('Link kopyalandı!');
        }).catch(() => {
            // Manual fallback
            const textArea = document.createElement('textarea');
            textArea.value = url;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            alert('Link kopyalandı!');
        });
    }
}

// Print News Function
function printNews() {
    window.print();
}

// Back to Top Button
function createBackToTopButton() {
    const button = document.createElement('button');
    button.innerHTML = '<i class="fas fa-chevron-up"></i>';
    button.className = 'btn btn-primary position-fixed';
    button.style.cssText = 'position: fixed; bottom: 20px; right: 20px; z-index: 1000; border-radius: 50%; width: 50px; height: 50px; display: none;';
    
    document.body.appendChild(button);
    
    // Show/hide button based on scroll position
    window.addEventListener('scroll', () => {
        if (window.pageYOffset > 300) {
            button.style.display = 'block';
        } else {
            button.style.display = 'none';
        }
    });
    
    // Smooth scroll to top
    button.addEventListener('click', () => {
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    });
}

// Font Size Adjustment
function adjustFontSize(action) {
    const content = document.querySelector('.news-content');
    if (!content) return;
    
    const currentSize = parseInt(window.getComputedStyle(content).fontSize);
    let newSize;
    
    switch(action) {
        case 'increase':
            newSize = Math.min(currentSize + 2, 24);
            break;
        case 'decrease':
            newSize = Math.max(currentSize - 2, 14);
            break;
        case 'reset':
            newSize = 16;
            break;
        default:
            return;
    }
    
    content.style.fontSize = newSize + 'px';
    
    // Save preference
    localStorage.setItem('fontSize', newSize);
}

// Load Font Size Preference
function loadFontSizePreference() {
    const savedSize = localStorage.getItem('fontSize');
    if (savedSize) {
        const content = document.querySelector('.news-content');
        if (content) {
            content.style.fontSize = savedSize + 'px';
        }
    }
}

// News View Tracking
function trackNewsView(newsId) {
    // Send view event to server
    fetch('/api/track-view', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            news_id: newsId,
            timestamp: new Date().toISOString()
        })
    }).catch(console.error);
}

// Image fallback system for news images
function initializeImageFallback() {
    // Handle image fallback for news images
    const imagesWithFallback = document.querySelectorAll('.img-with-fallback');
    
    imagesWithFallback.forEach(img => {
        img.addEventListener('error', function() {
            if (this.dataset.tried) return; // Prevent infinite loops
            
            const container = this.closest('.image-container');
            const contentImages = container ? container.dataset.contentImages : '';
            
            if (contentImages) {
                const imageList = contentImages.split(',').filter(url => url.trim());
                let found = false;
                
                for (let imageUrl of imageList) {
                    imageUrl = imageUrl.trim();
                    if (imageUrl && imageUrl !== this.src) {
                        // Clean up URL format
                        if (imageUrl.startsWith('//')) {
                            imageUrl = 'https:' + imageUrl;
                        }
                        this.src = imageUrl;
                        this.dataset.tried = 'true';
                        found = true;
                        break;
                    }
                }
                
                if (!found) {
                    showFallbackImage(this);
                }
            } else {
                showFallbackImage(this);
            }
        });
    });
}

function showFallbackImage(imgElement) {
    imgElement.style.display = 'none';
    const container = imgElement.closest('.image-container');
    if (container) {
        const fallback = container.querySelector('.fallback-image');
        if (fallback) {
            fallback.style.display = 'flex';
        }
    }
}

// Initialize additional features
document.addEventListener('DOMContentLoaded', function() {
    createBackToTopButton();
    loadFontSizePreference();
    
    // Track news view if on news detail page
    const newsId = document.querySelector('[data-news-id]');
    if (newsId) {
        trackNewsView(newsId.dataset.newsId);
    }
});

// Admin Panel Functions
if (window.location.pathname.includes('/admin')) {
    
    // Confirm Delete Actions
    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('btn-delete') || 
            e.target.closest('.btn-delete')) {
            if (!confirm('Bu işlemi gerçekleştirmek istediğinizden emin misiniz?')) {
                e.preventDefault();
                return false;
            }
        }
    });
    
    // Auto-save Draft
    let autoSaveTimeout;
    const contentFields = document.querySelectorAll('textarea[name="content"], input[name="title"]');
    
    contentFields.forEach(field => {
        field.addEventListener('input', () => {
            clearTimeout(autoSaveTimeout);
            autoSaveTimeout = setTimeout(() => {
                saveDraft();
            }, 5000); // Auto-save after 5 seconds of inactivity
        });
    });
    
    function saveDraft() {
        const form = document.querySelector('#news-form');
        if (!form) return;
        
        const formData = new FormData(form);
        formData.append('action', 'auto_save');
        
        fetch(form.action, {
            method: 'POST',
            body: formData
        }).then(response => {
            if (response.ok) {
                const indicator = document.querySelector('.auto-save-indicator');
                if (indicator) {
                    indicator.textContent = 'Otomatik kaydedildi: ' + new Date().toLocaleTimeString();
                }
            }
        }).catch(console.error);
    }
    
    // Image Preview
    function previewImages(input) {
        const preview = document.querySelector('#image-preview');
        if (!preview) return;
        
        preview.innerHTML = '';
        
        Array.from(input.files).forEach(file => {
            if (file.type.startsWith('image/')) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    const img = document.createElement('img');
                    img.src = e.target.result;
                    img.className = 'img-thumbnail m-2';
                    img.style.maxWidth = '150px';
                    preview.appendChild(img);
                };
                reader.readAsDataURL(file);
            }
        });
    }
    
    // Attach image preview to file inputs
    const imageInputs = document.querySelectorAll('input[type="file"][accept*="image"]');
    imageInputs.forEach(input => {
        input.addEventListener('change', function() {
            previewImages(this);
        });
    });
}

// Error Handling
window.addEventListener('error', function(e) {
    console.error('JavaScript Error:', e.error);
    // Could send error reports to server
});

// Live Player Functionality
function initializeLivePlayer() {
    console.log('Starting live player initialization...');
    
    const playerContainer = document.getElementById('live-player-container');
    const playerToggle = document.getElementById('live-player-toggle');
    const minimizeBtn = document.getElementById('minimize-player');
    const closeBtn = document.getElementById('close-player');
    const openBtn = document.getElementById('open-player');
    const playerHeader = playerContainer ? playerContainer.querySelector('.live-player-header') : null;
    
    console.log('Live player elements:', {
        playerContainer: !!playerContainer,
        playerToggle: !!playerToggle,
        minimizeBtn: !!minimizeBtn,
        closeBtn: !!closeBtn,
        openBtn: !!openBtn,
        playerHeader: !!playerHeader
    });
    
    if (!playerContainer || !playerToggle) {
        console.log('Required live player elements not found');
        return;
    }
    
    // Check user preferences
    const playerClosed = localStorage.getItem('livePlayerClosed') === 'true';
    const playerMinimized = localStorage.getItem('livePlayerMinimized') === 'true';
    
    console.log('Player state from localStorage:', { playerClosed, playerMinimized });
    
    // Set initial state
    if (!playerClosed) {
        playerContainer.style.display = 'block';
        playerToggle.style.display = 'none';
        
        if (playerMinimized) {
            playerContainer.classList.add('minimized');
        }
    } else {
        playerContainer.style.display = 'none';
        playerToggle.style.display = 'block';
    }
    
    // Drag functionality
    let isDragging = false;
    let dragStartX = 0;
    let dragStartY = 0;
    let playerStartX = 0;
    let playerStartY = 0;
    
    if (playerHeader) {
        playerHeader.style.cursor = 'move';
        
        playerHeader.addEventListener('mousedown', function(e) {
            if (e.target.closest('.btn-player-control')) return; // Don't drag when clicking buttons
            
            isDragging = true;
            dragStartX = e.clientX;
            dragStartY = e.clientY;
            
            const rect = playerContainer.getBoundingClientRect();
            playerStartX = rect.left;
            playerStartY = rect.top;
            
            playerContainer.style.position = 'fixed';
            playerContainer.style.right = 'auto';
            playerContainer.style.bottom = 'auto';
            playerContainer.style.left = playerStartX + 'px';
            playerContainer.style.top = playerStartY + 'px';
            
            document.addEventListener('mousemove', handleDrag);
            document.addEventListener('mouseup', stopDrag);
            
            e.preventDefault();
        });
        
        function handleDrag(e) {
            if (!isDragging) return;
            
            const deltaX = e.clientX - dragStartX;
            const deltaY = e.clientY - dragStartY;
            
            let newX = playerStartX + deltaX;
            let newY = playerStartY + deltaY;
            
            // Keep player within viewport
            const maxX = window.innerWidth - playerContainer.offsetWidth;
            const maxY = window.innerHeight - playerContainer.offsetHeight;
            
            newX = Math.max(0, Math.min(newX, maxX));
            newY = Math.max(0, Math.min(newY, maxY));
            
            playerContainer.style.left = newX + 'px';
            playerContainer.style.top = newY + 'px';
        }
        
        function stopDrag() {
            isDragging = false;
            document.removeEventListener('mousemove', handleDrag);
            document.removeEventListener('mouseup', stopDrag);
        }
    }
    
    // Minimize functionality
    if (minimizeBtn) {
        minimizeBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            
            console.log('Minimize button clicked');
            
            playerContainer.classList.toggle('minimized');
            const isMinimized = playerContainer.classList.contains('minimized');
            localStorage.setItem('livePlayerMinimized', isMinimized.toString());
            
            // Update button icon
            const icon = minimizeBtn.querySelector('i');
            if (icon) {
                icon.className = isMinimized ? 'fas fa-window-maximize' : 'fas fa-minus';
            }
        });
    }
    
    // Close functionality
    if (closeBtn) {
        closeBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            
            console.log('Close button clicked');
            
            playerContainer.style.display = 'none';
            playerToggle.style.display = 'block';
            localStorage.setItem('livePlayerClosed', 'true');
            
            // Reset position to default
            playerContainer.style.position = 'fixed';
            playerContainer.style.right = '20px';
            playerContainer.style.bottom = '20px';
            playerContainer.style.left = 'auto';
            playerContainer.style.top = 'auto';
        });
    }
    
    // Open functionality
    if (openBtn) {
        openBtn.addEventListener('click', function(e) {
            e.preventDefault();
            
            console.log('Open button clicked');
            
            playerContainer.style.display = 'block';
            playerToggle.style.display = 'none';
            playerContainer.classList.remove('minimized');
            localStorage.setItem('livePlayerClosed', 'false');
            localStorage.setItem('livePlayerMinimized', 'false');
            
            // Update minimize button icon
            const icon = minimizeBtn ? minimizeBtn.querySelector('i') : null;
            if (icon) {
                icon.className = 'fas fa-minus';
            }
        });
    }
    
    // Auto-fade toggle button when player is closed
    if (playerClosed && playerToggle) {
        setTimeout(() => {
            if (playerToggle.style.display === 'block') {
                playerToggle.style.opacity = '0.7';
            }
        }, 10000);
        
        playerToggle.addEventListener('mouseenter', function() {
            this.style.opacity = '1';
        });
        
        playerToggle.addEventListener('mouseleave', function() {
            this.style.opacity = '0.7';
        });
    }
    
    console.log('Live player initialization completed');
}

// YouTube Live Stream Retry Function
function retryLiveStream() {
    const iframe = document.getElementById('live-iframe');
    const errorOverlay = document.getElementById('video-error-message');
    
    if (iframe && errorOverlay) {
        // Hide error overlay
        errorOverlay.style.display = 'none';
        
        // Try alternative live stream URLs
        const streamUrls = [
            'https://www.youtube.com/embed/live_stream?channel=UCwIAJU8WnPNTmUfrGJMkwOQ&autoplay=1&mute=1&controls=1&rel=0&modestbranding=1&playsinline=1',
            'https://www.youtube.com/embed/jfKfPfyJRdk?autoplay=1&mute=1&controls=1&rel=0&modestbranding=1&playsinline=1', // CNN Türk
            'https://www.youtube.com/embed/XxJKnDLYZz4?autoplay=1&mute=1&controls=1&rel=0&modestbranding=1&playsinline=1'  // TRT Haber
        ];
        
        // Use a random stream URL
        const randomUrl = streamUrls[Math.floor(Math.random() * streamUrls.length)];
        iframe.src = randomUrl;
        
        // Set up error detection
        setTimeout(() => {
            // Check if video is playing by trying to access iframe content
            try {
                if (iframe.contentWindow) {
                    console.log('Live stream loaded successfully');
                }
            } catch (e) {
                console.log('Live stream still having issues, showing error overlay');
                errorOverlay.style.display = 'flex';
            }
        }, 3000);
    }
}

// Auto-detect video errors and show overlay
function setupVideoErrorDetection() {
    const iframe = document.getElementById('live-iframe');
    const errorOverlay = document.getElementById('video-error-message');
    
    if (iframe && errorOverlay) {
        iframe.addEventListener('load', () => {
            // Wait a bit then check if video is working
            setTimeout(() => {
                // If iframe is still loading or has issues, show error
                try {
                    const iframeSrc = iframe.src;
                    if (!iframeSrc || iframeSrc.includes('error')) {
                        errorOverlay.style.display = 'flex';
                    }
                } catch (e) {
                    console.log('Video detection check failed, assuming it works');
                }
            }, 5000);
        });
        
        iframe.addEventListener('error', () => {
            errorOverlay.style.display = 'flex';
        });
    }
}

// Recommendation tracking functions
function trackRecommendationClick(newsId) {
    fetch('/api/track-interaction', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            news_id: newsId,
            interaction_type: 'click'
        })
    }).catch(error => console.log('Tracking error:', error));
}

function trackScrollDepth() {
    let maxScroll = 0;
    let newsId = null;
    
    const metaNewsId = document.querySelector('meta[name="news-id"]');
    if (metaNewsId) {
        newsId = parseInt(metaNewsId.content);
    }
    
    if (!newsId) return;
    
    let startTime = Date.now();
    
    window.addEventListener('scroll', function() {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const docHeight = document.documentElement.scrollHeight - window.innerHeight;
        const scrollPercent = scrollTop / docHeight;
        
        maxScroll = Math.max(maxScroll, scrollPercent);
    });
    
    window.addEventListener('beforeunload', function() {
        const duration = Math.floor((Date.now() - startTime) / 1000);
        
        if (duration > 5 && maxScroll > 0.1) {
            navigator.sendBeacon('/api/track-interaction', JSON.stringify({
                news_id: newsId,
                interaction_type: 'scroll',
                duration: duration,
                scroll_depth: maxScroll
            }));
        }
    });
}

// Initialize tracking on news detail pages
if (window.location.pathname.includes('/haber/')) {
    trackScrollDepth();
}

// Service Worker Registration (for offline functionality)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/service-worker.js')
            .then(registration => {
                console.log('SW registered: ', registration);
            })
            .catch(registrationError => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}
