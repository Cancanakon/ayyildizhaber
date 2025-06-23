import re
import unicodedata
import time
from werkzeug.utils import secure_filename
from flask import current_app
from models import News
from app import db
import os
from datetime import datetime, timedelta
from bs4 import BeautifulSoup
import json

def create_slug(text):
    """Create URL-friendly slug from text"""
    if not text:
        return ""
    
    # Turkish character replacements
    replacements = {
        'ğ': 'g', 'Ğ': 'G',
        'ü': 'u', 'Ü': 'U',
        'ş': 's', 'Ş': 'S',
        'ı': 'i', 'İ': 'I',
        'ö': 'o', 'Ö': 'O',
        'ç': 'c', 'Ç': 'C'
    }
    
    # Replace Turkish characters
    for tr_char, en_char in replacements.items():
        text = text.replace(tr_char, en_char)
    
    # Convert to lowercase and create slug
    text = text.lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_-]+', '-', text)
    text = text.strip('-')
    
    # Ensure uniqueness
    base_slug = text[:50]  # Limit length
    slug = base_slug
    counter = 1
    
    while News.query.filter_by(slug=slug).first():
        slug = f"{base_slug}-{counter}"
        counter += 1
    
    return slug

def clean_html_content(content):
    """Clean HTML content and return plain text"""
    if not content:
        return ""
    
    # Parse HTML
    soup = BeautifulSoup(content, 'html.parser')
    
    # Remove script and style elements
    for script in soup(["script", "style"]):
        script.decompose()
    
    # Remove img tags and other unwanted elements
    for tag in soup(['img', 'figure', 'iframe', 'video', 'audio']):
        tag.decompose()
    
    # Get text content
    text = soup.get_text()
    
    # Clean whitespace and newlines
    lines = (line.strip() for line in text.splitlines())
    chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
    text = ' '.join(chunk for chunk in chunks if chunk)
    
    # Remove extra whitespace
    text = ' '.join(text.split())
    
    return text

def allowed_file(filename):
    """Check if file extension is allowed"""
    allowed_extensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'mp4', 'avi', 'mov'}
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in allowed_extensions

def save_uploaded_file(file, subfolder='images'):
    """Save uploaded file and return the path"""
    if not file or not allowed_file(file.filename):
        return None
    
    filename = secure_filename(file.filename)
    
    # Add timestamp to avoid conflicts
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_')
    filename = timestamp + filename
    
    # Create upload directory
    upload_path = os.path.join(current_app.config['UPLOAD_FOLDER'], subfolder)
    os.makedirs(upload_path, exist_ok=True)
    
    # Save file
    file_path = os.path.join(upload_path, filename)
    file.save(file_path)
    
    # Return relative path for database storage
    return f"/static/uploads/{subfolder}/{filename}"

def get_popular_news(limit=5, days=7):
    """Get most popular news in the last N days"""
    try:
        days_ago = datetime.utcnow() - timedelta(days=days)
        
        # First try to get popular news from last week
        popular = News.query.filter(
            News.published_at >= days_ago,
            News.status == 'published'
        ).order_by(News.view_count.desc()).limit(limit).all()
        
        # If not enough popular news, get recent news
        if len(popular) < limit:
            recent = News.query.filter(
                News.status == 'published'
            ).order_by(News.published_at.desc()).limit(limit * 2).all()
            
            # Combine and deduplicate
            popular_ids = [n.id for n in popular]
            for news in recent:
                if news.id not in popular_ids and len(popular) < limit:
                    popular.append(news)
        
        return popular[:limit]
    except Exception as e:
        print(f"Error getting popular news: {e}")
        # Return recent news as fallback
        try:
            return News.query.filter(
                News.status == 'published'
            ).order_by(News.published_at.desc()).limit(limit).all()
        except:
            return []

def format_date(date, format_type='full'):
    """Format date for display"""
    if not date:
        return ""
    
    # Turkish month names
    months = [
        'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ]
    
    if format_type == 'full':
        return f"{date.day} {months[date.month-1]} {date.year}"
    elif format_type == 'short':
        return f"{date.day}.{date.month}.{date.year}"
    elif format_type == 'time':
        return date.strftime('%H:%M')
    else:
        return date.strftime('%d.%m.%Y %H:%M')

def truncate_text(text, length=100):
    """Truncate text to specified length"""
    if not text:
        return ""
    
    if len(text) <= length:
        return text
    
    return text[:length].rsplit(' ', 1)[0] + '...'

def get_reading_time(content):
    """Calculate estimated reading time"""
    if not content:
        return 0
    
    words = len(content.split())
    # Average reading speed: 200 words per minute
    minutes = max(1, round(words / 200))
    return minutes

def generate_breadcrumb(category=None, news=None):
    """Generate breadcrumb navigation"""
    breadcrumb = [{'name': 'Ana Sayfa', 'url': '/'}]
    
    if category:
        breadcrumb.append({
            'name': category.name,
            'url': f'/kategori/{category.slug}'
        })
    
    if news:
        breadcrumb.append({
            'name': news.title,
            'url': f'/haber/{news.slug}',
            'active': True
        })
    
    return breadcrumb

def get_related_news(news, limit=5):
    """Get related news based on category and tags"""
    try:
        related = News.query.filter(
            News.category_id == news.category_id,
            News.id != news.id,
            News.status == 'published'
        ).order_by(News.published_at.desc()).limit(limit).all()
        
        return related
    except Exception as e:
        print(f"Error getting related news: {e}")
        return []

# Template filters
def highlight_search(text, query):
    """Highlight search terms in text"""
    if not query or not text:
        return text
    
    # Split query into words and highlight each
    words = query.split()
    highlighted_text = str(text)
    
    for word in words:
        if len(word) > 2:  # Only highlight words longer than 2 characters
            pattern = re.compile(re.escape(word), re.IGNORECASE)
            highlighted_text = pattern.sub(f'<mark class="bg-warning">{word}</mark>', highlighted_text)
    
    return highlighted_text

def from_json(json_string):
    """Parse JSON string to Python object"""
    try:
        if not json_string or json_string == '[]':
            return []
        return json.loads(json_string)
    except:
        return []

# Register template filters
def register_template_filters(app):
    """Register custom template filters"""
    app.jinja_env.filters['highlight_search'] = highlight_search
    app.jinja_env.filters['from_json'] = from_json
    app.jinja_env.filters['format_date'] = format_date
    app.jinja_env.filters['truncate_text'] = truncate_text
    
    # Add moment-like functionality for templates
    app.jinja_env.globals['moment'] = lambda: type('moment', (), {
        'year': datetime.now().year,
        'format': lambda fmt: datetime.now().strftime(fmt)
    })()

# News statistics helpers
def get_news_statistics():
    """Get comprehensive news statistics"""
    try:
        from models import NewsView
        
        total_news = News.query.count()
        published_news = News.query.filter_by(status='published').count()
        draft_news = News.query.filter_by(status='draft').count()
        
        # Get total views
        total_views = db.session.query(db.func.sum(News.view_count)).scalar() or 0
        
        # Get daily views for last 30 days
        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        daily_views = db.session.query(
            db.func.date(NewsView.viewed_at).label('date'),
            db.func.count(NewsView.id).label('views')
        ).filter(NewsView.viewed_at >= thirty_days_ago).group_by(
            db.func.date(NewsView.viewed_at)
        ).order_by(db.text('date DESC')).all()
        
        return {
            'total_news': total_news,
            'published_news': published_news,
            'draft_news': draft_news,
            'total_views': total_views,
            'daily_views': daily_views,
            'avg_views_per_news': (total_views / published_news) if published_news > 0 else 0
        }
    except Exception as e:
        print(f"Error getting news statistics: {e}")
        return {
            'total_news': 0,
            'published_news': 0,
            'draft_news': 0,
            'total_views': 0,
            'daily_views': [],
            'avg_views_per_news': 0
        }

# Cache management
def clear_cache_files():
    """Clear old cache files"""
    cache_dirs = ['cache', 'static/cache']
    
    for cache_dir in cache_dirs:
        if os.path.exists(cache_dir):
            try:
                for filename in os.listdir(cache_dir):
                    file_path = os.path.join(cache_dir, filename)
                    if os.path.isfile(file_path):
                        # Remove files older than 24 hours
                        file_age = time.time() - os.path.getmtime(file_path)
                        if file_age > 24 * 60 * 60:  # 24 hours
                            os.remove(file_path)
                            print(f"Removed old cache file: {file_path}")
            except Exception as e:
                print(f"Error clearing cache: {e}")

# URL helpers
def build_url(endpoint, **kwargs):
    """Build URL for given endpoint with parameters"""
    try:
        from flask import url_for
        return url_for(endpoint, **kwargs)
    except:
        return '#'

# SEO helpers
def generate_meta_description(content, length=160):
    """Generate meta description from content"""
    if not content:
        return "Ayyıldız Haber Ajansı - Türkiye'nin güvenilir haber kaynağı"
    
    # Clean and truncate content
    clean_content = clean_html_content(content)
    if len(clean_content) <= length:
        return clean_content
    
    # Truncate at word boundary
    truncated = clean_content[:length]
    last_space = truncated.rfind(' ')
    if last_space > 0:
        truncated = truncated[:last_space]
    
    return truncated + '...'

def generate_keywords(title, content, category_name=None):
    """Generate keywords from title and content"""
    keywords = []
    
    if title:
        keywords.extend(title.lower().split())
    
    if category_name:
        keywords.append(category_name.lower())
    
    # Add common Turkish news keywords
    common_keywords = ['haber', 'türkiye', 'son dakika', 'güncel', 'haberler']
    keywords.extend(common_keywords)
    
    # Remove duplicates and limit to 10 keywords
    unique_keywords = list(dict.fromkeys(keywords))[:10]
    
    return ', '.join(unique_keywords)
