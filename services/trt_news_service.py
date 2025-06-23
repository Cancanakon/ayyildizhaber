import requests
from bs4 import BeautifulSoup
import xml.etree.ElementTree as ET
from models import News, Category
from app import db
from utils.helpers import create_slug, clean_html_content
from datetime import datetime
import json
import logging

def fetch_trt_news_xml(category='gundem', count=20):
    """Fetch news from TRT Haber XML feed"""
    try:
        url = f"https://www.trthaber.com/xml_mobile.php?tur=xml_genel&kategori={category}&adet={count}&selectEx=yorumSay,okunmaadedi,anasayfamanset,kategorimanset"
        
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        # Parse XML
        root = ET.fromstring(response.content)
        news_items = []
        
        for haber in root.findall('haber'):
            try:
                item = {
                    'title': haber.find('haber_manset').text if haber.find('haber_manset') is not None else '',
                    'summary': haber.find('haber_aciklama').text if haber.find('haber_aciklama') is not None else '',
                    'content': haber.find('haber_metni').text if haber.find('haber_metni') is not None else '',
                    'image_url': haber.find('haber_resim').text if haber.find('haber_resim') is not None else '',
                    'source_url': haber.find('haber_link').text if haber.find('haber_link') is not None else '',
                    'pub_date': haber.find('haber_tarihi').text if haber.find('haber_tarihi') is not None else '',
                    'category': haber.find('haber_kategorisi').text if haber.find('haber_kategorisi') is not None else category
                }
                
                if item['title'] and item['content']:
                    news_items.append(item)
                    
            except Exception as e:
                logging.error(f"Error parsing TRT news item: {e}")
                continue
        
        return news_items
        
    except Exception as e:
        logging.error(f"Error fetching TRT news: {e}")
        return []

def save_trt_news_to_db(news_items):
    """Save TRT news items to database"""
    saved_count = 0
    
    for item in news_items:
        try:
            # Check if news already exists
            slug = create_slug(item['title'])
            existing_news = News.query.filter_by(slug=slug).first()
            
            if existing_news:
                continue
            
            # Get or create category
            category_name = item['category'].title()
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
                source='trt',
                source_url=item['source_url'],
                category_id=category.id,
                status='published',
                published_at=datetime.utcnow(),
                author='TRT Haber'
            )
            
            # Add images if available
            if item['image_url']:
                images = [item['image_url']]
                news.images = json.dumps(images)
            
            db.session.add(news)
            saved_count += 1
            
        except Exception as e:
            logging.error(f"Error saving TRT news item: {e}")
            continue
    
    try:
        db.session.commit()
        logging.info(f"Saved {saved_count} TRT news items to database")
    except Exception as e:
        db.session.rollback()
        logging.error(f"Error committing TRT news to database: {e}")
    
    return saved_count

def fetch_and_save_trt_news():
    """Main function to fetch and save TRT news"""
    categories = ['gundem', 'ekonomi', 'spor', 'teknoloji', 'saglik', 'kultur-sanat', 'dunya', 'politika']
    total_saved = 0
    
    for category in categories:
        try:
            logging.info(f"Fetching TRT news for category: {category}")
            news_items = fetch_trt_news_xml(category, 15)
            
            if news_items:
                saved = save_trt_news_to_db(news_items)
                total_saved += saved
                print(f"Saved {saved} TRT news items from {category}")
            else:
                # Try RSS as backup
                try:
                    import feedparser
                    rss_url = f"https://www.trthaber.com/rss/{category}.rss"
                    feed = feedparser.parse(rss_url)
                    
                    rss_items = []
                    for entry in feed.entries[:10]:
                        item = {
                            'title': entry.title,
                            'summary': entry.description[:200] + '...' if len(entry.description) > 200 else entry.description,
                            'content': entry.description,
                            'source_url': entry.link,
                            'pub_date': entry.published if hasattr(entry, 'published') else '',
                            'category': category,
                            'image_url': ''
                        }
                        rss_items.append(item)
                    
                    if rss_items:
                        saved = save_trt_news_to_db(rss_items)
                        total_saved += saved
                        print(f"Saved {saved} TRT RSS news items from {category}")
                        
                except Exception as rss_e:
                    print(f"RSS backup failed for {category}: {rss_e}")
            
        except Exception as e:
            logging.error(f"Error processing TRT category {category}: {e}")
    
    print(f"Total TRT news items saved: {total_saved}")
    return total_saved

def fetch_rss_backup():
    """Fetch from multiple RSS sources for continuous news flow"""
    try:
        import feedparser
        
        sources = [
            {'url': 'https://www.trthaber.com/rss/manset.rss', 'category': 'gundem'},
            {'url': 'https://www.trthaber.com/rss/son_dakika.rss', 'category': 'gundem'},
            {'url': 'https://www.aa.com.tr/tr/rss/default?cat=guncel', 'category': 'gundem'},
        ]
        
        total_saved = 0
        
        for source in sources:
            try:
                feed = feedparser.parse(source['url'])
                items = []
                
                for entry in feed.entries[:8]:
                    item = {
                        'title': entry.title,
                        'summary': entry.description[:200] + '...' if len(entry.description) > 200 else entry.description,
                        'content': entry.description,
                        'source_url': entry.link,
                        'pub_date': entry.published if hasattr(entry, 'published') else '',
                        'category': source['category'],
                        'image_url': ''
                    }
                    items.append(item)
                
                if items:
                    saved = save_trt_news_to_db(items)
                    total_saved += saved
                    print(f"Saved {saved} RSS backup news from {source['url']}")
                    
            except Exception as e:
                print(f"Error with RSS source {source['url']}: {e}")
        
        return total_saved
        
    except Exception as e:
        print(f"RSS backup failed: {e}")
        return 0
