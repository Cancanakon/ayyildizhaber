import requests
import json
import os
import logging
from datetime import datetime, timedelta

CACHE_FILE = 'cache/currency_data.json'
CACHE_DURATION = timedelta(hours=3)  # Cache for 3 hours

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
        logging.error(f"Error saving cache: {e}")

def fetch_currency_rates():
    """Fetch current currency rates from Kapali Carsi API"""
    try:
        logging.info("Fetching currency rates from Kapali Carsi API...")
        
        response = requests.get('https://kapalicarsi.apiluna.org/', timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            
            # Find currency data
            usd_data = next((item for item in data if item.get('code') == 'USD'), None)
            eur_data = next((item for item in data if item.get('code') == 'EUR'), None)
            gbp_data = next((item for item in data if item.get('code') == 'GBP'), None)
            
            rates = {}
            
            if usd_data:
                rates['USD'] = {
                    'buying': round(float(usd_data.get('alis', 34.5)), 2),
                    'selling': round(float(usd_data.get('satis', 34.7)), 2),
                    'change': round(float(usd_data.get('kapanis', 0)), 2)
                }
            
            if eur_data:
                rates['EUR'] = {
                    'buying': round(float(eur_data.get('alis', 37.2)), 2),
                    'selling': round(float(eur_data.get('satis', 37.4)), 2),
                    'change': round(float(eur_data.get('kapanis', 0)), 2)
                }
            
            if gbp_data:
                rates['GBP'] = {
                    'buying': round(float(gbp_data.get('alis', 43.1)), 2),
                    'selling': round(float(gbp_data.get('satis', 43.3)), 2),
                    'change': round(float(gbp_data.get('kapanis', 0)), 2)
                }
            
            return rates if rates else None
            
    except Exception as e:
        logging.error(f"Error fetching currency rates from Kapali Carsi: {e}")
        return None

def fetch_gold_prices():
    """Fetch real gold prices from Kapali Carsi API"""
    try:
        logging.info("Fetching gold prices from Kapali Carsi API...")
        
        response = requests.get('https://kapalicarsi.apiluna.org/', timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            
            # Find specific gold types
            gram_gold = next((item for item in data if item.get('code') == 'ALTIN'), None)
            quarter_gold = next((item for item in data if item.get('code') == 'CEYREK_YENI'), None)
            full_gold = next((item for item in data if item.get('code') == 'TEK_YENI'), None)
            half_gold = next((item for item in data if item.get('code') == 'YARIM_YENI'), None)
            
            gold_data = {}
            
            if gram_gold:
                gold_data['gram'] = {
                    'buying': round(float(gram_gold.get('alis', 2850)), 2),
                    'selling': round(float(gram_gold.get('satis', 2870)), 2),
                    'change': round(float(gram_gold.get('kapanis', 0)), 2)
                }
            
            if quarter_gold:
                gold_data['quarter'] = {
                    'buying': round(float(quarter_gold.get('alis', 900)), 2),
                    'selling': round(float(quarter_gold.get('satis', 920)), 2),
                    'change': round(float(quarter_gold.get('kapanis', 0)), 2)
                }
            
            if half_gold:
                gold_data['half'] = {
                    'buying': round(float(half_gold.get('alis', 1800)), 2),
                    'selling': round(float(half_gold.get('satis', 1820)), 2),
                    'change': round(float(half_gold.get('kapanis', 0)), 2)
                }
            
            if full_gold:
                gold_data['full'] = {
                    'buying': round(float(full_gold.get('alis', 3600)), 2),
                    'selling': round(float(full_gold.get('satis', 3650)), 2),
                    'change': round(float(full_gold.get('kapanis', 0)), 2)
                }
            
            return gold_data if gold_data else None
            
    except Exception as e:
        logging.error(f"Error fetching gold prices from Kapali Carsi: {e}")
        return None

def fetch_crypto_prices():
    """Fetch cryptocurrency prices from CoinGecko API"""
    try:
        logging.info("Fetching crypto prices from CoinGecko API...")
        
        response = requests.get(
            'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,binancecoin&vs_currencies=try',
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            
            crypto_data = {}
            
            if 'bitcoin' in data:
                btc_price = data['bitcoin']['try']
                crypto_data['BTC'] = {
                    'buying': round(btc_price, 0),
                    'selling': round(btc_price * 1.01, 0),
                    'change': 0.0
                }
            
            if 'ethereum' in data:
                eth_price = data['ethereum']['try']
                crypto_data['ETH'] = {
                    'buying': round(eth_price, 0),
                    'selling': round(eth_price * 1.01, 0),
                    'change': 0.0
                }
                
            if 'binancecoin' in data:
                bnb_price = data['binancecoin']['try']
                crypto_data['BNB'] = {
                    'buying': round(bnb_price, 0),
                    'selling': round(bnb_price * 1.01, 0),
                    'change': 0.0
                }
            
            return crypto_data
            
    except Exception as e:
        logging.error(f"Error fetching crypto prices: {e}")
        return None

def get_currency_data():
    """Get all currency data (cached or fresh)"""
    try:
        # Get cached data first
        cached_data = get_cached_data()
        if cached_data:
            return cached_data
        
        # Fetch fresh data
        logging.info("Fetching fresh currency data from Kapali Carsi and CoinGecko...")
        
        currency_rates = fetch_currency_rates()
        gold_prices = fetch_gold_prices()
        crypto_prices = fetch_crypto_prices()
        
        if not currency_rates and not gold_prices and not crypto_prices:
            logging.warning("No data available from any source")
            return None
        
        data = {
            'currency': currency_rates or {},
            'gold': gold_prices or {},
            'crypto': crypto_prices or {},
            'last_updated': datetime.now().isoformat(),
            'source': 'Kapali Carsi & CoinGecko'
        }
        
        # Save to cache
        save_cached_data(data)
        logging.info(f"Currency data updated successfully: {len(data.get('currency', {}))} currencies, {len(data.get('gold', {}))} gold types, {len(data.get('crypto', {}))} cryptocurrencies")
        
        return data
        
    except Exception as e:
        logging.error(f"Error getting currency data: {e}")
        return None