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
    total_news = News.query.count()
    published_news = News.query.filter_by(status='published').count()
    draft_news = News.query.filter_by(status='draft').count()
    total_categories = Category.query.count()
    
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
                         recent_news=recent_news,
                         popular_news=popular_news,
                         daily_stats=daily_stats)

@admin_bp.route('/haberler')
@login_required
def news_list():
    page = request.args.get('page', 1, type=int)
    status = request.args.get('status', 'all')
    category_id = request.args.get('category', type=int)
    
    query = News.query
    
    if status != 'all':
        query = query.filter_by(status=status)
    
    if category_id:
        query = query.filter_by(category_id=category_id)
    
    news = query.order_by(News.created_at.desc()).paginate(
        page=page, per_page=20, error_out=False
    )
    
    categories = Category.query.filter_by(is_active=True).all()
    
    return render_template('admin/news_list.html',
                         news=news,
                         categories=categories,
                         current_status=status,
                         current_category=category_id)

@admin_bp.route('/haber/yeni', methods=['GET', 'POST'])
@login_required
def news_create():
    if request.method == 'POST':
        title = request.form.get('title')
        summary = request.form.get('summary')
        content = request.form.get('content')
        category_id = request.form.get('category_id', type=int)
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
    news = News.query.get_or_404(id)
    
    # Delete associated views
    NewsView.query.filter_by(news_id=id).delete()
    
    db.session.delete(news)
    db.session.commit()
    
    flash('Haber başarıyla silindi', 'success')
    return redirect(url_for('admin.news_list'))

@admin_bp.route('/kategoriler')
@login_required
def categories():
    categories = Category.query.order_by(Category.name).all()
    return render_template('admin/categories.html', categories=categories)

@admin_bp.route('/kategori/yeni', methods=['POST'])
@login_required
def category_create():
    name = request.form.get('name')
    description = request.form.get('description')
    color = request.form.get('color', '#dc2626')
    
    slug = create_slug(name)
    
    category = Category(
        name=name,
        slug=slug,
        description=description,
        color=color
    )
    
    db.session.add(category)
    db.session.commit()
    
    flash('Kategori başarıyla oluşturuldu', 'success')
    return redirect(url_for('admin.categories'))

@admin_bp.route('/kategori/<int:id>/duzenle', methods=['POST'])
@login_required
def category_edit(id):
    category = Category.query.get_or_404(id)
    
    category.name = request.form.get('name')
    category.description = request.form.get('description')
    category.color = request.form.get('color', '#dc2626')
    category.slug = create_slug(category.name)
    
    db.session.commit()
    
    flash('Kategori başarıyla güncellendi', 'success')
    return redirect(url_for('admin.categories'))

@admin_bp.route('/kategori/<int:id>/sil', methods=['POST'])
@login_required  
def category_delete(id):
    category = Category.query.get_or_404(id)
    
    # Check if category has news
    if category.news.count() > 0:
        flash('Bu kategoride haberler bulunduğu için silinemez', 'error')
        return redirect(url_for('admin.categories'))
    
    db.session.delete(category)
    db.session.commit()
    
    flash('Kategori başarıyla silindi', 'success')
    return redirect(url_for('admin.categories'))

@admin_bp.route('/kullanicilar')
@login_required
def users():
    if not current_user.is_super_admin:
        flash('Bu sayfaya erişim yetkiniz yok', 'error')
        return redirect(url_for('admin.dashboard'))
    
    admins = Admin.query.order_by(Admin.created_at.desc()).all()
    return render_template('admin/users.html', admins=admins)

@admin_bp.route('/kullanici/yeni', methods=['POST'])
@login_required
def user_create():
    if not current_user.is_super_admin:
        flash('Bu işlem için yetkiniz yok', 'error')
        return redirect(url_for('admin.users'))
    
    username = request.form.get('username')
    email = request.form.get('email')
    password = request.form.get('password')
    is_super_admin = 'is_super_admin' in request.form
    
    # Check if email exists
    if Admin.query.filter_by(email=email).first():
        flash('Bu email adresi zaten kullanılıyor', 'error')
        return redirect(url_for('admin.users'))
    
    admin = Admin(
        username=username,
        email=email,
        password_hash=generate_password_hash(password),
        is_super_admin=is_super_admin
    )
    
    db.session.add(admin)
    db.session.commit()
    
    flash('Kullanıcı başarıyla oluşturuldu', 'success')
    return redirect(url_for('admin.users'))

@admin_bp.route('/kullanici/<int:id>/sil', methods=['POST'])
@login_required
def user_delete(id):
    if not current_user.is_super_admin:
        flash('Bu işlem için yetkiniz yok', 'error')
        return redirect(url_for('admin.users'))
    
    if id == current_user.id:
        flash('Kendi hesabınızı silemezsiniz', 'error')
        return redirect(url_for('admin.users'))
    
    admin = Admin.query.get_or_404(id)
    db.session.delete(admin)
    db.session.commit()
    
    flash('Kullanıcı başarıyla silindi', 'success')
    return redirect(url_for('admin.users'))

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
    
    # Daily views (last 30 days)
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    daily_views = db.session.query(
        db.func.date(NewsView.viewed_at).label('date'),
        db.func.count(NewsView.id).label('views')
    ).filter(NewsView.viewed_at >= thirty_days_ago).group_by(
        db.func.date(NewsView.viewed_at)
    ).order_by(db.text('date DESC')).all()
    
    # Category statistics
    category_stats = db.session.query(
        Category.name,
        db.func.count(News.id).label('news_count'),
        db.func.sum(News.view_count).label('total_views')
    ).join(News, Category.id == News.category_id).group_by(Category.id).all()
    
    return render_template('admin/statistics.html',
                         total_news=total_news,
                         published_news=published_news,
                         draft_news=draft_news,
                         total_views=total_views,
                         most_viewed=most_viewed,
                         daily_views=daily_views,
                         category_stats=category_stats)
