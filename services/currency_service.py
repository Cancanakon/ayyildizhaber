import requests
import json
import os
from datetime import datetime, timedelta

CACHE_FILE = 'cache/currency_data.json'
CACHE_DURATION = timedelta(hours=1)  # Cache for 1 hour

def ensure_cache_dir():
    """Ensure cache directory exists"""
    os.makedirs('cache', exist_ok=True)

def get_cached_data():
    """Get cached currency data if valid"""
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

def save_cached_data(data):
    """Save currency data to cache"""
    try:
        ensure_cache_dir()
        cache_data = {
            'timestamp': datetime.now().isoformat(),
            'data': data
        }
        with open(CACHE_FILE, 'w') as f:
            json.dump(cache_data, f)
    except Exception as e:
        print(f"Error saving cache: {e}")

def fetch_currency_rates():
    """Fetch current currency rates from API"""
    try:
        # Try multiple APIs for reliability
        apis = [
            'https://api.exchangerate-api.com/v4/latest/USD',
            'https://api.fixer.io/latest?access_key=' + os.environ.get('FIXER_API_KEY', ''),
            'https://openexchangerates.org/api/latest.json?app_id=' + os.environ.get('OPENEXCHANGE_API_KEY', '')
        ]
        
        for api_url in apis:
            try:
                if 'fixer.io' in api_url and not os.environ.get('FIXER_API_KEY'):
                    continue
                if 'openexchangerates' in api_url and not os.environ.get('OPENEXCHANGE_API_KEY'):
                    continue
                    
                response = requests.get(api_url, timeout=10)
                if response.status_code == 200:
                    data = response.json()
                    
                    # Convert to our format
                    if 'rates' in data:
                        try_rate = data['rates'].get('TRY', 0)
                        if try_rate > 0:
                            return {
                                'USD': {
                                    'buying': round(try_rate, 2),
                                    'selling': round(try_rate * 1.02, 2)
                                },
                                'EUR': {
                                    'buying': round(try_rate * 1.1, 2),  # Approximate EUR rate
                                    'selling': round(try_rate * 1.12, 2)
                                },
                                'GBP': {
                                    'buying': round(try_rate * 1.25, 2),  # Approximate GBP rate
                                    'selling': round(try_rate * 1.27, 2)
                                }
                            }
            except:
                continue
        
        # Fallback rates if APIs fail
        return {
            'USD': {'buying': 34.50, 'selling': 34.70},
            'EUR': {'buying': 37.20, 'selling': 37.40},
            'GBP': {'buying': 43.10, 'selling': 43.30}
        }
        
    except Exception as e:
        print(f"Error fetching currency rates: {e}")
        return None

def fetch_crypto_prices():
    """Fetch cryptocurrency prices"""
    try:
        url = 'https://api.coingecko.com/api/v3/simple/price'
        params = {
            'ids': 'bitcoin,ethereum,binancecoin',
            'vs_currencies': 'try'
        }
        
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            return {
                'BTC': {
                    'price': round(data.get('bitcoin', {}).get('try', 0)),
                    'symbol': '₺'
                },
                'ETH': {
                    'price': round(data.get('ethereum', {}).get('try', 0)),
                    'symbol': '₺'
                },
                'BNB': {
                    'price': round(data.get('binancecoin', {}).get('try', 0)),
                    'symbol': '₺'
                }
            }
    except Exception as e:
        print(f"Error fetching crypto prices: {e}")
    
    # Fallback prices
    return {
        'BTC': {'price': 1800000, 'symbol': '₺'},
        'ETH': {'price': 120000, 'symbol': '₺'},
        'BNB': {'price': 15000, 'symbol': '₺'}
    }

def fetch_gold_prices():
    """Fetch gold prices"""
    try:
        # Try Turkish gold API
        response = requests.get('https://finans.truncgil.com/today.json', timeout=10)
        if response.status_code == 200:
            data = response.json()
            gold_data = data.get('gold', {})
            
            return {
                'GRAM': {
                    'buying': gold_data.get('buying', 2850),
                    'selling': gold_data.get('selling', 2870)
                },
                'QUARTER': {
                    'buying': gold_data.get('quarter_buying', 740),
                    'selling': gold_data.get('quarter_selling', 750)
                },
                'FULL': {
                    'buying': gold_data.get('full_buying', 2950),
                    'selling': gold_data.get('full_selling', 2970)
                }
            }
    except Exception as e:
        print(f"Error fetching gold prices: {e}")
    
    # Fallback prices
    return {
        'GRAM': {'buying': 2850, 'selling': 2870},
        'QUARTER': {'buying': 740, 'selling': 750},
        'FULL': {'buying': 2950, 'selling': 2970}
    }

def get_currency_data():
    """Get all currency data (cached or fresh)"""
    # Try cache first
    cached_data = get_cached_data()
    if cached_data:
        return cached_data
    
    # Fetch fresh data
    try:
        currency_rates = fetch_currency_rates()
        crypto_prices = fetch_crypto_prices()
        gold_prices = fetch_gold_prices()
        
        data = {
            'currencies': currency_rates,
            'crypto': crypto_prices,
            'gold': gold_prices,
            'last_updated': datetime.now().isoformat()
        }
        
        # Cache the data
        save_cached_data(data)
        
        return data
        
    except Exception as e:
        print(f"Error getting currency data: {e}")
        return {
            'currencies': {
                'USD': {'buying': 34.50, 'selling': 34.70},
                'EUR': {'buying': 37.20, 'selling': 37.40},
                'GBP': {'buying': 43.10, 'selling': 43.30}
            },
            'crypto': {
                'BTC': {'price': 1800000, 'symbol': '₺'},
                'ETH': {'price': 120000, 'symbol': '₺'},
                'BNB': {'price': 15000, 'symbol': '₺'}
            },
            'gold': {
                'GRAM': {'buying': 2850, 'selling': 2870},
                'QUARTER': {'buying': 740, 'selling': 750},
                'FULL': {'buying': 2950, 'selling': 2970}
            },
            'last_updated': datetime.now().isoformat()
        }
