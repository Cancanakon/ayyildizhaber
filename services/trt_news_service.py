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
    categories = ['gundem', 'ekonomi', 'spor', 'teknoloji', 'saglik', 'kultur-sanat']
    total_saved = 0
    
    for category in categories:
        try:
            logging.info(f"Fetching TRT news for category: {category}")
            news_items = fetch_trt_news_xml(category, 10)
            saved = save_trt_news_to_db(news_items)
            total_saved += saved
            
        except Exception as e:
            logging.error(f"Error processing TRT category {category}: {e}")
    
    logging.info(f"Total TRT news items saved: {total_saved}")
    return total_saved
