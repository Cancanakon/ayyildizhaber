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
                            # Clean HTML content
                            from utils.helpers import clean_html_content
                            title = clean_html_content(item.get('name', ''))
                            description = clean_html_content(item.get('description', ''))
                            image_url = item.get('image', '')
                            
                            # Validate image URL
                            if image_url and not image_url.startswith('http'):
                                image_url = ''
                            
                            news_item = {
                                'title': title.strip(),
                                'summary': description[:200] + '...' if len(description) > 200 else description,
                                'content': description.strip(),
                                'image_url': image_url.strip(),
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
                # Check if category with this slug already exists
                slug = create_slug(category_name)
                existing_category = Category.query.filter_by(slug=slug).first()
                
                if existing_category:
                    category = existing_category
                else:
                    try:
                        category = Category(
                            name=category_name,
                            slug=slug,
                            description=f"{category_name} kategorisi",
                            color='#dc2626'
                        )
                        db.session.add(category)
                        db.session.flush()  # Get the ID
                    except Exception as e:
                        # If category creation fails, use default category
                        category = Category.query.filter_by(name='Gündem').first()
                        if not category:
                            db.session.rollback()
                            continue
            
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
            db.session.rollback()
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
        total_saved = 0
        
        # First try TRT news
        try:
            from services.trt_news_service import fetch_and_save_trt_news
            trt_saved = fetch_and_save_trt_news()
            total_saved += trt_saved
            print(f"TRT News: {trt_saved} articles saved")
        except Exception as e:
            print(f"TRT fetch failed: {e}")
        
        # Try external API
        try:
            api_news = fetch_external_news_api()
            if api_news:
                api_saved = save_external_news_to_db(api_news)
                total_saved += api_saved
                print(f"External API: {api_saved} articles saved")
        except Exception as e:
            print(f"External API fetch failed: {e}")
        
        # Add RSS backup sources
        try:
            rss_saved = fetch_multiple_rss_sources()
            total_saved += rss_saved
            print(f"RSS Sources: {rss_saved} articles saved")
        except Exception as e:
            print(f"RSS fetch failed: {e}")
        
        print(f"Total news articles saved: {total_saved}")
        return total_saved
        
    except Exception as e:
        logging.error(f"Error in fetch_and_save_external_news: {e}")
        return 0

def fetch_multiple_rss_sources():
    """Fetch from multiple RSS sources for continuous news flow"""
    try:
        import feedparser
        
        sources = [
            {'url': 'https://www.hurriyet.com.tr/rss/anasayfa', 'category': 'gundem'},
            {'url': 'https://www.milliyet.com.tr/rss/rssNew/SonDakikaRSS.xml', 'category': 'gundem'},
            {'url': 'https://www.sabah.com.tr/rss/ekonomi.xml', 'category': 'ekonomi'},
            {'url': 'https://www.haberturk.com/rss/spor.xml', 'category': 'spor'},
            {'url': 'https://www.aa.com.tr/tr/rss/default?cat=guncel', 'category': 'gundem'},
            {'url': 'https://www.ntv.com.tr/teknoloji.rss', 'category': 'teknoloji'},
        ]
        
        total_saved = 0
        
        for source in sources:
            try:
                feed = feedparser.parse(source['url'])
                items = []
                
                for entry in feed.entries[:5]:  # Limit to 5 per source
                    try:
                        # Clean and prepare content
                        from utils.helpers import clean_html_content
                        description = getattr(entry, 'description', getattr(entry, 'summary', ''))
                        title = clean_html_content(entry.title)
                        content = clean_html_content(description)
                        
                        item = {
                            'title': title.strip(),
                            'summary': content[:200] + '...' if len(content) > 200 else content,
                            'content': content.strip(),
                            'source_url': entry.link,
                            'category': source['category'],
                            'source': 'rss',
                            'image_url': ''
                        }
                        
                        if item['title'] and item['content']:
                            items.append(item)
                    except Exception as item_e:
                        continue
                
                if items:
                    saved = save_external_news_to_db(items)
                    total_saved += saved
                    
            except Exception as source_e:
                continue
        
        return total_saved
        
    except Exception as e:
        print(f"Multiple RSS fetch failed: {e}")
        return 0
