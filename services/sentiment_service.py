"""
News Sentiment Analysis Service
Analyzes news sentiment and provides dynamic background colors
"""

import json
import os
from datetime import datetime, timedelta
from textblob import TextBlob
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
import colorsys


class SentimentAnalyzer:
    """Advanced sentiment analysis with color generation"""
    
    def __init__(self):
        self.vader_analyzer = SentimentIntensityAnalyzer()
        self.cache_file = os.path.join('cache', 'sentiment_cache.json')
        self.ensure_cache_dir()
        
    def ensure_cache_dir(self):
        """Ensure cache directory exists"""
        os.makedirs('cache', exist_ok=True)
        
    def analyze_text_sentiment(self, text):
        """
        Analyze sentiment of text using both TextBlob and VADER
        Returns sentiment scores and interpretation
        """
        if not text or len(text.strip()) < 10:
            return {
                'polarity': 0.0,
                'subjectivity': 0.0,
                'compound': 0.0,
                'sentiment': 'neutral',
                'confidence': 0.0
            }
        
        # TextBlob analysis
        blob = TextBlob(text)
        polarity = blob.sentiment.polarity  # -1 to 1
        subjectivity = blob.sentiment.subjectivity  # 0 to 1
        
        # VADER analysis
        vader_scores = self.vader_analyzer.polarity_scores(text)
        compound = vader_scores['compound']  # -1 to 1
        
        # Determine overall sentiment
        avg_sentiment = (polarity + compound) / 2
        
        if avg_sentiment >= 0.1:
            sentiment = 'positive'
        elif avg_sentiment <= -0.1:
            sentiment = 'negative'
        else:
            sentiment = 'neutral'
            
        # Calculate confidence (combination of absolute values)
        confidence = (abs(polarity) + abs(compound) + subjectivity) / 3
        
        return {
            'polarity': polarity,
            'subjectivity': subjectivity,
            'compound': compound,
            'sentiment': sentiment,
            'confidence': min(confidence, 1.0),
            'avg_sentiment': avg_sentiment
        }
    
    def analyze_news_sentiment(self, news_item):
        """Analyze sentiment of a single news article"""
        # Combine title and content for analysis
        text_content = ""
        if hasattr(news_item, 'title') and news_item.title:
            text_content += news_item.title + ". "
        if hasattr(news_item, 'summary') and news_item.summary:
            text_content += news_item.summary + ". "
        if hasattr(news_item, 'content') and news_item.content:
            # Limit content to first 500 characters for performance
            content = news_item.content[:500] if len(news_item.content) > 500 else news_item.content
            text_content += content
            
        return self.analyze_text_sentiment(text_content)
    
    def get_global_sentiment(self, news_list, limit=20):
        """
        Analyze sentiment of multiple news articles to get global sentiment
        """
        if not news_list:
            return {
                'overall_sentiment': 'neutral',
                'sentiment_score': 0.0,
                'confidence': 0.0,
                'positive_count': 0,
                'negative_count': 0,
                'neutral_count': 0,
                'total_analyzed': 0
            }
        
        sentiments = []
        positive_count = 0
        negative_count = 0
        neutral_count = 0
        
        # Analyze recent news (limit for performance)
        recent_news = news_list[:limit]
        
        for news in recent_news:
            sentiment_data = self.analyze_news_sentiment(news)
            sentiments.append(sentiment_data)
            
            if sentiment_data['sentiment'] == 'positive':
                positive_count += 1
            elif sentiment_data['sentiment'] == 'negative':
                negative_count += 1
            else:
                neutral_count += 1
        
        # Calculate overall metrics
        total_analyzed = len(sentiments)
        if total_analyzed == 0:
            avg_sentiment = 0.0
            overall_confidence = 0.0
        else:
            avg_sentiment = sum(s['avg_sentiment'] for s in sentiments) / total_analyzed
            overall_confidence = sum(s['confidence'] for s in sentiments) / total_analyzed
        
        # Determine overall sentiment
        if avg_sentiment >= 0.15:
            overall_sentiment = 'positive'
        elif avg_sentiment <= -0.15:
            overall_sentiment = 'negative'
        else:
            overall_sentiment = 'neutral'
        
        return {
            'overall_sentiment': overall_sentiment,
            'sentiment_score': avg_sentiment,
            'confidence': overall_confidence,
            'positive_count': positive_count,
            'negative_count': negative_count,
            'neutral_count': neutral_count,
            'total_analyzed': total_analyzed
        }
    
    def sentiment_to_color(self, sentiment_data):
        """
        Convert sentiment analysis to background color scheme
        Returns CSS-compatible color values
        """
        sentiment = sentiment_data['overall_sentiment']
        score = sentiment_data['sentiment_score']
        confidence = sentiment_data['confidence']
        
        # Base colors for different sentiments
        if sentiment == 'positive':
            # Green-based colors (calm, positive)
            base_hue = 120  # Green
            saturation = min(0.3 + (confidence * 0.4), 0.7)
            lightness = max(0.95 - (abs(score) * 0.15), 0.85)
        elif sentiment == 'negative':
            # Red-orange based colors (warm, attention)
            base_hue = 15   # Red-orange
            saturation = min(0.2 + (confidence * 0.3), 0.5)
            lightness = max(0.95 - (abs(score) * 0.1), 0.9)
        else:
            # Blue-gray neutral colors
            base_hue = 210  # Blue-gray
            saturation = min(0.1 + (confidence * 0.2), 0.3)
            lightness = 0.96
        
        # Convert HSL to RGB
        rgb = colorsys.hls_to_rgb(base_hue/360, lightness, saturation)
        
        # Convert to CSS rgb values
        r, g, b = [int(c * 255) for c in rgb]
        
        # Generate color scheme
        primary_color = f"rgb({r}, {g}, {b})"
        
        # Secondary color (slightly darker)
        secondary_rgb = colorsys.hls_to_rgb(base_hue/360, lightness - 0.05, saturation)
        sr, sg, sb = [int(c * 255) for c in secondary_rgb]
        secondary_color = f"rgb({sr}, {sg}, {sb})"
        
        # Accent color (different hue)
        accent_hue = (base_hue + 30) % 360
        accent_rgb = colorsys.hls_to_rgb(accent_hue/360, lightness - 0.02, saturation + 0.1)
        ar, ag, ab = [int(c * 255) for c in accent_rgb]
        accent_color = f"rgb({ar}, {ag}, {ab})"
        
        return {
            'primary': primary_color,
            'secondary': secondary_color,
            'accent': accent_color,
            'css_variables': {
                '--sentiment-bg-primary': primary_color,
                '--sentiment-bg-secondary': secondary_color,
                '--sentiment-bg-accent': accent_color,
                '--sentiment-opacity': str(min(0.3 + confidence * 0.4, 0.7))
            }
        }
    
    def get_cached_sentiment(self):
        """Get cached sentiment data if valid"""
        try:
            if os.path.exists(self.cache_file):
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    cache_data = json.load(f)
                
                # Check if cache is still valid (1 hour)
                cache_time = datetime.fromisoformat(cache_data['timestamp'])
                if datetime.now() - cache_time < timedelta(hours=1):
                    return cache_data['sentiment_data']
        except Exception as e:
            print(f"Error reading sentiment cache: {e}")
        
        return None
    
    def save_sentiment_cache(self, sentiment_data):
        """Save sentiment data to cache"""
        try:
            cache_data = {
                'timestamp': datetime.now().isoformat(),
                'sentiment_data': sentiment_data
            }
            
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(cache_data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"Error saving sentiment cache: {e}")
    
    def get_sentiment_colors(self, news_list=None):
        """
        Get sentiment-based color scheme for the website
        Uses cache when available for performance
        """
        # Try to get cached data first
        cached_sentiment = self.get_cached_sentiment()
        if cached_sentiment:
            return self.sentiment_to_color(cached_sentiment)
        
        # If no cache or expired, analyze news
        if news_list:
            sentiment_data = self.get_global_sentiment(news_list)
            self.save_sentiment_cache(sentiment_data)
            return self.sentiment_to_color(sentiment_data)
        
        # Default neutral colors if no news available
        default_sentiment = {
            'overall_sentiment': 'neutral',
            'sentiment_score': 0.0,
            'confidence': 0.5,
            'positive_count': 0,
            'negative_count': 0,
            'neutral_count': 0,
            'total_analyzed': 0
        }
        
        return self.sentiment_to_color(default_sentiment)


# Global instance
sentiment_analyzer = SentimentAnalyzer()