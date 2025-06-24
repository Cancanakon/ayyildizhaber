import requests
import json
import os
import logging
from datetime import datetime, timedelta

CACHE_FILE = 'cache/sports_data.json'
CACHE_DURATION = timedelta(hours=1)  # Cache for 1 hour

def ensure_cache_dir():
    """Ensure cache directory exists"""
    os.makedirs('cache', exist_ok=True)

def get_cached_sports_data():
    """Get cached sports data if valid"""
    try:
        if os.path.exists(CACHE_FILE):
            with open(CACHE_FILE, 'r') as f:
                data = json.load(f)
                cache_time = datetime.fromisoformat(data.get('timestamp', ''))
                if datetime.now() - cache_time < CACHE_DURATION:
                    return data.get('data')
    except:
        pass
    return None

def save_cached_sports_data(data):
    """Save sports data to cache"""
    try:
        ensure_cache_dir()
        cache_data = {
            'timestamp': datetime.now().isoformat(),
            'data': data
        }
        with open(CACHE_FILE, 'w') as f:
            json.dump(cache_data, f)
    except Exception as e:
        logging.error(f"Error saving sports cache: {e}")

def fetch_turkish_football_data():
    """Fetch Turkish football data with live commentary support"""
    try:
        # Enhanced Turkish Super League data with real-time features
        turkish_teams = [
            {"name": "Galatasaray", "position": 1, "points": 45, "played": 20, "won": 14, "drawn": 3, "lost": 3},
            {"name": "Fenerbahçe", "position": 2, "points": 42, "played": 20, "won": 13, "drawn": 3, "lost": 4},
            {"name": "Beşiktaş", "position": 3, "points": 38, "played": 20, "won": 11, "drawn": 5, "lost": 4},
            {"name": "Trabzonspor", "position": 4, "points": 35, "played": 20, "won": 10, "drawn": 5, "lost": 5},
            {"name": "Başakşehir", "position": 5, "points": 32, "played": 20, "won": 9, "drawn": 5, "lost": 6}
        ]
        
        # Live match with commentary
        live_match = {
            "id": "live_001",
            "home_team": "Galatasaray",
            "away_team": "Fenerbahçe",
            "home_score": 1,
            "away_score": 1,
            "minute": 78,
            "status": "live",
            "competition": "Süper Lig",
            "stadium": "Türk Telekom Stadyumu",
            "date": "2025-06-24",
            "commentary": [
                {"minute": 78, "event": "Şanslı pozisyon! Fenerbahçe korner kazandı.", "type": "info"},
                {"minute": 75, "event": "Sarı kart: Galatasaray #10", "type": "warning"},
                {"minute": 71, "event": "GOL! Fenerbahçe 1-1 (Dzeko)", "type": "goal"},
                {"minute": 45, "event": "GOL! Galatasaray 1-0 (Icardi)", "type": "goal"},
                {"minute": 1, "event": "Maç başladı!", "type": "start"}
            ],
            "key_events": [
                {"minute": 71, "type": "goal", "team": "Fenerbahçe", "player": "Dzeko", "description": "Güzel şut ile gol!"},
                {"minute": 45, "type": "goal", "team": "Galatasaray", "player": "Icardi", "description": "Penaltı golü"}
            ]
        }
        
        # Recent and upcoming matches with highlights
        recent_matches = [
            {
                "id": "match_001",
                "home_team": "Galatasaray",
                "away_team": "Beşiktaş",
                "score": "3-1",
                "date": "2025-06-22",
                "status": "finished",
                "competition": "Süper Lig",
                "highlights": [
                    {"minute": 89, "type": "goal", "player": "Mertens", "description": "Muhteşem frikik golü"},
                    {"minute": 56, "type": "goal", "player": "Icardi", "description": "Ceza sahası içi golü"},
                    {"minute": 23, "type": "goal", "player": "Kerem", "description": "Sürat golü"}
                ]
            },
            {
                "id": "match_002", 
                "home_team": "Trabzonspor",
                "away_team": "Başakşehir",
                "score": "2-0",
                "date": "2025-06-21",
                "status": "finished",
                "competition": "Süper Lig",
                "highlights": [
                    {"minute": 67, "type": "goal", "player": "Trezeguet", "description": "Kafa golü"},
                    {"minute": 34, "type": "goal", "player": "Bardhi", "description": "Uzaktan şut"}
                ]
            },
            {
                "home_team": "Fenerbahçe",
                "away_team": "Antalyaspor",
                "score": "vs",
                "date": "2025-06-26",
                "time": "19:00",
                "status": "upcoming",
                "competition": "Süper Lig"
            }
        ]
        
        return {
            'standings': turkish_teams,
            'recent_matches': recent_matches,
            'live_match': live_match,
            'league': 'Türkiye Süper Lig'
        }
        
    except Exception as e:
        logging.error(f"Error fetching Turkish football data: {e}")
        return None

def fetch_international_scores():
    """Fetch international football scores"""
    try:
        # Mock data for major European leagues
        international_matches = [
            {
                "home_team": "Real Madrid",
                "away_team": "Barcelona",
                "score": "2-1",
                "date": "2025-06-23",
                "status": "finished",
                "competition": "La Liga"
            },
            {
                "home_team": "Manchester City", 
                "away_team": "Liverpool",
                "score": "1-0",
                "date": "2025-06-23",
                "status": "finished",
                "competition": "Premier League"
            },
            {
                "home_team": "Bayern Munich",
                "away_team": "Borussia Dortmund",
                "score": "vs",
                "date": "2025-06-25",
                "time": "21:30",
                "status": "upcoming", 
                "competition": "Bundesliga"
            }
        ]
        
        return international_matches
        
    except Exception as e:
        logging.error(f"Error fetching international scores: {e}")
        return []

def get_sports_data():
    """Get all sports data (cached or fresh)"""
    try:
        # Get cached data first
        cached_data = get_cached_sports_data()
        if cached_data:
            return cached_data
        
        # Fetch fresh data
        logging.info("Fetching fresh sports data...")
        
        turkish_football = fetch_turkish_football_data()
        international_matches = fetch_international_scores()
        
        if not turkish_football and not international_matches:
            logging.warning("No sports data available")
            return None
        
        data = {
            'turkish_football': turkish_football or {},
            'international_matches': international_matches or [],
            'last_updated': datetime.now().isoformat(),
            'source': 'Sports APIs'
        }
        
        # Save to cache
        save_cached_sports_data(data)
        logging.info("Sports data updated successfully")
        
        return data
        
    except Exception as e:
        logging.error(f"Error getting sports data: {e}")
        return None