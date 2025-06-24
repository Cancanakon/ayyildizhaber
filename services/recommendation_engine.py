"""
Personalized News Recommendation Engine
Tracks user behavior and provides personalized news recommendations
"""

import uuid
import hashlib
from datetime import datetime, timedelta
from collections import defaultdict
from sqlalchemy import func, desc
from models import db, News, Category, UserSession, UserInteraction, UserPreference, NewsView
import logging

class NewsRecommendationEngine:
    """Main recommendation engine class"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def get_or_create_session(self, request):
        """Get or create user session based on IP and user agent"""
        try:
            ip_address = request.remote_addr or 'unknown'
            user_agent = request.headers.get('User-Agent', '')[:500]
            
            # Create session identifier
            session_data = f"{ip_address}_{user_agent}"
            session_id = hashlib.md5(session_data.encode()).hexdigest()
            
            # Check if session exists
            session = UserSession.query.filter_by(session_id=session_id).first()
            
            if not session:
                session = UserSession(
                    session_id=session_id,
                    ip_address=ip_address,
                    user_agent=user_agent
                )
                db.session.add(session)
            else:
                # Update last activity
                session.last_activity = datetime.utcnow()
            
            db.session.commit()
            return session
            
        except Exception as e:
            self.logger.error(f"Error getting/creating session: {e}")
            return None
    
    def track_interaction(self, session_id, news_id, interaction_type='view', duration=0, scroll_depth=0.0):
        """Track user interaction with news article"""
        try:
            news = News.query.get(news_id)
            if not news:
                return False
            
            interaction = UserInteraction(
                session_id=session_id,
                news_id=news_id,
                interaction_type=interaction_type,
                category_id=news.category_id,
                duration=duration,
                scroll_depth=scroll_depth
            )
            
            db.session.add(interaction)
            db.session.commit()
            
            # Update user preferences asynchronously
            self._update_user_preferences(session_id, news.category_id, interaction_type, duration, scroll_depth)
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error tracking interaction: {e}")
            return False
    
    def _update_user_preferences(self, session_id, category_id, interaction_type, duration, scroll_depth):
        """Update user preference scores based on interaction"""
        try:
            # Get or create preference record
            preference = UserPreference.query.filter_by(
                session_id=session_id,
                category_id=category_id
            ).first()
            
            if not preference:
                preference = UserPreference(
                    session_id=session_id,
                    category_id=category_id,
                    interest_score=0.0
                )
                db.session.add(preference)
            
            # Calculate score increment based on interaction
            score_increment = self._calculate_score_increment(interaction_type, duration, scroll_depth)
            
            # Update preference score (weighted average)
            current_score = preference.interest_score
            new_score = min(1.0, current_score + score_increment * 0.1)  # Gradual learning
            preference.interest_score = new_score
            preference.last_updated = datetime.utcnow()
            
            db.session.commit()
            
        except Exception as e:
            self.logger.error(f"Error updating user preferences: {e}")
    
    def _calculate_score_increment(self, interaction_type, duration, scroll_depth):
        """Calculate score increment based on interaction quality"""
        base_scores = {
            'view': 0.1,
            'click': 0.2,
            'scroll': 0.3,
            'share': 0.5
        }
        
        base_score = base_scores.get(interaction_type, 0.1)
        
        # Bonus for longer reading time
        if duration > 30:  # More than 30 seconds
            base_score += 0.2
        if duration > 120:  # More than 2 minutes
            base_score += 0.3
        
        # Bonus for scroll depth
        if scroll_depth > 0.5:  # Read more than 50%
            base_score += 0.2
        if scroll_depth > 0.8:  # Read more than 80%
            base_score += 0.3
        
        return min(1.0, base_score)
    
    def get_recommended_news(self, session_id, limit=5, exclude_ids=None):
        """Get personalized news recommendations for user"""
        try:
            exclude_ids = exclude_ids or []
            
            # Get user preferences
            user_preferences = UserPreference.query.filter_by(session_id=session_id).all()
            
            if not user_preferences:
                # New user - return popular news
                return self._get_popular_news(limit, exclude_ids)
            
            # Create category weights based on user preferences
            category_weights = {}
            for pref in user_preferences:
                category_weights[pref.category_id] = pref.interest_score
            
            # Get news recommendations based on preferences
            recommendations = []
            
            # Sort categories by preference score
            sorted_categories = sorted(category_weights.items(), key=lambda x: x[1], reverse=True)
            
            for category_id, score in sorted_categories:
                if len(recommendations) >= limit:
                    break
                
                # Get recent news from this category
                category_news = News.query.filter(
                    News.category_id == category_id,
                    News.status == 'published',
                    ~News.id.in_(exclude_ids)
                ).order_by(desc(News.published_at)).limit(3).all()
                
                for news in category_news:
                    if news.id not in [r.id for r in recommendations]:
                        recommendations.append(news)
                        if len(recommendations) >= limit:
                            break
            
            # Fill remaining slots with popular news
            if len(recommendations) < limit:
                popular_news = self._get_popular_news(
                    limit - len(recommendations),
                    exclude_ids + [r.id for r in recommendations]
                )
                recommendations.extend(popular_news)
            
            return recommendations[:limit]
            
        except Exception as e:
            self.logger.error(f"Error getting recommendations: {e}")
            return self._get_popular_news(limit, exclude_ids)
    
    def _get_popular_news(self, limit, exclude_ids=None):
        """Get popular news as fallback"""
        exclude_ids = exclude_ids or []
        
        # Get most viewed news from last 7 days
        week_ago = datetime.utcnow() - timedelta(days=7)
        
        popular_news = News.query.filter(
            News.status == 'published',
            News.published_at >= week_ago,
            ~News.id.in_(exclude_ids)
        ).order_by(desc(News.view_count)).limit(limit).all()
        
        # If not enough popular news, get latest news
        if len(popular_news) < limit:
            latest_news = News.query.filter(
                News.status == 'published',
                ~News.id.in_(exclude_ids + [n.id for n in popular_news])
            ).order_by(desc(News.published_at)).limit(limit - len(popular_news)).all()
            
            popular_news.extend(latest_news)
        
        return popular_news[:limit]
    
    def get_user_interests(self, session_id):
        """Get user's category interests for analytics"""
        try:
            preferences = UserPreference.query.filter_by(session_id=session_id).all()
            
            interests = {}
            for pref in preferences:
                interests[pref.category.name] = {
                    'score': pref.interest_score,
                    'last_updated': pref.last_updated
                }
            
            return interests
            
        except Exception as e:
            self.logger.error(f"Error getting user interests: {e}")
            return {}
    
    def get_trending_categories(self, days=7):
        """Get trending categories based on user interactions"""
        try:
            since_date = datetime.utcnow() - timedelta(days=days)
            
            # Get interaction counts by category
            trending = db.session.query(
                Category.name,
                func.count(UserInteraction.id).label('interaction_count')
            ).join(
                UserInteraction, Category.id == UserInteraction.category_id
            ).filter(
                UserInteraction.timestamp >= since_date
            ).group_by(
                Category.id, Category.name
            ).order_by(
                desc('interaction_count')
            ).limit(5).all()
            
            return [{'category': t.name, 'interactions': t.interaction_count} for t in trending]
            
        except Exception as e:
            self.logger.error(f"Error getting trending categories: {e}")
            return []

# Global recommendation engine instance
recommendation_engine = NewsRecommendationEngine()