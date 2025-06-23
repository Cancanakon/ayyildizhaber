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
- June 23, 2025: Enhanced image extraction for news sources (NTV, Donanimhaber) with multiple fallback methods
- June 23, 2025: Improved homepage image display with better URL handling and fallback logic
- June 23, 2025: Replaced TinyMCE with Quill.js (free rich text editor, no API key required)
- June 23, 2025: Removed categories and users management from admin panel per user request
- June 23, 2025: Comprehensive image display fix across all templates (homepage, category, search, admin, news detail)
- June 23, 2025: Enhanced protocol-relative URL handling (// prefixed URLs)
- June 23, 2025: Standardized logo fallback implementation across all image references
- June 23, 2025: Added Turkish translations for gold prices (Çeyrek Altın, Yarım Altın, Tam Altın)
- June 23, 2025: Fixed currency service to use Kapali Carsi API for accurate Turkish market data
- June 23, 2025: Adjusted logo size to optimal 52px after user feedback iterations
- June 23, 2025: Added official logo to website header with proper integration

## Changelog
- June 23, 2025: Initial setup and deployment

## User Preferences

Preferred communication style: Simple, everyday language.