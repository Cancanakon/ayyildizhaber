"""
Dynamic Environment Configuration Manager
Manages application configuration with runtime updates and validation
"""

import os
import json
import logging
from typing import Dict, Any, Optional, Union
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)

class ConfigManager:
    """Dynamic configuration manager with live updates and validation"""
    
    def __init__(self, config_file: str = None, app=None):
        self.app = app
        self.config_file = config_file or os.path.join(os.getcwd(), 'config', 'dynamic_config.json')
        self.config_dir = os.path.dirname(self.config_file)
        self._config = {}
        self._watchers = {}
        self._default_config = self._get_default_config()
        self._ensure_config_dir()
        self.load_config()
    
    def _ensure_config_dir(self):
        """Ensure configuration directory exists"""
        Path(self.config_dir).mkdir(parents=True, exist_ok=True)
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Default configuration values"""
        return {
            "app": {
                "debug": False,
                "secret_key": os.environ.get("SESSION_SECRET", "default-dev-key"),
                "max_content_length": 16 * 1024 * 1024,  # 16MB
                "upload_folder": "static/uploads",
                "allowed_extensions": ["png", "jpg", "jpeg", "gif", "webp"]
            },
            "database": {
                "url": os.environ.get("DATABASE_URL", "sqlite:///ayyildizhaber.db"),
                "pool_size": 10,
                "pool_recycle": 3600,
                "pool_pre_ping": True
            },
            "news": {
                "auto_fetch_enabled": True,
                "fetch_interval_minutes": 15,
                "max_news_per_category": 15,
                "featured_news_count": 6,
                "latest_news_count": 8,
                "yerel_news_count": 4
            },
            "cache": {
                "enabled": True,
                "default_timeout": 300,
                "weather_timeout": 1800,
                "currency_timeout": 3600,
                "prayer_timeout": 3600
            },
            "security": {
                "csrf_enabled": True,
                "csrf_time_limit": 3600,
                "session_timeout": 7200,
                "max_login_attempts": 5,
                "lockout_duration": 900
            },
            "ui": {
                "site_name": "Ayyıldız Haber Ajansı",
                "site_description": "Güncel haberler ve son dakika gelişmeleri",
                "theme_color": "#dc2626",
                "items_per_page": 12,
                "search_results_per_page": 20
            },
            "external_apis": {
                "weather_enabled": True,
                "currency_enabled": True,
                "prayer_times_enabled": True,
                "trt_news_enabled": True
            },
            "monitoring": {
                "log_level": "INFO",
                "enable_metrics": True,
                "stats_collection": True,
                "error_reporting": True
            }
        }
    
    def load_config(self) -> bool:
        """Load configuration from file, create if doesn't exist"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    file_config = json.load(f)
                
                # Merge with defaults
                self._config = self._deep_merge(self._default_config, file_config)
                logger.info(f"Configuration loaded from {self.config_file}")
            else:
                # Create default config file
                self._config = self._default_config.copy()
                self.save_config()
                logger.info(f"Created default configuration at {self.config_file}")
            
            return True
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            self._config = self._default_config.copy()
            return False
    
    def save_config(self) -> bool:
        """Save current configuration to file"""
        try:
            # Add metadata
            config_with_meta = {
                "_metadata": {
                    "last_updated": datetime.utcnow().isoformat(),
                    "version": "1.0"
                },
                **self._config
            }
            
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config_with_meta, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Configuration saved to {self.config_file}")
            return True
        except Exception as e:
            logger.error(f"Failed to save configuration: {e}")
            return False
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value by dot notation key"""
        try:
            keys = key.split('.')
            value = self._config
            
            for k in keys:
                if isinstance(value, dict) and k in value:
                    value = value[k]
                else:
                    return default
            
            return value
        except Exception:
            return default
    
    def set(self, key: str, value: Any, persist: bool = True) -> bool:
        """Set configuration value by dot notation key"""
        try:
            keys = key.split('.')
            config = self._config
            
            # Navigate to parent
            for k in keys[:-1]:
                if k not in config:
                    config[k] = {}
                config = config[k]
            
            # Set value
            old_value = config.get(keys[-1])
            config[keys[-1]] = value
            
            # Validate
            if not self._validate_config():
                config[keys[-1]] = old_value  # Rollback
                return False
            
            # Save if requested
            if persist:
                self.save_config()
            
            # Notify watchers
            self._notify_watchers(key, value, old_value)
            
            logger.info(f"Configuration updated: {key} = {value}")
            return True
        except Exception as e:
            logger.error(f"Failed to set configuration {key}: {e}")
            return False
    
    def update(self, updates: Dict[str, Any], persist: bool = True) -> bool:
        """Update multiple configuration values"""
        try:
            # Store backup
            backup = self._config.copy()
            
            # Apply updates
            for key, value in updates.items():
                if not self.set(key, value, persist=False):
                    # Rollback on failure
                    self._config = backup
                    return False
            
            # Validate entire config
            if not self._validate_config():
                self._config = backup
                return False
            
            # Save if requested
            if persist:
                self.save_config()
            
            logger.info(f"Configuration batch update completed: {len(updates)} items")
            return True
        except Exception as e:
            logger.error(f"Failed to update configuration: {e}")
            return False
    
    def reset_to_defaults(self, section: str = None) -> bool:
        """Reset configuration to defaults"""
        try:
            if section:
                if section in self._default_config:
                    self._config[section] = self._default_config[section].copy()
                    logger.info(f"Reset section '{section}' to defaults")
                else:
                    return False
            else:
                self._config = self._default_config.copy()
                logger.info("Reset entire configuration to defaults")
            
            self.save_config()
            return True
        except Exception as e:
            logger.error(f"Failed to reset configuration: {e}")
            return False
    
    def watch(self, key: str, callback: callable):
        """Watch for changes to a configuration key"""
        if key not in self._watchers:
            self._watchers[key] = []
        self._watchers[key].append(callback)
    
    def _notify_watchers(self, key: str, new_value: Any, old_value: Any):
        """Notify watchers of configuration changes"""
        for pattern in self._watchers:
            if key.startswith(pattern) or pattern == "*":
                for callback in self._watchers[pattern]:
                    try:
                        callback(key, new_value, old_value)
                    except Exception as e:
                        logger.error(f"Watcher callback failed for {key}: {e}")
    
    def _validate_config(self) -> bool:
        """Validate configuration values"""
        try:
            # Validate app settings
            app_config = self.get('app', {})
            if app_config.get('max_content_length', 0) <= 0:
                logger.error("Invalid max_content_length")
                return False
            
            # Validate news settings
            news_config = self.get('news', {})
            if news_config.get('fetch_interval_minutes', 0) < 1:
                logger.error("Invalid fetch_interval_minutes")
                return False
            
            # Validate cache settings
            cache_config = self.get('cache', {})
            if cache_config.get('default_timeout', 0) <= 0:
                logger.error("Invalid cache timeout")
                return False
            
            return True
        except Exception as e:
            logger.error(f"Configuration validation failed: {e}")
            return False
    
    def _deep_merge(self, base: dict, override: dict) -> dict:
        """Deep merge dictionaries"""
        result = base.copy()
        
        for key, value in override.items():
            if key == "_metadata":
                continue  # Skip metadata
            
            if (key in result and 
                isinstance(result[key], dict) and 
                isinstance(value, dict)):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = value
        
        return result
    
    def get_all(self) -> Dict[str, Any]:
        """Get all configuration as dictionary"""
        return self._config.copy()
    
    def get_section(self, section: str) -> Dict[str, Any]:
        """Get entire configuration section"""
        return self.get(section, {})
    
    def export_config(self, filepath: str) -> bool:
        """Export configuration to file"""
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(self._config, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            logger.error(f"Failed to export configuration: {e}")
            return False
    
    def import_config(self, filepath: str, merge: bool = True) -> bool:
        """Import configuration from file"""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                imported_config = json.load(f)
            
            if merge:
                self._config = self._deep_merge(self._config, imported_config)
            else:
                self._config = imported_config
            
            if self._validate_config():
                self.save_config()
                return True
            else:
                return False
        except Exception as e:
            logger.error(f"Failed to import configuration: {e}")
            return False

# Global configuration manager instance
config_manager = None

def init_config_manager(app=None, config_file=None):
    """Initialize global configuration manager"""
    global config_manager
    config_manager = ConfigManager(config_file, app)
    return config_manager

def get_config(key: str, default: Any = None) -> Any:
    """Get configuration value"""
    if config_manager:
        return config_manager.get(key, default)
    return default

def set_config(key: str, value: Any, persist: bool = True) -> bool:
    """Set configuration value"""
    if config_manager:
        return config_manager.set(key, value, persist)
    return False