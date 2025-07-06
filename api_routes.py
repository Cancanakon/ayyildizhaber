"""
Mobile API Routes for Ayyıldız Haber Ajansı
Comprehensive API endpoints for mobile application integration
"""

from flask import Blueprint, jsonify, request, g
from sqlalchemy import desc, func, and_, or_
from datetime import datetime, timedelta
import json
from werkzeug.exceptions import NotFound

from app import db
from models import News, Category, Advertisement, LiveStreamSettings, NewsView, UserSession, UserInteraction
from services.currency_service import get_currency_data
from services.weather_service import get_weather_data
from services.prayer_service import get_prayer_times
from services.recommendation_engine import NewsRecommendationEngine

api_bp = Blueprint('api', __name__, url_prefix='/api/v1')

# API Key validation (simple implementation)
def validate_api_key():
    """Validate API key for mobile app access"""
    api_key = request.headers.get('X-API-Key')
    if not api_key or api_key != 'ayyildizhaber_mobile_2025':
        return False
    return True

def api_key_required(f):
    """Decorator to require API key"""
    def decorated_function(*args, **kwargs):
        if not validate_api_key():
            return jsonify({'error': 'Invalid or missing API key'}), 401
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__
    return decorated_function

def paginate_query(query, page=1, per_page=20):
    """Helper function for pagination"""
    try:
        page = int(request.args.get('page', page))
        per_page = min(int(request.args.get('per_page', per_page)), 100)  # Max 100 per page
    except ValueError:
        page = 1
        per_page = 20
    
    total = query.count()
    items = query.offset((page - 1) * per_page).limit(per_page).all()
    
    return {
        'items': items,
        'pagination': {
            'page': page,
            'per_page': per_page,
            'total': total,
            'pages': (total + per_page - 1) // per_page
        }
    }

# NEWS ENDPOINTS
@api_bp.route('/news', methods=['GET'])
@api_key_required
def get_news():
    """Get all news with pagination and filtering"""
    query = News.query.filter_by(status='published')
    
    # Filtering
    category_id = request.args.get('category_id')
    if category_id:
        query = query.filter_by(category_id=category_id)
    
    is_featured = request.args.get('is_featured')
    if is_featured:
        query = query.filter_by(is_featured=True)
    
    is_breaking = request.args.get('is_breaking')
    if is_breaking:
        query = query.filter_by(is_breaking=True)
    
    # Search
    search = request.args.get('search')
    if search:
        query = query.filter(
            or_(
                News.title.ilike(f'%{search}%'),
                News.content.ilike(f'%{search}%'),
                News.summary.ilike(f'%{search}%')
            )
        )
    
    # Ordering
    query = query.order_by(desc(News.published_at))
    
    # Pagination
    result = paginate_query(query)
    
    return jsonify({
        'success': True,
        'data': {
            'news': [news.to_dict() for news in result['items']],
            'pagination': result['pagination']
        }
    })

@api_bp.route('/news/<int:news_id>', methods=['GET'])
@api_key_required
def get_news_detail(news_id):
    """Get single news article detail"""
    news = News.query.filter_by(id=news_id, status='published').first()
    if not news:
        return jsonify({'error': 'News not found'}), 404
    
    # Increment view count
    news.increment_view_count()
    
    # Track view for mobile
    ip_address = request.remote_addr
    user_agent = request.headers.get('User-Agent', '')
    
    news_view = NewsView(
        news_id=news_id,
        ip_address=ip_address,
        user_agent=user_agent
    )
    db.session.add(news_view)
    db.session.commit()
    
    return jsonify({
        'success': True,
        'data': {
            'news': news.to_dict(),
            'related_news': [n.to_dict() for n in get_related_news(news, limit=5)]
        }
    })

@api_bp.route('/news/slug/<slug>', methods=['GET'])
@api_key_required
def get_news_by_slug(slug):
    """Get news by slug"""
    news = News.query.filter_by(slug=slug, status='published').first()
    if not news:
        return jsonify({'error': 'News not found'}), 404
    
    # Increment view count
    news.increment_view_count()
    
    return jsonify({
        'success': True,
        'data': {
            'news': news.to_dict(),
            'related_news': [n.to_dict() for n in get_related_news(news, limit=5)]
        }
    })

def get_related_news(news, limit=5):
    """Get related news based on category"""
    return News.query.filter(
        and_(
            News.category_id == news.category_id,
            News.id != news.id,
            News.status == 'published'
        )
    ).order_by(desc(News.published_at)).limit(limit).all()

# CATEGORY ENDPOINTS
@api_bp.route('/categories', methods=['GET'])
@api_key_required
def get_categories():
    """Get all active categories"""
    categories = Category.query.filter_by(is_active=True).all()
    
    return jsonify({
        'success': True,
        'data': {
            'categories': [category.to_dict() for category in categories]
        }
    })

@api_bp.route('/categories/<int:category_id>/news', methods=['GET'])
@api_key_required
def get_category_news(category_id):
    """Get news by category"""
    category = Category.query.filter_by(id=category_id, is_active=True).first()
    if not category:
        return jsonify({'error': 'Category not found'}), 404
    
    query = News.query.filter_by(category_id=category_id, status='published')
    query = query.order_by(desc(News.published_at))
    
    result = paginate_query(query)
    
    return jsonify({
        'success': True,
        'data': {
            'category': category.to_dict(),
            'news': [news.to_dict() for news in result['items']],
            'pagination': result['pagination']
        }
    })

# FEATURED & BREAKING NEWS
@api_bp.route('/news/featured', methods=['GET'])
@api_key_required
def get_featured_news():
    """Get featured news"""
    limit = min(int(request.args.get('limit', 10)), 50)
    
    news = News.query.filter_by(
        is_featured=True, 
        status='published'
    ).order_by(desc(News.published_at)).limit(limit).all()
    
    return jsonify({
        'success': True,
        'data': {
            'news': [n.to_dict() for n in news]
        }
    })

@api_bp.route('/news/breaking', methods=['GET'])
@api_key_required
def get_breaking_news():
    """Get breaking news"""
    limit = min(int(request.args.get('limit', 5)), 20)
    
    news = News.query.filter_by(
        is_breaking=True, 
        status='published'
    ).order_by(desc(News.published_at)).limit(limit).all()
    
    return jsonify({
        'success': True,
        'data': {
            'news': [n.to_dict() for n in news]
        }
    })

# SEARCH ENDPOINT
@api_bp.route('/search', methods=['GET'])
@api_key_required
def search_news():
    """Search news articles"""
    query_text = request.args.get('q', '').strip()
    if not query_text:
        return jsonify({'error': 'Search query is required'}), 400
    
    if len(query_text) < 3:
        return jsonify({'error': 'Search query must be at least 3 characters'}), 400
    
    query = News.query.filter(
        and_(
            News.status == 'published',
            or_(
                News.title.ilike(f'%{query_text}%'),
                News.content.ilike(f'%{query_text}%'),
                News.summary.ilike(f'%{query_text}%')
            )
        )
    ).order_by(desc(News.published_at))
    
    result = paginate_query(query)
    
    return jsonify({
        'success': True,
        'data': {
            'query': query_text,
            'news': [news.to_dict() for news in result['items']],
            'pagination': result['pagination']
        }
    })

# WIDGETS DATA
@api_bp.route('/widgets/currency', methods=['GET'])
@api_key_required
def get_currency_widget():
    """Get currency data"""
    try:
        currency_data = get_currency_data()
        return jsonify({
            'success': True,
            'data': currency_data
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_bp.route('/widgets/weather', methods=['GET'])
@api_key_required
def get_weather_widget():
    """Get weather data"""
    try:
        weather_data = get_weather_data()
        return jsonify({
            'success': True,
            'data': weather_data
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_bp.route('/widgets/prayer', methods=['GET'])
@api_key_required
def get_prayer_widget():
    """Get prayer times"""
    try:
        prayer_data = get_prayer_times()
        return jsonify({
            'success': True,
            'data': prayer_data
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# ADVERTISEMENTS
@api_bp.route('/ads', methods=['GET'])
@api_key_required
def get_advertisements():
    """Get active advertisements"""
    ad_type = request.args.get('type')  # sidebar, popup
    
    query = Advertisement.query.filter_by(is_active=True)
    
    if ad_type:
        query = query.filter_by(ad_type=ad_type)
    
    ads = query.all()
    
    return jsonify({
        'success': True,
        'data': {
            'ads': [ad.to_dict() for ad in ads]
        }
    })

@api_bp.route('/ads/<int:ad_id>/click', methods=['POST'])
@api_key_required
def track_ad_click(ad_id):
    """Track advertisement click"""
    ad = Advertisement.query.get(ad_id)
    if not ad:
        return jsonify({'error': 'Advertisement not found'}), 404
    
    ad.increment_clicks()
    db.session.commit()
    
    return jsonify({
        'success': True,
        'data': {
            'ad_id': ad_id,
            'click_count': ad.click_count
        }
    })

@api_bp.route('/ads/<int:ad_id>/impression', methods=['POST'])
@api_key_required
def track_ad_impression(ad_id):
    """Track advertisement impression"""
    ad = Advertisement.query.get(ad_id)
    if not ad:
        return jsonify({'error': 'Advertisement not found'}), 404
    
    ad.increment_impressions()
    db.session.commit()
    
    return jsonify({
        'success': True,
        'data': {
            'ad_id': ad_id,
            'impression_count': ad.impression_count
        }
    })

# LIVE STREAM
@api_bp.route('/live-stream', methods=['GET'])
@api_key_required
def get_live_stream():
    """Get active live stream"""
    stream = LiveStreamSettings.query.filter_by(is_active=True).first()
    
    if not stream:
        return jsonify({
            'success': True,
            'data': {
                'stream': None
            }
        })
    
    return jsonify({
        'success': True,
        'data': {
            'stream': stream.to_dict()
        }
    })

# RECOMMENDATIONS
@api_bp.route('/recommendations', methods=['GET'])
@api_key_required
def get_recommendations():
    """Get personalized recommendations"""
    try:
        engine = NewsRecommendationEngine()
        
        # Create or get session for mobile user
        session_id = request.headers.get('X-Session-ID')
        if not session_id:
            # Generate session based on device info
            device_id = request.headers.get('X-Device-ID', '')
            user_agent = request.headers.get('User-Agent', '')
            session_id = f"mobile_{device_id}_{hash(user_agent)}"
        
        limit = min(int(request.args.get('limit', 10)), 50)
        
        # Get or create session
        session = UserSession.query.filter_by(session_id=session_id).first()
        if not session:
            session = UserSession(
                session_id=session_id,
                ip_address=request.remote_addr,
                user_agent=request.headers.get('User-Agent', '')
            )
            db.session.add(session)
            db.session.commit()
        
        recommendations = engine.get_recommended_news(session_id, limit=limit)
        
        return jsonify({
            'success': True,
            'data': {
                'recommendations': [news.to_dict() for news in recommendations],
                'session_id': session_id
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# INTERACTION TRACKING
@api_bp.route('/track/interaction', methods=['POST'])
@api_key_required
def track_interaction():
    """Track user interaction for personalization"""
    try:
        data = request.get_json()
        
        session_id = data.get('session_id')
        news_id = data.get('news_id')
        interaction_type = data.get('interaction_type', 'view')
        duration = data.get('duration', 0)
        scroll_depth = data.get('scroll_depth', 0.0)
        
        if not session_id or not news_id:
            return jsonify({'error': 'session_id and news_id are required'}), 400
        
        engine = NewsRecommendationEngine()
        engine.track_interaction(session_id, news_id, interaction_type, duration, scroll_depth)
        
        return jsonify({
            'success': True,
            'data': {
                'message': 'Interaction tracked successfully'
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# STATISTICS
@api_bp.route('/stats/popular', methods=['GET'])
@api_key_required
def get_popular_news():
    """Get popular news based on view counts"""
    limit = min(int(request.args.get('limit', 10)), 50)
    days = min(int(request.args.get('days', 7)), 30)
    
    date_threshold = datetime.utcnow() - timedelta(days=days)
    
    popular_news = db.session.query(
        News,
        func.count(NewsView.id).label('view_count')
    ).join(
        NewsView, News.id == NewsView.news_id
    ).filter(
        and_(
            News.status == 'published',
            NewsView.viewed_at >= date_threshold
        )
    ).group_by(News.id).order_by(
        desc('view_count')
    ).limit(limit).all()
    
    return jsonify({
        'success': True,
        'data': {
            'popular_news': [
                {
                    **news.to_dict(),
                    'view_count': view_count
                }
                for news, view_count in popular_news
            ],
            'period_days': days
        }
    })

# HOMEPAGE DATA
@api_bp.route('/homepage', methods=['GET'])
@api_key_required
def get_homepage_data():
    """Get all homepage data in single request"""
    try:
        # Breaking news
        breaking_news = News.query.filter_by(
            is_breaking=True, 
            status='published'
        ).order_by(desc(News.published_at)).limit(5).all()
        
        # Featured news
        featured_news = News.query.filter_by(
            is_featured=True, 
            status='published'
        ).order_by(desc(News.published_at)).limit(8).all()
        
        # Latest news
        latest_news = News.query.filter_by(
            status='published'
        ).order_by(desc(News.published_at)).limit(12).all()
        
        # Categories with news counts
        categories = db.session.query(
            Category,
            func.count(News.id).label('news_count')
        ).outerjoin(
            News, and_(
                Category.id == News.category_id,
                News.status == 'published'
            )
        ).filter(
            Category.is_active == True
        ).group_by(Category.id).all()
        
        # Active live stream
        live_stream = LiveStreamSettings.query.filter_by(is_active=True).first()
        
        return jsonify({
            'success': True,
            'data': {
                'breaking_news': [news.to_dict() for news in breaking_news],
                'featured_news': [news.to_dict() for news in featured_news],
                'latest_news': [news.to_dict() for news in latest_news],
                'categories': [
                    {
                        **category.to_dict(),
                        'news_count': news_count
                    }
                    for category, news_count in categories
                ],
                'live_stream': live_stream.to_dict() if live_stream else None
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# API INFO
@api_bp.route('/info', methods=['GET'])
def get_api_info():
    """Get API information"""
    return jsonify({
        'success': True,
        'data': {
            'name': 'Ayyıldız Haber Ajansı API',
            'version': '1.0',
            'description': 'Mobile API for news and content delivery',
            'endpoints': {
                'news': '/api/v1/news',
                'categories': '/api/v1/categories',
                'search': '/api/v1/search',
                'widgets': '/api/v1/widgets/{currency|weather|prayer}',
                'ads': '/api/v1/ads',
                'live_stream': '/api/v1/live-stream',
                'recommendations': '/api/v1/recommendations',
                'homepage': '/api/v1/homepage'
            },
            'authentication': 'API Key required in X-API-Key header'
        }
    })

# Add to_dict methods to models if not exists
def add_to_dict_methods():
    """Add to_dict methods to models"""
    
    def news_to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'slug': self.slug,
            'summary': self.summary,
            'content': self.content,
            'featured_image': self.featured_image,
            'images': json.loads(self.images) if self.images else [],
            'videos': json.loads(self.videos) if self.videos else [],
            'source': self.source,
            'source_url': self.source_url,
            'author': self.author,
            'status': self.status,
            'is_featured': self.is_featured,
            'is_breaking': self.is_breaking,
            'published_at': self.published_at.isoformat() if self.published_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'view_count': self.view_count,
            'category_id': self.category_id,
            'category': self.category.to_dict() if self.category else None
        }
    
    def category_to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'slug': self.slug,
            'description': self.description,
            'color': self.color,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
    
    def live_stream_to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'youtube_url': self.youtube_url,
            'youtube_video_id': self.youtube_video_id,
            'embed_url': self.get_embed_url(),
            'is_active': self.is_active,
            'is_default': self.is_default,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
    
    # Add methods to models
    if not hasattr(News, 'to_dict'):
        News.to_dict = news_to_dict
    
    if not hasattr(Category, 'to_dict'):
        Category.to_dict = category_to_dict
    
    if not hasattr(LiveStreamSettings, 'to_dict'):
        LiveStreamSettings.to_dict = live_stream_to_dict

# Initialize methods
add_to_dict_methods()