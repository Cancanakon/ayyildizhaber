# Ayyıldız Haber Ajansı - News Website

## Overview

This is a comprehensive news website application built with Flask, featuring a Turkish news agency theme with a red color scheme. The application provides a complete news management system with both public-facing news display and administrative functionality.

## System Architecture

### Frontend Architecture
- **Framework**: Flask with Jinja2 templating
- **Styling**: Bootstrap 5.1.3 with custom CSS (red theme)
- **JavaScript**: Vanilla JavaScript for interactive features
- **Responsive Design**: Mobile-first approach with Bootstrap grid system

### Backend Architecture
- **Framework**: Flask (Python web framework)
- **Database**: SQLAlchemy ORM with support for both SQLite (development) and PostgreSQL (production)
- **Authentication**: Flask-Login for admin session management
- **Background Tasks**: APScheduler for automated news fetching
- **File Handling**: Werkzeug for secure file uploads

### Template Structure
- Base template with consistent header/footer
- Category-specific news pages
- News detail pages with social sharing
- Admin panel with separate template hierarchy
- Search functionality with pagination

## Key Components

### Models
- **Admin**: User management with role-based permissions
- **Category**: News categorization system
- **News**: Main content model with rich metadata
- **NewsView**: View tracking for analytics
- **SiteStatistics**: System-wide statistics

### Services
- **Currency Service**: External API integration for currency rates
- **Weather Service**: Multi-city weather data with caching
- **Prayer Service**: Islamic prayer times for Turkish cities
- **TRT News Service**: External news feed integration
- **External News Service**: Multiple news source aggregation

### Admin Panel Features
- User management with role-based access
- News creation and editing with rich text editor
- Category management with color coding
- Statistics and analytics dashboard
- File upload management

## Data Flow

1. **Public Interface**: Users browse news by category, search, and view details
2. **Admin Interface**: Administrators manage content through secure admin panel
3. **External Services**: Background tasks fetch news from external sources
4. **Caching System**: External API data cached to reduce API calls
5. **Database Operations**: All data persisted through SQLAlchemy ORM

## External Dependencies

### Python Packages
- Flask ecosystem (Flask, Flask-SQLAlchemy, Flask-Login)
- Database drivers (psycopg2-binary for PostgreSQL)
- Web scraping (BeautifulSoup4, lxml, requests)
- Task scheduling (APScheduler)
- Email validation and utilities

### External APIs
- News APIs for content aggregation
- Weather APIs for multi-city forecasts
- Currency exchange rate APIs
- Prayer times APIs for Turkish cities

### Frontend Libraries
- Bootstrap 5.1.3 for responsive design
- Font Awesome 6.0.0 for icons
- TinyMCE for rich text editing (admin panel)
- Chart.js for statistics visualization

## Deployment Strategy

### Development Environment
- SQLite database for local development
- Debug mode enabled
- Hot reload with Gunicorn

### Production Environment
- PostgreSQL database
- Gunicorn WSGI server with autoscaling
- Static file serving optimization
- Environment variable configuration

### Configuration
- Database URL configurable via environment variables
- File upload limits and security settings
- Session management with secure keys
- Proxy configuration for reverse proxy deployment

## Recent Changes  
- July 5, 2025: Reklam sistemindeki kritik sorun çözüldü - popup reklamlar artık sayfaya girişte görünür ve sadece X butonuyla kapanır
- July 5, 2025: Reklamların dışına tıklama ile kapanma sorunu giderildi - artık sadece kapatma butonuyla kapanır
- July 5, 2025: Reklam JavaScript kodları base template'e taşındı - tüm sayfalarda tutarlı çalışım
- July 5, 2025: Kenar reklamlarının kapatma butonları aktifleştirildi - kullanıcılar reklamları kapatabilir
- July 5, 2025: Admin panel istatistikleri gerçek verilerle güncellendi - SQLite uyumlu sorgular ve otantik veri görünümü
- July 5, 2025: Günlük görüntülenme trendi artık gerçek verileri gösteriyor - boş günler 0 değerle dahil edildi
- July 5, 2025: Trafik kaynakları ve cihaz istatistikleri gerçek kullanıcı verilerinden beslenecek şekilde düzenlendi
- July 5, 2025: Breaking news kayan yazısı iyileştirildi - daha yavaş animasyon (45s), hover efektleri ve responsive tasarım
- July 5, 2025: Breaking news ticker'da "SON DAKİKA" etiketinden sonra alan sınırlandırıldı - tasarım dengelendi
- July 5, 2025: Popup reklamlar için localStorage cache kaldırıldı - artık her sayfa yenilemesinde görünüyor
- July 5, 2025: Admin paneli body margin'ları kaldırıldı - tüm sayfa genişliğinde görünüm
- July 5, 2025: İyileştirilmiş breadcrumb (yol görünümü) tasarımı - gradient arkaplan, daha iyi görsel ayrım
- July 5, 2025: Admin panelinden üst banner ve alt banner reklam seçenekleri kaldırıldı - sadece kenar ve popup reklamlar
- July 5, 2025: Tüm sayfalara header elementleri eklendi (kategori, haber detay, arama, sabit sayfalar)
- July 5, 2025: Header elementleri tam ekran genişliğinde görünüm (header-top, main-header, main-nav, breaking-news, footer)
- June 26, 2025: Removed all previous deployment files and created single GitHub-based VPS installation
- June 26, 2025: Created github-vps-install.sh - one-command complete installation from GitHub repository
- June 26, 2025: Implemented Supervisor process management instead of systemd for better reliability
- June 26, 2025: Added comprehensive PostgreSQL setup with proper user permissions and database ownership
- June 26, 2025: Added README.md with clear installation instructions and system requirements
- June 26, 2025: Added GitHub token authentication support for private repository deployment
- June 26, 2025: Created github-token-install.sh with parameter-based token handling for secure installation
- June 26, 2025: Added comprehensive live stream management system with admin panel control
- June 26, 2025: Enhanced advertisement system with larger banners (160x400px) and improved clickability
- June 26, 2025: Fixed sidebar ad positioning conflicts - reduced z-index and added pointer-events controls
- June 26, 2025: Upgraded YouTube live player with professional error handling and multiple stream sources
- June 26, 2025: Updated video embed to TNax9QRxK40 for reliable TRT Haber live streaming
- June 26, 2025: Increased admin panel file upload limit from 2MB to 10MB for advertisement images
- June 26, 2025: Added automatic video error detection with retry functionality and alternative streams
- June 25, 2025: Redesigned advertisement system for vertical banners (120x300px)
- June 25, 2025: Fixed layout conflicts with widgets - ads now properly positioned
- June 25, 2025: Reduced to 2 slots per side to prevent design disruption
- June 25, 2025: Left ads positioned as fixed vertical banners outside main content
- June 25, 2025: Right ads integrated with sidebar widgets in proper layout
- June 25, 2025: Improved mobile responsiveness with conditional ad display
- June 25, 2025: Enhanced widget design for currency, weather, popular news, and prayer times
- June 25, 2025: Implemented comprehensive advertisement management system with admin panel
- June 25, 2025: Added sidebar ads (left/right positioning) and popup ads functionality  
- June 25, 2025: Created ad tracking system with click and impression analytics
- June 25, 2025: Added advertisement model with image upload and URL linking capabilities
- June 25, 2025: Integrated ads into homepage with responsive design and mobile support
- June 25, 2025: Fixed news detail page template errors - removed duplicate head blocks
- June 25, 2025: Reorganized navigation menu - moved Yerel Haberler to rightmost position
- June 25, 2025: Removed Yaşam and Çevre categories from navigation and homepage
- June 25, 2025: Fixed mini live player functionality completely - all buttons now working properly
- June 25, 2025: Added drag-and-drop functionality to mini player with viewport boundary constraints
- June 25, 2025: Implemented proper JavaScript event handling with preventDefault and stopPropagation
- June 24, 2025: Implemented personalized news recommendation engine with user behavior tracking
- June 24, 2025: Added "Size Özel Haberler" section with AI-powered recommendations
- June 24, 2025: User interaction tracking (views, clicks, scroll depth, reading time)
- June 24, 2025: Machine learning-based interest scoring and category preferences
- June 24, 2025: Real-time recommendation API endpoints
- June 24, 2025: Added YouTube live player with auto-start and toggle functionality (https://www.youtube.com/watch?v=TNax9QRxK40)
- June 24, 2025: Mini player shows at bottom-right, user can minimize/close/reopen
- June 24, 2025: Player state is remembered using localStorage
- June 24, 2025: Mobile responsive design for live player
- June 24, 2025: Fixed currency data display issue - now showing live rates
- June 24, 2025: Changed color scheme from red to subtle closed blue throughout the system
- June 24, 2025: Updated all UI elements, buttons, headers, and accents to use blue theme
- June 24, 2025: Added Instagram stories-style featured news section at top of homepage
- June 24, 2025: Implemented horizontal scrollable story cards with category badges and hover effects
- June 24, 2025: Created responsive design for both desktop and mobile story viewing
- June 24, 2025: Added navigation buttons for desktop story browsing
- June 24, 2025: Integrated featured news stories with existing news system
- June 24, 2025: Added interactive currency and gold price charts using Chart.js
- June 24, 2025: Implemented chart toggle functionality for both desktop and mobile currency widgets
- June 24, 2025: Created bar charts for desktop view and doughnut charts for mobile view
- June 24, 2025: Enhanced currency widget styling with hover effects and better layout
- June 24, 2025: Fixed navbar toggler icon color to white for better mobile visibility
- June 24, 2025: Fixed mobile category icons issue - added proper Font Awesome icons for all categories
- June 24, 2025: Enhanced mobile category layout with improved styling and hover effects
- June 24, 2025: Added category-specific icons (politics, economy, sports, tech, health, culture, world, local)
- June 23, 2025: Enhanced design with dynamic animations, improved mobile widget layout, and professional styling
- June 23, 2025: Added mobile-first widget system with top scroll bar for currency, weather, crypto, and prayer times
- June 23, 2025: Implemented advanced CSS animations, scroll-triggered effects, and enhanced card hover states
- June 23, 2025: Created comprehensive animation system with AOS library integration and custom keyframes
- June 23, 2025: Improved template structure with richer content, better loading states, and enhanced user experience
- June 23, 2025: Fixed persistent Nginx "http directive" error by removing invalid http wrapper from config files
- June 23, 2025: Created emergency-nginx-fix.sh script for direct server configuration repair
- June 23, 2025: Updated domain configuration for IP 69.62.110.158 and ayyildizajans.com
- June 23, 2025: Implemented dynamic environment configuration manager with web interface
- June 23, 2025: Added real-time configuration updates, validation, and import/export functionality
- June 23, 2025: Created admin config management pages with section-based organization
- June 23, 2025: Integrated configuration manager with Flask app initialization
- June 23, 2025: Fixed Nginx configuration error by removing invalid "http" directive from site config file
- June 23, 2025: Moved security headers inside server block for proper Nginx syntax compliance
- June 23, 2025: Fixed dependency conflict between lxml and trafilatura packages by using flexible version constraints
- June 23, 2025: Updated requirements.txt and pyproject.toml to use >= for lxml and trafilatura versions
- June 23, 2025: Fixed Yerel Haberler category image display issue by adding local file path support (/static/)
- June 23, 2025: Updated template logic to handle both local uploads and external image URLs properly
- June 23, 2025: Enhanced image fallback system for category pages with proper error handling
- June 23, 2025: Successfully implemented "Yerel Haberler" category for admin-only local news content
- June 23, 2025: Added navigation menu integration with special styling for local news category
- June 23, 2025: Implemented automatic SSL certificate generation with Let's Encrypt integration
- June 23, 2025: Created ssl-setup.sh script for one-command SSL installation with domain verification
- June 23, 2025: Added ssl-renew.sh and ssl-status.sh for automated renewal and monitoring

## Changelog
- June 23, 2025: Initial setup and deployment

## User Preferences

Preferred communication style: Simple, everyday language.