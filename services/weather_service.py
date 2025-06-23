import requests
import json
import os
from datetime import datetime, timedelta

CACHE_FILE = 'cache/weather_data.json'
CACHE_DURATION = timedelta(hours=2)  # Cache for 2 hours

# Major Turkish cities with coordinates
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

def get_cached_weather():
    """Get cached weather data if valid"""
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

def save_cached_weather(data):
    """Save weather data to cache"""
    try:
        ensure_cache_dir()
        cache_data = {
            'timestamp': datetime.now().isoformat(),
            'data': data
        }
        with open(CACHE_FILE, 'w') as f:
            json.dump(cache_data, f)
    except Exception as e:
        print(f"Error saving weather cache: {e}")

def get_weather_icon(weather_code):
    """Convert weather code to icon class"""
    icon_map = {
        0: 'fas fa-sun',  # Clear sky
        1: 'fas fa-sun',  # Mainly clear
        2: 'fas fa-cloud-sun',  # Partly cloudy
        3: 'fas fa-cloud',  # Overcast
        45: 'fas fa-smog',  # Fog
        48: 'fas fa-smog',  # Depositing rime fog
        51: 'fas fa-cloud-drizzle',  # Light drizzle
        53: 'fas fa-cloud-drizzle',  # Moderate drizzle
        55: 'fas fa-cloud-drizzle',  # Dense drizzle
        61: 'fas fa-cloud-rain',  # Slight rain
        63: 'fas fa-cloud-rain',  # Moderate rain
        65: 'fas fa-cloud-showers-heavy',  # Heavy rain
        71: 'fas fa-snowflake',  # Slight snow
        73: 'fas fa-snowflake',  # Moderate snow
        75: 'fas fa-snowflake',  # Heavy snow
        77: 'fas fa-snowflake',  # Snow grains
        80: 'fas fa-cloud-showers-heavy',  # Slight rain showers
        81: 'fas fa-cloud-showers-heavy',  # Moderate rain showers
        82: 'fas fa-cloud-showers-heavy',  # Violent rain showers
        85: 'fas fa-snowflake',  # Slight snow showers
        86: 'fas fa-snowflake',  # Heavy snow showers
        95: 'fas fa-bolt',  # Thunderstorm
        96: 'fas fa-bolt',  # Thunderstorm with slight hail
        99: 'fas fa-bolt'   # Thunderstorm with heavy hail
    }
    return icon_map.get(weather_code, 'fas fa-sun')

def get_weather_description(weather_code):
    """Convert weather code to Turkish description"""
    desc_map = {
        0: 'Açık',
        1: 'Çoğunlukla açık',
        2: 'Parçalı bulutlu',
        3: 'Bulutlu',
        45: 'Sisli',
        48: 'Dondurucu sis',
        51: 'Hafif çisenti',
        53: 'Orta çisenti',
        55: 'Yoğun çisenti',
        61: 'Hafif yağmur',
        63: 'Orta yağmur',
        65: 'Şiddetli yağmur',
        71: 'Hafif kar',
        73: 'Orta kar',
        75: 'Yoğun kar',
        77: 'Kar taneleri',
        80: 'Hafif sağanak',
        81: 'Orta sağanak',
        82: 'Şiddetli sağanak',
        85: 'Hafif kar sağanağı',
        86: 'Yoğun kar sağanağı',
        95: 'Gök gürültülü fırtına',
        96: 'Hafif dolu ile fırtına',
        99: 'Şiddetli dolu ile fırtına'
    }
    return desc_map.get(weather_code, 'Bilinmeyen')

def fetch_weather_data():
    """Fetch weather data for all cities"""
    weather_data = []
    
    for city in CITIES:
        try:
            url = f"https://api.open-meteo.com/v1/forecast"
            params = {
                'latitude': city['lat'],
                'longitude': city['lon'],
                'current_weather': 'true',
                'timezone': 'Europe/Istanbul'
            }
            
            response = requests.get(url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                current = data.get('current_weather', {})
                
                weather_info = {
                    'city': city['name'],
                    'temperature': round(current.get('temperature', 0)),
                    'weather_code': current.get('weathercode', 0),
                    'wind_speed': round(current.get('windspeed', 0)),
                    'wind_direction': current.get('winddirection', 0),
                    'icon': get_weather_icon(current.get('weathercode', 0)),
                    'description': get_weather_description(current.get('weathercode', 0))
                }
                
                weather_data.append(weather_info)
                
        except Exception as e:
            print(f"Error fetching weather for {city['name']}: {e}")
            # Add fallback data
            weather_data.append({
                'city': city['name'],
                'temperature': 20,
                'weather_code': 0,
                'wind_speed': 0,
                'wind_direction': 0,
                'icon': 'fas fa-sun',
                'description': 'Bilinmeyen'
            })
    
    return weather_data

def get_weather_data():
    """Get weather data (cached or fresh)"""
    # Try cache first
    cached_data = get_cached_weather()
    if cached_data:
        return cached_data
    
    # Fetch fresh data
    try:
        weather_data = fetch_weather_data()
        
        result = {
            'cities': weather_data,
            'last_updated': datetime.now().isoformat()
        }
        
        # Cache the data
        save_cached_weather(result)
        
        return result
        
    except Exception as e:
        print(f"Error getting weather data: {e}")
        return {
            'cities': [
                {'city': city['name'], 'temperature': 20, 'icon': 'fas fa-sun', 'description': 'Açık'}
                for city in CITIES
            ],
            'last_updated': datetime.now().isoformat()
        }
