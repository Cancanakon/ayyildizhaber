import os
from flask import Flask, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from werkzeug.middleware.proxy_fix import ProxyFix

# Initialize Flask app
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = 'test-secret-key'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///test.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize SQLAlchemy
db = SQLAlchemy(app)

# Simple User model
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)

# Simple News model
class News(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())

# Routes
@app.route('/')
def index():
    news_list = News.query.order_by(News.created_at.desc()).limit(10).all()
    return f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Ayyıldız Haber Ajansı</title>
        <meta charset="utf-8">
        <style>
            body {{ font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
            .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }}
            .header {{ background: #dc2626; color: white; padding: 20px; text-align: center; border-radius: 10px; margin-bottom: 20px; }}
            .status {{ background: #059669; color: white; padding: 10px; border-radius: 5px; margin-bottom: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Ayyıldız Haber Ajansı</h1>
                <p>Test Başarılı - Sistem Çalışıyor</p>
            </div>
            <div class="status">
                ✅ Database bağlantısı aktif - {News.query.count()} haber kayıtlı
            </div>
            <h2>Son Haberler</h2>
            {"".join([f'<div style="border: 1px solid #ddd; padding: 15px; margin-bottom: 15px;"><h3>{news.title}</h3><p>{news.content[:200]}...</p></div>' for news in news_list]) if news_list else '<p>Yakında haberler eklenecek.</p>'}
        </div>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    return {'status': 'OK', 'database': 'Connected', 'news_count': News.query.count()}

# Create tables and sample data
with app.app_context():
    db.create_all()
    if News.query.count() == 0:
        sample_news = [
            News(title="Sistem Test Başarılı", content="Flask uygulaması başarıyla çalışıyor. Database bağlantısı aktif."),
            News(title="Kurulum Tamamlandı", content="Tüm bileşenler doğru şekilde yapılandırıldı ve test edildi.")
        ]
        for news in sample_news:
            db.session.add(news)
        db.session.commit()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)