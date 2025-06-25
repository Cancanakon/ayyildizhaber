from flask import Blueprint, render_template, request, redirect, url_for, flash, jsonify
from models import News, Category, NewsView, SiteStatistics
from app import db
from services.currency_service import get_currency_data
from services.weather_service import get_weather_data
from services.prayer_service import get_prayer_times
from services.recommendation_engine import recommendation_engine
from utils.helpers import create_slug, get_popular_news
from datetime import datetime
import json

main_bp = Blueprint('main', __name__)

@main_bp.route('/')
def index():
    # Get slider news (15 latest published news for slider)
    slider_news = News.query.filter_by(status='published').order_by(News.published_at.desc()).limit(15).all()
    
    # Get featured and breaking news
    breaking_news = News.query.filter_by(is_breaking=True, status='published').order_by(News.published_at.desc()).limit(3).all()
    featured_news = News.query.filter_by(is_featured=True, status='published').order_by(News.published_at.desc()).limit(6).all()
    
    # If no featured news, get latest news (excluding slider news to avoid duplication)
    if not featured_news:
        slider_ids = [news.id for news in slider_news]
        featured_news = News.query.filter_by(status='published').filter(~News.id.in_(slider_ids)).order_by(News.published_at.desc()).limit(6).all()
    
    # Get latest news by category
    categories = Category.query.filter_by(is_active=True).all()
    latest_news = News.query.filter_by(status='published').order_by(News.published_at.desc()).limit(12).all()
    
    # Yerel haberler (sadece manuel eklenenler)
    yerel_news = News.query.join(Category).filter(
        Category.slug == 'yerel-haberler',
        News.status == 'published',
        News.source == 'manual'
    ).order_by(News.published_at.desc()).limit(4).all()
    
    # Get popular news
    popular_news = get_popular_news(limit=5)
    
    # Get or create user session for recommendations
    user_session = recommendation_engine.get_or_create_session(request)
    
    # Get personalized recommendations
    recommended_news = []
    if user_session:
        recommended_news = recommendation_engine.get_recommended_news(
            user_session.session_id, 
            limit=6,
            exclude_ids=[news.id for news in latest_news[:3]]  # Exclude already shown news
        )
    
    # Get external data - force fresh data
    try:
        # Clear cache and get fresh data
        import os
        cache_file = 'cache/currency_data.json'
        if os.path.exists(cache_file):
            os.remove(cache_file)
        
        currency_data = get_currency_data()
        weather_data = get_weather_data()
        prayer_data = get_prayer_times()
        
        # Debug: print what we got
        print(f"Currency data in routes: {currency_data}")
        
    except Exception as e:
        print(f"Error fetching external data: {e}")
        currency_data = weather_data = prayer_data = None
    
    return render_template('index.html',
                         slider_news=slider_news,
                         breaking_news=breaking_news,
                         featured_news=featured_news,
                         latest_news=latest_news,
                         yerel_news=yerel_news,
                         popular_news=popular_news,
                         recommended_news=recommended_news,
                         categories=categories,
                         currency_data=currency_data,
                         weather_data=weather_data,
                         prayer_data=prayer_data,
                         sidebar_ads=sidebar_ads,
                         popup_ads=popup_ads)

@main_bp.route('/haber/<slug>')
def news_detail(slug):
    news = News.query.filter_by(slug=slug, status='published').first_or_404()
    
    # Record view
    ip_address = request.environ.get('HTTP_X_REAL_IP', request.remote_addr)
    user_agent = request.headers.get('User-Agent', '')
    
    # Check if this IP has viewed this news in the last hour to prevent spam
    recent_view = NewsView.query.filter_by(
        news_id=news.id,
        ip_address=ip_address
    ).filter(NewsView.viewed_at > datetime.utcnow().replace(hour=datetime.utcnow().hour-1)).first()
    
    if not recent_view:
        view = NewsView(news_id=news.id, ip_address=ip_address, user_agent=user_agent)
        db.session.add(view)
        news.increment_view_count()
        
        # Track interaction for recommendation engine
        user_session = recommendation_engine.get_or_create_session(request)
        if user_session:
            recommendation_engine.track_interaction(
                user_session.session_id, 
                news.id, 
                'view'
            )
    
    # Get related news
    related_news = News.query.filter(
        News.category_id == news.category_id,
        News.id != news.id,
        News.status == 'published'
    ).order_by(News.published_at.desc()).limit(5).all()
    
    # Get popular news for sidebar
    popular_news = get_popular_news(limit=5)
    
    # Parse images and videos
    images = json.loads(news.images) if news.images else []
    videos = json.loads(news.videos) if news.videos else []
    
    # Get personalized recommendations for this user
    user_session = recommendation_engine.get_or_create_session(request)
    recommended_news = []
    if user_session:
        recommended_news = recommendation_engine.get_recommended_news(
            user_session.session_id,
            limit=4,
            exclude_ids=[news.id] + [r.id for r in related_news]
        )
    
    return render_template('news_detail.html',
                         news=news,
                         related_news=related_news,
                         popular_news=popular_news,
                         recommended_news=recommended_news,
                         images=images,
                         videos=videos)

@main_bp.route('/kategori/<slug>')
def category_news(slug):
    page = request.args.get('page', 1, type=int)
    category = Category.query.filter_by(slug=slug, is_active=True).first_or_404()
    
    # Yerel Haberler kategorisi için sadece manuel haberleri göster
    if slug == 'yerel-haberler':
        news_query = News.query.filter_by(
            category_id=category.id,
            status='published',
            source='manual'  # Sadece admin panelinden eklenen haberler
        ).order_by(News.published_at.desc())
    else:
        news_query = News.query.filter_by(
            category_id=category.id,
            status='published'
        ).order_by(News.published_at.desc())
    
    news = news_query.paginate(
        page=page, per_page=12, error_out=False
    )
    
    # Get other categories
    other_categories = Category.query.filter(
        Category.id != category.id,
        Category.is_active == True
    ).all()
    
    # Get recent news from other categories
    recent_news = News.query.filter(
        News.category_id != category.id,
        News.status == 'published'
    ).order_by(News.published_at.desc()).limit(5).all()
    
    # Get popular news
    popular_news = get_popular_news(limit=5)
    
    return render_template('category.html',
                         category=category,
                         news=news,
                         other_categories=other_categories,
                         recent_news=recent_news,
                         popular_news=popular_news)

@main_bp.route('/arama')
def search():
    query = request.args.get('q', '')
    page = request.args.get('page', 1, type=int)
    
    if query:
        news_query = News.query.filter(
            News.title.contains(query) | News.content.contains(query),
            News.status == 'published'
        ).order_by(News.published_at.desc())
        
        news = news_query.paginate(
            page=page, per_page=12, error_out=False
        )
    else:
        news = None
    
    return render_template('search.html', news=news, query=query)

@main_bp.route('/api/currency')
def api_currency():
    """API endpoint for currency data"""
    try:
        from services.currency_service import get_currency_data
        data = get_currency_data()
        if data:
            return jsonify(data)
        else:
            return jsonify({'error': 'Currency data not available'}), 500
    except Exception as e:
        logging.error(f"Currency API error: {e}")
        return jsonify({'error': str(e)}), 500

@main_bp.route('/api/weather')
def api_weather():
    """API endpoint for weather data"""
    try:
        data = get_weather_data()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@main_bp.route('/api/prayer')
def api_prayer():
    """API endpoint for prayer times"""
    try:
        data = get_prayer_times()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Footer Pages
@main_bp.route('/hakkimizda')
def about():
    return render_template('pages/about.html')

@main_bp.route('/iletisim')
def contact():
    return render_template('pages/contact.html')

@main_bp.route('/reklam')
def advertising():
    return render_template('pages/advertising.html')

@main_bp.route('/gizlilik-politikasi')
def privacy():
    return render_template('pages/privacy.html')

@main_bp.route('/kullanim-sartlari')
def terms():
    return render_template('pages/terms.html')

# Recommendation Engine API Endpoints
@main_bp.route('/api/track-interaction', methods=['POST'])
def track_interaction():
    """API endpoint to track user interactions"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Get user session
        user_session = recommendation_engine.get_or_create_session(request)
        if not user_session:
            return jsonify({'error': 'Could not create session'}), 500
        
        # Track interaction
        success = recommendation_engine.track_interaction(
            user_session.session_id,
            data.get('news_id'),
            data.get('interaction_type', 'view'),
            data.get('duration', 0),
            data.get('scroll_depth', 0.0)
        )
        
        if success:
            return jsonify({'status': 'success'})
        else:
            return jsonify({'error': 'Failed to track interaction'}), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@main_bp.route('/api/recommendations')
def get_recommendations():
    """API endpoint to get personalized recommendations"""
    try:
        user_session = recommendation_engine.get_or_create_session(request)
        if not user_session:
            return jsonify({'recommendations': []})
        
        limit = int(request.args.get('limit', 5))
        exclude_ids = request.args.getlist('exclude_ids', type=int)
        
        recommendations = recommendation_engine.get_recommended_news(
            user_session.session_id,
            limit=limit,
            exclude_ids=exclude_ids
        )
        
        # Convert to JSON format
        rec_data = []
        for news in recommendations:
            rec_data.append({
                'id': news.id,
                'title': news.title,
                'slug': news.slug,
                'summary': news.summary,
                'category': news.category.name,
                'published_at': news.published_at.isoformat() if news.published_at else None,
                'featured_image': news.featured_image,
                'view_count': news.view_count
            })
        
        return jsonify({'recommendations': rec_data})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@main_bp.route('/api/user-interests')
def get_user_interests():
    """API endpoint to get user interests"""
    try:
        user_session = recommendation_engine.get_or_create_session(request)
        if not user_session:
            return jsonify({'interests': {}})
        
        interests = recommendation_engine.get_user_interests(user_session.session_id)
        return jsonify({'interests': interests})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@main_bp.route('/api/track-ad-click', methods=['POST'])
def track_ad_click():
    """Track advertisement clicks"""
    try:
        data = request.get_json()
        ad_id = data.get('ad_id')
        
        from models import Advertisement
        ad = Advertisement.query.get(ad_id)
        if ad:
            ad.increment_clicks()
            return jsonify({'status': 'success'})
        
        return jsonify({'error': 'Ad not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@main_bp.route('/api/track-ad-impression', methods=['POST'])
def track_ad_impression():
    """Track advertisement impressions"""
    try:
        data = request.get_json()
        ad_id = data.get('ad_id')
        
        from models import Advertisement
        ad = Advertisement.query.get(ad_id)
        if ad:
            ad.increment_impressions()
            return jsonify({'status': 'success'})
        
        return jsonify({'error': 'Ad not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500
