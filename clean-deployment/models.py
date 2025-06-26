from app import db
from flask_login import UserMixin
from datetime import datetime
from sqlalchemy import text
from werkzeug.security import generate_password_hash, check_password_hash

class Admin(UserMixin, db.Model):
    __tablename__ = 'admins'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    is_super_admin = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Category(db.Model):
    __tablename__ = 'categories'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False, unique=True)
    slug = db.Column(db.String(100), nullable=False, unique=True)
    description = db.Column(db.Text)
    color = db.Column(db.String(7), default='#dc2626')  # Red theme
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship
    news = db.relationship('News', backref='category', lazy='dynamic')

class News(db.Model):
    __tablename__ = 'news'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    slug = db.Column(db.String(255), nullable=False, unique=True)
    summary = db.Column(db.Text)
    content = db.Column(db.Text, nullable=False)
    featured_image = db.Column(db.String(255))
    images = db.Column(db.Text)  # JSON string of image URLs
    videos = db.Column(db.Text)  # JSON string of video URLs
    source = db.Column(db.String(50), default='manual')  # manual, trt, external
    source_url = db.Column(db.String(500))
    author = db.Column(db.String(100))
    
    # Status and publishing
    status = db.Column(db.String(20), default='draft')  # draft, published, archived
    is_featured = db.Column(db.Boolean, default=False)
    is_breaking = db.Column(db.Boolean, default=False)
    published_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Statistics
    view_count = db.Column(db.Integer, default=0)
    
    # Foreign Keys
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'), nullable=False)
    admin_id = db.Column(db.Integer, db.ForeignKey('admins.id'))
    
    # Relationships
    admin = db.relationship('Admin', backref=db.backref('news_created', lazy='dynamic'))
    
    def increment_view_count(self):
        self.view_count += 1
        db.session.commit()

class NewsView(db.Model):
    __tablename__ = 'news_views'
    
    id = db.Column(db.Integer, primary_key=True)
    news_id = db.Column(db.Integer, db.ForeignKey('news.id'), nullable=False)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.String(500))
    viewed_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship
    news = db.relationship('News', backref='views')

class SiteStatistics(db.Model):
    __tablename__ = 'site_statistics'
    
    id = db.Column(db.Integer, primary_key=True)
    total_visitors = db.Column(db.Integer, default=0)
    daily_visitors = db.Column(db.Integer, default=0)
    total_news = db.Column(db.Integer, default=0)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow)
    date = db.Column(db.Date, default=datetime.utcnow().date())

class SystemSettings(db.Model):
    __tablename__ = 'system_settings'
    
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), unique=True, nullable=False)
    value = db.Column(db.Text)
    description = db.Column(db.Text)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class UserSession(db.Model):
    __tablename__ = 'user_sessions'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(64), unique=True, nullable=False)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.String(500))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_activity = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship with user interactions
    interactions = db.relationship('UserInteraction', backref='session', lazy='dynamic')

class UserInteraction(db.Model):
    __tablename__ = 'user_interactions'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(64), db.ForeignKey('user_sessions.session_id'), nullable=False)
    news_id = db.Column(db.Integer, db.ForeignKey('news.id'), nullable=False)
    interaction_type = db.Column(db.String(20), nullable=False)  # 'view', 'click', 'scroll', 'share'
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'))
    duration = db.Column(db.Integer, default=0)  # seconds spent reading
    scroll_depth = db.Column(db.Float, default=0.0)  # percentage of article scrolled
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    news = db.relationship('News', backref='interactions')
    category = db.relationship('Category', backref='interactions')

class UserPreference(db.Model):
    __tablename__ = 'user_preferences'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(64), db.ForeignKey('user_sessions.session_id'), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'), nullable=False)
    interest_score = db.Column(db.Float, default=0.0)  # 0.0 to 1.0
    last_updated = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    session = db.relationship('UserSession', backref='preferences')
    category = db.relationship('Category', backref='user_preferences')

class Advertisement(db.Model):
    __tablename__ = 'advertisements'
    
    id = db.Column(db.Integer, primary_key=True)
    ad_type = db.Column(db.String(20), nullable=False)  # 'sidebar', 'popup'
    position = db.Column(db.String(20))  # 'left', 'right' (for sidebar ads)
    slot_number = db.Column(db.Integer, default=1)  # 1-4 for each side
    title = db.Column(db.String(255))
    description = db.Column(db.Text)  # Enhanced description field
    image_path = db.Column(db.String(500), nullable=False)
    link_url = db.Column(db.String(500))
    is_active = db.Column(db.Boolean, default=True)
    click_count = db.Column(db.Integer, default=0)
    impression_count = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Foreign key to admin who created the ad
    admin_id = db.Column(db.Integer, db.ForeignKey('admins.id'))
    admin = db.relationship('Admin', backref=db.backref('advertisements', lazy='dynamic'))
    
    def to_dict(self):
        return {
            'id': self.id,
            'ad_type': self.ad_type,
            'position': self.position,
            'slot_number': self.slot_number,
            'title': self.title,
            'description': self.description,
            'image_path': self.image_path,
            'link_url': self.link_url,
            'is_active': self.is_active,
            'click_count': self.click_count,
            'impression_count': self.impression_count,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
    
    def increment_clicks(self):
        self.click_count += 1
        db.session.commit()
    
    def increment_impressions(self):
        self.impression_count += 1
        db.session.commit()
