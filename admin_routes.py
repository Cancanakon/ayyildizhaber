from flask import Blueprint, render_template, request, redirect, url_for, flash, current_app, jsonify
from flask_login import login_user, logout_user, login_required, current_user
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename
from models import Admin, News, Category, NewsView, SiteStatistics
from app import db
from utils.helpers import create_slug, allowed_file, save_uploaded_file
from datetime import datetime, timedelta
import json
import os

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('admin.dashboard'))
    
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')
        
        admin = Admin.query.filter_by(email=email, is_active=True).first()
        
        if admin and check_password_hash(admin.password_hash, password):
            login_user(admin, remember=True)
            admin.last_login = datetime.utcnow()
            db.session.commit()
            
            next_page = request.args.get('next')
            return redirect(next_page) if next_page else redirect(url_for('admin.dashboard'))
        else:
            flash('Geçersiz email veya şifre', 'error')
    
    return render_template('admin/login.html')

@admin_bp.route('/logout')
@login_required
def logout():
    logout_user()
    flash('Başarıyla çıkış yaptınız', 'success')
    return redirect(url_for('admin.login'))

@admin_bp.route('/')
@admin_bp.route('/dashboard')
@login_required
def dashboard():
    # Statistics
    from models import Advertisement
    total_news = News.query.count()
    published_news = News.query.filter_by(status='published').count()
    draft_news = News.query.filter_by(status='draft').count()
    total_categories = Category.query.count()
    total_ads = Advertisement.query.count()
    
    # Recent news
    recent_news = News.query.order_by(News.created_at.desc()).limit(5).all()
    
    # Popular news (last 7 days)
    week_ago = datetime.utcnow() - timedelta(days=7)
    popular_news = db.session.query(News, db.func.count(NewsView.id).label('view_count')).join(
        NewsView, News.id == NewsView.news_id
    ).filter(NewsView.viewed_at >= week_ago).group_by(News.id).order_by(
        db.text('view_count DESC')
    ).limit(5).all()
    
    # Daily visitors (last 30 days)
    thirty_days_ago = datetime.utcnow().date() - timedelta(days=30)
    daily_stats = SiteStatistics.query.filter(
        SiteStatistics.date >= thirty_days_ago
    ).order_by(SiteStatistics.date.desc()).limit(30).all()
    
    return render_template('admin/dashboard.html',
                         total_news=total_news,
                         published_news=published_news,
                         draft_news=draft_news,
                         total_categories=total_categories,
                         total_ads=total_ads,
                         recent_news=recent_news,
                         popular_news=popular_news,
                         daily_stats=daily_stats)

@admin_bp.route('/haberler')
@login_required
def news_list():
    page = request.args.get('page', 1, type=int)
    status = request.args.get('status', 'all')
    category_id = request.args.get('category', type=int)
    search = request.args.get('search', '').strip()
    author_filter = request.args.get('author', 'all')
    
    query = News.query
    
    # Status filtresi
    if status != 'all':
        query = query.filter_by(status=status)
    
    # Kategori filtresi
    if category_id:
        query = query.filter_by(category_id=category_id)
    
    # Arama filtresi
    if search:
        query = query.filter(
            News.title.ilike(f'%{search}%') | 
            News.summary.ilike(f'%{search}%') |
            News.content.ilike(f'%{search}%')
        )
    
    # Yazar filtresi
    if author_filter != 'all':
        if author_filter == 'mine':
            query = query.filter_by(admin_id=current_user.id)
        elif author_filter == 'external':
            query = query.filter(News.source != 'manual')
        elif author_filter == 'manual':
            query = query.filter_by(source='manual')
    
    news = query.order_by(News.created_at.desc()).paginate(
        page=page, per_page=20, error_out=False
    )
    
    categories = Category.query.filter_by(is_active=True).all()
    
    return render_template('admin/news_list.html',
                         news=news,
                         categories=categories,
                         current_status=status,
                         current_category=category_id,
                         current_search=search,
                         current_author=author_filter)

@admin_bp.route('/benim-makalelerim')
@login_required
def my_articles():
    page = request.args.get('page', 1, type=int)
    status = request.args.get('status', 'all')
    category_id = request.args.get('category', type=int)
    search = request.args.get('search', '').strip()
    
    # Sadece mevcut kullanıcının makalelerini getir
    query = News.query.filter_by(admin_id=current_user.id)
    
    # Status filtresi
    if status != 'all':
        query = query.filter_by(status=status)
    
    # Kategori filtresi
    if category_id:
        query = query.filter_by(category_id=category_id)
    
    # Arama filtresi
    if search:
        query = query.filter(
            News.title.ilike(f'%{search}%') | 
            News.summary.ilike(f'%{search}%') |
            News.content.ilike(f'%{search}%')
        )
    
    news = query.order_by(News.created_at.desc()).paginate(
        page=page, per_page=20, error_out=False
    )
    
    categories = Category.query.filter_by(is_active=True).all()
    
    return render_template('admin/my_articles.html',
                         news=news,
                         categories=categories,
                         current_status=status,
                         current_category=category_id,
                         current_search=search)

@admin_bp.route('/haber/yeni', methods=['GET', 'POST'])
@login_required
def news_create():
    if request.method == 'POST':
        title = request.form.get('title')
        summary = request.form.get('summary')
        content = request.form.get('content')
        category_id = request.form.get('category_id', type=int)
        
        # Validate category_id
        if not category_id:
            flash('Kategori seçimi zorunludur', 'error')
            categories = Category.query.filter_by(is_active=True).all()
            return render_template('admin/news_form.html', categories=categories)
        status = request.form.get('status', 'draft')
        is_featured = 'is_featured' in request.form
        is_breaking = 'is_breaking' in request.form
        
        # Create slug
        slug = create_slug(title)
        
        # Handle file uploads
        images = []
        videos = []
        featured_image = None
        
        # Featured image
        if 'featured_image' in request.files:
            file = request.files['featured_image']
            if file and allowed_file(file.filename):
                featured_image = save_uploaded_file(file, 'images')
        
        # Multiple images
        for file in request.files.getlist('images'):
            if file and allowed_file(file.filename):
                image_path = save_uploaded_file(file, 'images')
                images.append(image_path)
        
        # Video URLs
        video_urls = request.form.getlist('video_urls')
        videos = [url.strip() for url in video_urls if url.strip()]
        
        news = News(
            title=title,
            slug=slug,
            summary=summary,
            content=content,
            category_id=category_id,
            status=status,
            is_featured=is_featured,
            is_breaking=is_breaking,
            featured_image=featured_image,
            images=json.dumps(images),
            videos=json.dumps(videos),
            admin_id=current_user.id,
            source='manual',  # Admin panelinden eklenen haberler için
            published_at=datetime.utcnow() if status == 'published' else None
        )
        
        db.session.add(news)
        db.session.commit()
        
        flash('Haber başarıyla oluşturuldu', 'success')
        return redirect(url_for('admin.news_list'))
    
    categories = Category.query.filter_by(is_active=True).all()
    return render_template('admin/news_form.html', categories=categories, news=None)

@admin_bp.route('/haber/<int:id>/duzenle', methods=['GET', 'POST'])
@login_required
def news_edit(id):
    news = News.query.get_or_404(id)
    
    if request.method == 'POST':
        news.title = request.form.get('title')
        news.summary = request.form.get('summary')
        news.content = request.form.get('content')
        news.category_id = request.form.get('category_id', type=int)
        news.status = request.form.get('status', 'draft')
        news.is_featured = 'is_featured' in request.form
        news.is_breaking = 'is_breaking' in request.form
        news.updated_at = datetime.utcnow()
        
        # Update slug if title changed
        news.slug = create_slug(news.title)
        
        # Handle file uploads
        images = json.loads(news.images) if news.images else []
        videos = json.loads(news.videos) if news.videos else []
        
        # Featured image
        if 'featured_image' in request.files:
            file = request.files['featured_image']
            if file and allowed_file(file.filename):
                news.featured_image = save_uploaded_file(file, 'images')
        
        # Additional images
        for file in request.files.getlist('images'):
            if file and allowed_file(file.filename):
                image_path = save_uploaded_file(file, 'images')
                images.append(image_path)
        
        # Video URLs
        video_urls = request.form.getlist('video_urls')
        new_videos = [url.strip() for url in video_urls if url.strip()]
        videos.extend(new_videos)
        
        news.images = json.dumps(images)
        news.videos = json.dumps(videos)
        
        # Set published date if status changed to published
        if news.status == 'published' and not news.published_at:
            news.published_at = datetime.utcnow()
        
        db.session.commit()
        
        flash('Haber başarıyla güncellendi', 'success')
        return redirect(url_for('admin.news_list'))
    
    categories = Category.query.filter_by(is_active=True).all()
    return render_template('admin/news_form.html', categories=categories, news=news)

@admin_bp.route('/haber/<int:id>/sil', methods=['POST'])
@login_required
def news_delete(id):
    try:
        news = News.query.get_or_404(id)
        
        # Yetki kontrolü - sadece makale sahibi veya super admin silebilir
        if news.admin_id != current_user.id and not current_user.is_super_admin:
            return jsonify({'success': False, 'message': 'Bu makaleyi silme yetkiniz yok'}), 403
        
        # Delete associated views
        NewsView.query.filter_by(news_id=id).delete()
        
        # Delete the news article
        db.session.delete(news)
        db.session.commit()
        
        # Ajax isteği kontrolü
        if request.headers.get('Content-Type') == 'application/json' or request.is_json:
            return jsonify({'success': True, 'message': 'Makale başarıyla silindi'})
        
        # Normal form isteği
        flash('Haber başarıyla silindi', 'success')
        return redirect(url_for('admin.news_list'))
        
    except Exception as e:
        db.session.rollback()
        
        # Ajax isteği kontrolü
        if request.headers.get('Content-Type') == 'application/json' or request.is_json:
            return jsonify({'success': False, 'message': 'Silme işlemi başarısız: ' + str(e)}), 500
        
        # Normal form isteği
        flash('Haber silinemedi: ' + str(e), 'error')
        return redirect(url_for('admin.news_list'))

# User Management Routes
@admin_bp.route('/kullanicilar')
@login_required
def users_list():
    if not current_user.is_super_admin:
        flash('Bu sayfaya erişim yetkiniz yok', 'error')
        return redirect(url_for('admin.dashboard'))
    
    users = Admin.query.order_by(Admin.created_at.desc()).all()
    return render_template('admin/users_list.html', users=users)

@admin_bp.route('/kullanici/yeni', methods=['GET', 'POST'])
@login_required
def user_create():
    if not current_user.is_super_admin:
        flash('Bu sayfaya erişim yetkiniz yok', 'error')
        return redirect(url_for('admin.dashboard'))
    
    if request.method == 'POST':
        username = request.form.get('username')
        email = request.form.get('email')
        password = request.form.get('password')
        is_super_admin = 'is_super_admin' in request.form
        
        # Check if username or email already exists
        if Admin.query.filter_by(username=username).first():
            flash('Bu kullanıcı adı zaten kullanılıyor', 'error')
            return render_template('admin/user_form.html')
        
        if Admin.query.filter_by(email=email).first():
            flash('Bu e-posta adresi zaten kullanılıyor', 'error')
            return render_template('admin/user_form.html')
        
        # Create new user with password hash
        from werkzeug.security import generate_password_hash
        user = Admin(
            username=username,
            email=email,
            password_hash=generate_password_hash(password),
            is_super_admin=is_super_admin
        )
        
        db.session.add(user)
        db.session.commit()
        
        flash('Yeni kullanıcı başarıyla oluşturuldu', 'success')
        return redirect(url_for('admin.users_list'))
    
    return render_template('admin/user_form.html')

@admin_bp.route('/kullanici/<int:id>/duzenle', methods=['GET', 'POST'])
@login_required
def user_edit(id):
    user = Admin.query.get_or_404(id)
    
    # Only super admin can edit others, or user can edit themselves
    if not current_user.is_super_admin and current_user.id != id:
        flash('Bu kullanıcıyı düzenleme yetkiniz yok', 'error')
        return redirect(url_for('admin.dashboard'))
    
    if request.method == 'POST':
        user.username = request.form.get('username')
        user.email = request.form.get('email')
        
        # Only super admin can change super admin status
        if current_user.is_super_admin:
            user.is_super_admin = 'is_super_admin' in request.form
            user.is_active = 'is_active' in request.form
        
        # Change password if provided
        new_password = request.form.get('new_password')
        if new_password:
            from werkzeug.security import generate_password_hash
            user.password_hash = generate_password_hash(new_password)
        
        db.session.commit()
        flash('Kullanıcı bilgileri güncellendi', 'success')
        
        if current_user.id == id:
            return redirect(url_for('admin.profile'))
        else:
            return redirect(url_for('admin.users_list'))
    
    return render_template('admin/user_form.html', user=user, is_edit=True)

@admin_bp.route('/kullanici/<int:id>/sil', methods=['POST'])
@login_required
def user_delete(id):
    if not current_user.is_super_admin:
        flash('Bu işlem için yetkiniz yok', 'error')
        return redirect(url_for('admin.users_list'))
    
    if current_user.id == id:
        flash('Kendi hesabınızı silemezsiniz', 'error')
        return redirect(url_for('admin.users_list'))
    
    user = Admin.query.get_or_404(id)
    db.session.delete(user)
    db.session.commit()
    
    flash('Kullanıcı başarıyla silindi', 'success')
    return redirect(url_for('admin.users_list'))

@admin_bp.route('/profil', methods=['GET', 'POST'])
@login_required
def profile():
    if request.method == 'POST':
        current_user.username = request.form.get('username')
        current_user.email = request.form.get('email')
        
        # Change password if provided
        current_password = request.form.get('current_password')
        new_password = request.form.get('new_password')
        confirm_password = request.form.get('confirm_password')
        
        if new_password:
            if not current_user.check_password(current_password):
                flash('Mevcut şifre yanlış', 'error')
                return render_template('admin/profile.html')
            
            if new_password != confirm_password:
                flash('Yeni şifreler eşleşmiyor', 'error')
                return render_template('admin/profile.html')
            
            if len(new_password) < 6:
                flash('Şifre en az 6 karakter olmalıdır', 'error')
                return render_template('admin/profile.html')
            
            from werkzeug.security import generate_password_hash
            current_user.password_hash = generate_password_hash(new_password)
        
        db.session.commit()
        flash('Profil bilgileriniz güncellendi', 'success')
        return redirect(url_for('admin.profile'))
    
    return render_template('admin/profile.html')



# Category editing removed

# Category deletion removed

# Users management removed



@admin_bp.route('/istatistikler')
@login_required
def statistics():
    # News statistics
    total_news = News.query.count()
    published_news = News.query.filter_by(status='published').count()
    draft_news = News.query.filter_by(status='draft').count()
    
    # View statistics
    total_views = db.session.query(db.func.sum(News.view_count)).scalar() or 0
    
    # Most viewed news
    most_viewed = News.query.order_by(News.view_count.desc()).limit(10).all()
    
    # Daily views (last 30 days) - gerçek veriler
    from datetime import timedelta, date
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    
    # Gerçek günlük görüntülenme verileri
    daily_views_raw = db.session.query(
        db.func.date(NewsView.viewed_at).label('date'),
        db.func.count(NewsView.id).label('views')
    ).filter(NewsView.viewed_at >= thirty_days_ago).group_by(
        db.func.date(NewsView.viewed_at)
    ).order_by(db.text('date DESC')).all()
    
    # Boş günleri de dahil et (0 görüntülenme ile)
    daily_views = []
    current_date = date.today()
    
    for i in range(30):
        check_date = current_date - timedelta(days=i)
        views_count = 0
        
        # Bu tarihte görüntülenme var mı kontrol et
        for view_data in daily_views_raw:
            if view_data.date == check_date:
                views_count = view_data.views
                break
        
        daily_views.append({
            'date': check_date,
            'views': views_count
        })
    
    # Category statistics
    category_stats = db.session.query(
        Category.name,
        db.func.count(News.id).label('news_count'),
        db.func.sum(News.view_count).label('total_views')
    ).join(News, Category.id == News.category_id).group_by(Category.id).all()
    
    # Get real traffic source data
    from sqlalchemy import func, text
    
    try:
        # Real traffic sources based on actual data (SQLite compatible)
        traffic_sources = db.session.execute(text("""
            SELECT 
                CASE 
                    WHEN user_agent LIKE '%Google%' OR user_agent LIKE '%googlebot%' THEN 'Google'
                    WHEN user_agent LIKE '%Facebook%' OR user_agent LIKE '%facebookexternalhit%' THEN 'Facebook'
                    WHEN user_agent LIKE '%Twitter%' OR user_agent LIKE '%Twitterbot%' THEN 'Twitter'
                    WHEN user_agent LIKE '%WhatsApp%' THEN 'WhatsApp'
                    WHEN user_agent LIKE '%Telegram%' THEN 'Telegram'
                    WHEN user_agent LIKE '%Safari%' AND user_agent NOT LIKE '%Chrome%' THEN 'Safari'
                    WHEN user_agent LIKE '%Chrome%' THEN 'Chrome'
                    WHEN user_agent LIKE '%Firefox%' THEN 'Firefox'
                    WHEN user_agent LIKE '%Edge%' THEN 'Edge'
                    ELSE 'Diğer'
                END as source,
                COUNT(*) as count
            FROM news_views 
            WHERE viewed_at >= datetime('now', '-30 days')
            GROUP BY source
            ORDER BY count DESC
            LIMIT 10
        """)).fetchall()
        
        # Browser statistics (SQLite compatible)
        browser_stats = db.session.execute(text("""
            SELECT 
                CASE 
                    WHEN user_agent LIKE '%Chrome%' AND user_agent NOT LIKE '%Edge%' THEN 'Chrome'
                    WHEN user_agent LIKE '%Firefox%' THEN 'Firefox'
                    WHEN user_agent LIKE '%Safari%' AND user_agent NOT LIKE '%Chrome%' THEN 'Safari'
                    WHEN user_agent LIKE '%Edge%' THEN 'Edge'
                    WHEN user_agent LIKE '%Opera%' THEN 'Opera'
                    ELSE 'Diğer'
                END as browser,
                COUNT(*) as count
            FROM news_views 
            WHERE viewed_at >= datetime('now', '-30 days')
            GROUP BY browser
            ORDER BY count DESC
        """)).fetchall()
        
        # Device statistics (SQLite compatible)
        device_stats = db.session.execute(text("""
            SELECT 
                CASE 
                    WHEN user_agent LIKE '%Mobile%' OR user_agent LIKE '%Android%' OR user_agent LIKE '%iPhone%' THEN 'Mobil'
                    WHEN user_agent LIKE '%Tablet%' OR user_agent LIKE '%iPad%' THEN 'Tablet'
                    ELSE 'Masaüstü'
                END as device,
                COUNT(*) as count
            FROM news_views 
            WHERE viewed_at >= datetime('now', '-30 days')
            GROUP BY device
            ORDER BY count DESC
        """)).fetchall()
        
        traffic_sources_list = [{'source': row[0], 'count': row[1]} for row in traffic_sources]
        browser_stats_list = [{'browser': row[0], 'count': row[1]} for row in browser_stats]
        device_stats_list = [{'device': row[0], 'count': row[1]} for row in device_stats]
        
    except Exception as e:
        print(f"Error fetching traffic stats: {e}")
        # Fallback to empty lists if SQL fails
        traffic_sources_list = []
        browser_stats_list = []
        device_stats_list = []
    
    return render_template('admin/statistics.html',
                         total_news=total_news,
                         published_news=published_news,
                         draft_news=draft_news,
                         total_views=total_views,
                         most_viewed=most_viewed,
                         daily_views=daily_views,
                         category_stats=category_stats,
                         traffic_sources=traffic_sources_list,
                         browser_stats=browser_stats_list,
                         device_stats=device_stats_list)
