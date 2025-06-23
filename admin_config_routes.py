"""
Admin Configuration Management Routes
Web interface for dynamic configuration management
"""

from flask import Blueprint, render_template, request, flash, redirect, url_for, jsonify
from flask_login import login_required, current_user
from functools import wraps
import json
import logging
from utils.config_manager import config_manager, get_config, set_config

logger = logging.getLogger(__name__)

config_bp = Blueprint('config', __name__, url_prefix='/admin/config')

def admin_required(f):
    """Decorator to require admin access"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or not current_user.is_super_admin:
            flash('Bu sayfaya erişim yetkiniz yok.', 'error')
            return redirect(url_for('admin.login'))
        return f(*args, **kwargs)
    return decorated_function

@config_bp.route('/')
@login_required
@admin_required
def index():
    """Configuration management dashboard"""
    try:
        all_config = config_manager.get_all() if config_manager else {}
        
        # Organize config by sections
        sections = {
            'app': {
                'title': 'Uygulama Ayarları',
                'icon': 'fas fa-cogs',
                'config': all_config.get('app', {})
            },
            'news': {
                'title': 'Haber Ayarları',
                'icon': 'fas fa-newspaper',
                'config': all_config.get('news', {})
            },
            'database': {
                'title': 'Veritabanı Ayarları',
                'icon': 'fas fa-database',
                'config': all_config.get('database', {})
            },
            'cache': {
                'title': 'Önbellek Ayarları',
                'icon': 'fas fa-memory',
                'config': all_config.get('cache', {})
            },
            'security': {
                'title': 'Güvenlik Ayarları',
                'icon': 'fas fa-shield-alt',
                'config': all_config.get('security', {})
            },
            'ui': {
                'title': 'Arayüz Ayarları',
                'icon': 'fas fa-palette',
                'config': all_config.get('ui', {})
            },
            'external_apis': {
                'title': 'Harici API Ayarları',
                'icon': 'fas fa-plug',
                'config': all_config.get('external_apis', {})
            },
            'monitoring': {
                'title': 'İzleme Ayarları',
                'icon': 'fas fa-chart-line',
                'config': all_config.get('monitoring', {})
            }
        }
        
        return render_template('admin/config/index.html', sections=sections)
    except Exception as e:
        logger.error(f"Config index error: {e}")
        flash('Konfigürasyon yüklenirken hata oluştu.', 'error')
        return redirect(url_for('admin.dashboard'))

@config_bp.route('/section/<section>')
@login_required
@admin_required
def section(section):
    """Edit specific configuration section"""
    try:
        if not config_manager:
            flash('Konfigürasyon yöneticisi başlatılmamış.', 'error')
            return redirect(url_for('config.index'))
        
        section_config = config_manager.get_section(section)
        
        # Section metadata
        section_info = {
            'app': {
                'title': 'Uygulama Ayarları',
                'description': 'Temel uygulama konfigürasyonu'
            },
            'news': {
                'title': 'Haber Ayarları',
                'description': 'Haber çekme ve gösterim ayarları'
            },
            'database': {
                'title': 'Veritabanı Ayarları',
                'description': 'Veritabanı bağlantı ayarları'
            },
            'cache': {
                'title': 'Önbellek Ayarları',
                'description': 'Önbellek süresi ve aktivasyon ayarları'
            },
            'security': {
                'title': 'Güvenlik Ayarları',
                'description': 'CSRF, oturum ve güvenlik ayarları'
            },
            'ui': {
                'title': 'Arayüz Ayarları',
                'description': 'Site görünümü ve kullanıcı arayüzü ayarları'
            },
            'external_apis': {
                'title': 'Harici API Ayarları',
                'description': 'Dış servis entegrasyonları'
            },
            'monitoring': {
                'title': 'İzleme Ayarları',
                'description': 'Log ve performans izleme ayarları'
            }
        }.get(section, {'title': section.title(), 'description': ''})
        
        return render_template('admin/config/section.html',
                             section=section,
                             section_info=section_info,
                             config=section_config)
    except Exception as e:
        logger.error(f"Config section error: {e}")
        flash('Konfigürasyon bölümü yüklenirken hata oluştu.', 'error')
        return redirect(url_for('config.index'))

@config_bp.route('/update', methods=['POST'])
@login_required
@admin_required
def update():
    """Update configuration values"""
    try:
        if not config_manager:
            return jsonify({'success': False, 'error': 'Konfigürasyon yöneticisi başlatılmamış'})
        
        updates = request.get_json()
        if not updates:
            return jsonify({'success': False, 'error': 'Güncellenecek veri bulunamadı'})
        
        # Process updates
        processed_updates = {}
        for key, value in updates.items():
            # Convert string values to appropriate types
            if isinstance(value, str):
                if value.lower() == 'true':
                    value = True
                elif value.lower() == 'false':
                    value = False
                elif value.isdigit():
                    value = int(value)
                elif value.replace('.', '').isdigit():
                    value = float(value)
            
            processed_updates[key] = value
        
        # Apply updates
        success = config_manager.update(processed_updates, persist=True)
        
        if success:
            logger.info(f"Configuration updated by {current_user.username}: {list(processed_updates.keys())}")
            return jsonify({'success': True, 'message': 'Konfigürasyon başarıyla güncellendi'})
        else:
            return jsonify({'success': False, 'error': 'Konfigürasyon güncellenirken hata oluştu'})
    
    except Exception as e:
        logger.error(f"Config update error: {e}")
        return jsonify({'success': False, 'error': str(e)})

@config_bp.route('/reset/<section>', methods=['POST'])
@login_required
@admin_required
def reset_section(section):
    """Reset configuration section to defaults"""
    try:
        if not config_manager:
            flash('Konfigürasyon yöneticisi başlatılmamış.', 'error')
            return redirect(url_for('config.index'))
        
        success = config_manager.reset_to_defaults(section)
        
        if success:
            flash(f'{section.title()} bölümü varsayılan ayarlara sıfırlandı.', 'success')
            logger.info(f"Configuration section {section} reset by {current_user.username}")
        else:
            flash('Konfigürasyon sıfırlanırken hata oluştu.', 'error')
        
        return redirect(url_for('config.section', section=section))
    
    except Exception as e:
        logger.error(f"Config reset error: {e}")
        flash('Konfigürasyon sıfırlanırken hata oluştu.', 'error')
        return redirect(url_for('config.index'))

@config_bp.route('/export')
@login_required
@admin_required
def export():
    """Export configuration as JSON"""
    try:
        if not config_manager:
            return jsonify({'error': 'Konfigürasyon yöneticisi başlatılmamış'}), 500
        
        config_data = config_manager.get_all()
        
        # Add export metadata
        export_data = {
            '_export_info': {
                'exported_by': current_user.username,
                'exported_at': datetime.utcnow().isoformat(),
                'version': '1.0'
            },
            **config_data
        }
        
        from flask import make_response
        from datetime import datetime
        
        response = make_response(json.dumps(export_data, indent=2, ensure_ascii=False))
        response.headers['Content-Type'] = 'application/json'
        response.headers['Content-Disposition'] = f'attachment; filename=ayyildizhaber_config_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        
        logger.info(f"Configuration exported by {current_user.username}")
        return response
    
    except Exception as e:
        logger.error(f"Config export error: {e}")
        return jsonify({'error': str(e)}), 500

@config_bp.route('/import', methods=['POST'])
@login_required
@admin_required
def import_config():
    """Import configuration from JSON file"""
    try:
        if not config_manager:
            flash('Konfigürasyon yöneticisi başlatılmamış.', 'error')
            return redirect(url_for('config.index'))
        
        if 'config_file' not in request.files:
            flash('Dosya seçilmedi.', 'error')
            return redirect(url_for('config.index'))
        
        file = request.files['config_file']
        if file.filename == '':
            flash('Dosya seçilmedi.', 'error')
            return redirect(url_for('config.index'))
        
        if not file.filename.endswith('.json'):
            flash('Sadece JSON dosyaları kabul edilir.', 'error')
            return redirect(url_for('config.index'))
        
        # Read and parse JSON
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w+', suffix='.json', delete=False) as tmp_file:
            file.save(tmp_file.name)
            
            merge = request.form.get('merge', 'true').lower() == 'true'
            success = config_manager.import_config(tmp_file.name, merge=merge)
            
            import os
            os.unlink(tmp_file.name)
        
        if success:
            flash('Konfigürasyon başarıyla içe aktarıldı.', 'success')
            logger.info(f"Configuration imported by {current_user.username}")
        else:
            flash('Konfigürasyon içe aktarılırken hata oluştu.', 'error')
        
        return redirect(url_for('config.index'))
    
    except Exception as e:
        logger.error(f"Config import error: {e}")
        flash('Konfigürasyon içe aktarılırken hata oluştu.', 'error')
        return redirect(url_for('config.index'))

@config_bp.route('/api/get/<path:key>')
@login_required
@admin_required
def api_get(key):
    """API endpoint to get configuration value"""
    try:
        value = get_config(key)
        return jsonify({'success': True, 'value': value})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@config_bp.route('/api/set', methods=['POST'])
@login_required
@admin_required
def api_set():
    """API endpoint to set configuration value"""
    try:
        data = request.get_json()
        key = data.get('key')
        value = data.get('value')
        persist = data.get('persist', True)
        
        if not key:
            return jsonify({'success': False, 'error': 'Key is required'})
        
        success = set_config(key, value, persist)
        return jsonify({'success': success})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})