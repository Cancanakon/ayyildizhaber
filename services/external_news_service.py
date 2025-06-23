import requests
import json
from models import News, Category
from app import db
from utils.helpers import create_slug, clean_html_content
from datetime import datetime
import logging
import os

def fetch_external_news_api():
    """Fetch news from external API (using provided service pattern)"""
    try:
        # Using news API similar to the provided service
        api_key = os.environ.get('NEWS_API_KEY', '3ZtBxBJ6bXe3bJB0t7lFw0:26r9LIVecUDgXit4axIcKi')
        categories = ['sport', 'health', 'technology', 'politic', 'economy']
        
        all_news = []
        
        for category in categories:
            try:
                url = f"https://api.collectapi.com/news/getNews"
                headers = {
                    'content-type': 'application/json',
                    'authorization': f'apikey {api_key}'
                }
                params = {
                    'country': 'tr',
                    'tag': category
                }
                
                response = requests.get(url, headers=headers, params=params, timeout=30)
                
                if response.status_code == 200:
                    data = response.json()
                    if data.get('success') and data.get('result'):
                        for item in data['result'][:5]:  # Limit to 5 news per category
                            news_item = {
                                'title': item.get('name', ''),
                                'summary': item.get('description', ''),
                                'content': item.get('description', ''),  # Use description as content
                                'image_url': item.get('image', ''),
                                'source_url': item.get('url', ''),
                                'category': category,
                                'source': 'external'
                            }
                            
                            if news_item['title'] and news_item['content']:
                                all_news.append(news_item)
                
            except Exception as e:
                logging.error(f"Error fetching external news for category {category}: {e}")
                continue
        
        return all_news
        
    except Exception as e:
        logging.error(f"Error fetching external news: {e}")
        return []

def save_external_news_to_db(news_items):
    """Save external news items to database"""
    saved_count = 0
    
    for item in news_items:
        try:
            # Check if news already exists
            slug = create_slug(item['title'])
            existing_news = News.query.filter_by(slug=slug).first()
            
            if existing_news:
                continue
            
            # Map category names
            category_map = {
                'sport': 'Spor',
                'health': 'Sağlık',
                'technology': 'Teknoloji',
                'politic': 'Politika',
                'economy': 'Ekonomi'
            }
            
            category_name = category_map.get(item['category'], item['category'].title())
            category = Category.query.filter_by(name=category_name).first()
            
            if not category:
                category = Category(
                    name=category_name,
                    slug=create_slug(category_name),
                    description=f"{category_name} kategorisi",
                    color='#dc2626'
                )
                db.session.add(category)
                db.session.flush()  # Get the ID
            
            # Clean content
            content = clean_html_content(item['content'])
            summary = clean_html_content(item['summary']) if item['summary'] else content[:200] + '...'
            
            # Create news item
            news = News(
                title=item['title'],
                slug=slug,
                summary=summary,
                content=content,
                featured_image=item['image_url'] if item['image_url'] else None,
                source=item['source'],
                source_url=item['source_url'],
                category_id=category.id,
                status='published',
                published_at=datetime.utcnow(),
                author='Harici Kaynak'
            )
            
            # Add images if available
            if item['image_url']:
                images = [item['image_url']]
                news.images = json.dumps(images)
            
            db.session.add(news)
            saved_count += 1
            
        except Exception as e:
            logging.error(f"Error saving external news item: {e}")
            continue
    
    try:
        db.session.commit()
        logging.info(f"Saved {saved_count} external news items to database")
    except Exception as e:
        db.session.rollback()
        logging.error(f"Error committing external news to database: {e}")
    
    return saved_count

def fetch_and_save_external_news():
    """Main function to fetch and save external news"""
    try:
        logging.info("Fetching external news...")
        news_items = fetch_external_news_api()
        saved = save_external_news_to_db(news_items)
        logging.info(f"Total external news items saved: {saved}")
        return saved
    except Exception as e:
        logging.error(f"Error in fetch_and_save_external_news: {e}")
        return 0
