import requests
import json
import os
from datetime import datetime, timedelta

CACHE_FILE = 'cache/prayer_data.json'
CACHE_DURATION = timedelta(hours=6)  # Cache for 6 hours

# Major Turkish cities
CITIES = [
    {'name': 'İstanbul', 'lat': 41.0082, 'lon': 28.9784},
    {'name': 'Ankara', 'lat': 39.9334, 'lon': 32.8597},
    {'name': 'İzmir', 'lat': 38.4192, 'lon': 27.1287},
    {'name': 'Antalya', 'lat': 36.8841, 'lon': 30.7056},
    {'name': 'Adana', 'lat': 37.0000, 'lon': 35.3213},
    {'name': 'Bursa', 'lat': 40.1826, 'lon': 29.0665}
]

def ensure_cache_dir():
    """Ensure cache directory exists"""
    os.makedirs('cache', exist_ok=True)

def get_cached_prayer_times():
    """Get cached prayer times if valid"""
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

def save_cached_prayer_times(data):
    """Save prayer times to cache"""
    try:
        ensure_cache_dir()
        cache_data = {
            'timestamp': datetime.now().isoformat(),
            'data': data
        }
        with open(CACHE_FILE, 'w') as f:
            json.dump(cache_data, f)
    except Exception as e:
        print(f"Error saving prayer times cache: {e}")

def fetch_prayer_times_for_city(city):
    """Fetch prayer times for a specific city"""
    try:
        # Using Islamic Network API
        today = datetime.now().strftime('%d-%m-%Y')
        url = f"http://api.aladhan.com/v1/timings/{today}"
        params = {
            'latitude': city['lat'],
            'longitude': city['lon'],
            'method': 13,  # Turkey method
            'school': 1    # Hanafi
        }
        
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            timings = data.get('data', {}).get('timings', {})
            
            return {
                'city': city['name'],
                'fajr': timings.get('Fajr', ''),
                'sunrise': timings.get('Sunrise', ''),
                'dhuhr': timings.get('Dhuhr', ''),
                'asr': timings.get('Asr', ''),
                'maghrib': timings.get('Maghrib', ''),
                'isha': timings.get('Isha', ''),
                'date': data.get('data', {}).get('date', {}).get('readable', '')
            }
    except Exception as e:
        print(f"Error fetching prayer times for {city['name']}: {e}")
    
    return None

def fetch_all_prayer_times():
    """Fetch prayer times for all cities"""
    prayer_data = []
    
    for city in CITIES:
        try:
            city_data = fetch_prayer_times_for_city(city)
            if city_data:
                prayer_data.append(city_data)
            else:
                # Fallback data
                prayer_data.append({
                    'city': city['name'],
                    'fajr': '05:30',
                    'sunrise': '07:00',
                    'dhuhr': '12:30',
                    'asr': '15:30',
                    'maghrib': '18:00',
                    'isha': '19:30',
                    'date': datetime.now().strftime('%d %B %Y')
                })
        except Exception as e:
            print(f"Error processing prayer times for {city['name']}: {e}")
    
    return prayer_data

def get_prayer_times():
    """Get prayer times (cached or fresh)"""
    # Try cache first
    cached_data = get_cached_prayer_times()
    if cached_data:
        return cached_data
    
    # Fetch fresh data
    try:
        prayer_data = fetch_all_prayer_times()
        
        result = {
            'cities': prayer_data,
            'last_updated': datetime.now().isoformat()
        }
        
        # Cache the data
        save_cached_prayer_times(result)
        
        return result
        
    except Exception as e:
        print(f"Error getting prayer times: {e}")
        return {
            'cities': [
                {
                    'city': city['name'],
                    'fajr': '05:30',
                    'sunrise': '07:00',
                    'dhuhr': '12:30',
                    'asr': '15:30',
                    'maghrib': '18:00',
                    'isha': '19:30',
                    'date': datetime.now().strftime('%d %B %Y')
                }
                for city in CITIES
            ],
            'last_updated': datetime.now().isoformat()
        }
