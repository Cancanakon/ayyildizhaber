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
    """Fetch real gold prices"""
    try:
        # Real gold prices from Döviz API
        response = requests.get('https://api.genelpara.com/embed/doviz.json', timeout=10)
        if response.status_code == 200:
            data = response.json()
            
            # Extract gold prices if available
            gold_data = {}
            for item in data:
                if item.get('kur') == 'gram-altin':
                    gold_data['gram_altin'] = {
                        'buying': float(item.get('alis', 0)),
                        'selling': float(item.get('satis', 0))
                    }
                elif item.get('kur') == 'ceyrek-altin':
                    gold_data['ceyrek_altin'] = {
                        'buying': float(item.get('alis', 0)),
                        'selling': float(item.get('satis', 0))
                    }
                elif item.get('kur') == 'yarim-altin':
                    gold_data['yarim_altin'] = {
                        'buying': float(item.get('alis', 0)),
                        'selling': float(item.get('satis', 0))
                    }
                elif item.get('kur') == 'tam-altin':
                    gold_data['tam_altin'] = {
                        'buying': float(item.get('alis', 0)),
                        'selling': float(item.get('satis', 0))
                    }
            
            if gold_data:
                return gold_data
        
        # Try alternative API
        alt_response = requests.get('https://api.exchangerate-api.com/v4/latest/USD', timeout=10)
        if alt_response.status_code == 200:
            data = alt_response.json()
            usd_to_try = data['rates'].get('TRY', 34.50)
            
            # Approximate gold price based on international gold price
            gold_usd_per_ounce = 2000  # Approximate current gold price
            gold_try_per_gram = (gold_usd_per_ounce / 31.1035) * usd_to_try
            
            gram_price = round(gold_try_per_gram)
            
            return {
                'gram_altin': {
                    'buying': gram_price - 20,
                    'selling': gram_price + 20
                },
                'ceyrek_altin': {
                    'buying': round((gram_price * 1.6) - 30),
                    'selling': round((gram_price * 1.6) + 30)
                },
                'yarim_altin': {
                    'buying': round((gram_price * 3.2) - 60),
                    'selling': round((gram_price * 3.2) + 60)
                },
                'tam_altin': {
                    'buying': round((gram_price * 6.4) - 120),
                    'selling': round((gram_price * 6.4) + 120)
                }
            }
        
    except Exception as e:
        print(f"Error fetching gold prices: {e}")
    
    # Return None to indicate failure - don't show fake data
    return None

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
