import os
import logging
from datetime import datetime, timedelta
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from sqlalchemy.orm import DeclarativeBase
from werkzeug.middleware.proxy_fix import ProxyFix
from apscheduler.schedulers.background import BackgroundScheduler
import atexit

class Base(DeclarativeBase):
    pass

db = SQLAlchemy(model_class=Base)
login_manager = LoginManager()

# create the app
app = Flask(__name__)
app.secret_key = os.environ.get("SESSION_SECRET", "your-secret-key-here")
app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)

# configure logging
logging.basicConfig(level=logging.DEBUG)

# configure the database
app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get("DATABASE_URL", "sqlite:///news.db")
app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
    "pool_recycle": 300,
    "pool_pre_ping": True,
}
app.config["UPLOAD_FOLDER"] = "static/uploads"
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16MB max file size

# initialize extensions
db.init_app(app)
login_manager.init_app(app)
login_manager.login_view = 'admin.login'
login_manager.login_message = 'Bu sayfaya erişmek için giriş yapmalısınız.'

@login_manager.user_loader
def load_user(user_id):
    from models import Admin
    return Admin.query.get(int(user_id))

# Create upload directory
os.makedirs(app.config["UPLOAD_FOLDER"], exist_ok=True)
os.makedirs(os.path.join(app.config["UPLOAD_FOLDER"], "images"), exist_ok=True)
os.makedirs(os.path.join(app.config["UPLOAD_FOLDER"], "videos"), exist_ok=True)

with app.app_context():
    # Import models to create tables
    import models
    db.create_all()
    
    # Create default categories
    from models import Category
    default_categories = [
        {'name': 'Gündem', 'slug': 'gundem', 'description': 'Güncel gelişmeler ve önemli haberler', 'color': '#dc2626'},
        {'name': 'Politika', 'slug': 'politika', 'description': 'Siyasi gelişmeler ve haberler', 'color': '#991b1b'},
        {'name': 'Ekonomi', 'slug': 'ekonomi', 'description': 'Ekonomik haberler ve analizler', 'color': '#059669'},
        {'name': 'Spor', 'slug': 'spor', 'description': 'Spor haberleri ve sonuçları', 'color': '#2563eb'},
        {'name': 'Teknoloji', 'slug': 'teknoloji', 'description': 'Teknoloji haberleri ve yenilikler', 'color': '#7c3aed'},
        {'name': 'Sağlık', 'slug': 'saglik', 'description': 'Sağlık haberleri ve bilgileri', 'color': '#16a34a'},
        {'name': 'Eğitim', 'slug': 'egitim', 'description': 'Eğitim haberleri ve gelişmeleri', 'color': '#ea580c'},
        {'name': 'Kültür-Sanat', 'slug': 'kultur-sanat', 'description': 'Kültür ve sanat haberleri', 'color': '#be185d'},
        {'name': 'Dünya', 'slug': 'dunya', 'description': 'Dünya haberleri ve uluslararası gelişmeler', 'color': '#0891b2'},
    ]
    
    for cat_data in default_categories:
        if not Category.query.filter_by(slug=cat_data['slug']).first():
            category = Category(
                name=cat_data['name'],
                slug=cat_data['slug'],
                description=cat_data['description'],
                color=cat_data['color']
            )
            db.session.add(category)
    
    # Create default admin user
    from models import Admin
    from werkzeug.security import generate_password_hash
    
    admin = Admin.query.filter_by(email='admin@gmail.com').first()
    if not admin:
        admin = Admin(
            username='admin',
            email='admin@gmail.com',
            password_hash=generate_password_hash('admin123'),
            is_super_admin=True
        )
        db.session.add(admin)
    
    db.session.commit()
    print("Default admin user created: admin@gmail.com / admin123")
    print("Default categories created")

# Register template filters
from utils.helpers import register_template_filters
register_template_filters(app)

# Import routes
from routes import main_bp
from admin_routes import admin_bp

app.register_blueprint(main_bp)
app.register_blueprint(admin_bp, url_prefix='/admin')

# Background scheduler for fetching news
scheduler = BackgroundScheduler()

def fetch_external_news():
    """Background task to fetch news from TRT and other sources"""
    with app.app_context():
        try:
            from services.trt_news_service import fetch_and_save_trt_news
            from services.external_news_service import fetch_and_save_external_news
            
            # Fetch TRT news
            fetch_and_save_trt_news()
            
            # Fetch external news
            fetch_and_save_external_news()
            
            print("External news fetched successfully")
        except Exception as e:
            print(f"Error fetching external news: {e}")

# Schedule news fetching every 15 minutes for more frequent updates
scheduler.add_job(
    func=fetch_external_news,
    trigger="interval",
    minutes=15,
    id='fetch_news_job'
)

# Also run once at startup after 30 seconds
scheduler.add_job(
    func=fetch_external_news,
    trigger="date",
    run_date=datetime.now() + timedelta(seconds=30),
    id='startup_news_job'
)

# Start scheduler
scheduler.start()
atexit.register(lambda: scheduler.shutdown())
