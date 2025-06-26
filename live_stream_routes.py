"""
Live Stream Management Routes
Admin interface for managing YouTube live streams
"""

from flask import Blueprint, render_template, request, redirect, url_for, flash, jsonify
from flask_login import login_required, current_user
from models import db, LiveStreamSettings
from functools import wraps
import re

live_stream_bp = Blueprint('live_stream', __name__, url_prefix='/admin/live-stream')

def admin_required(f):
    """Decorator to require admin access"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated:
            return redirect(url_for('admin.login'))
        return f(*args, **kwargs)
    return decorated_function

def extract_youtube_video_id(url):
    """Extract YouTube video ID from various URL formats"""
    patterns = [
        r'youtube\.com/watch\?v=([^&]+)',
        r'youtu\.be/([^?]+)',
        r'youtube\.com/embed/([^?]+)',
        r'youtube\.com/v/([^?]+)'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None

@live_stream_bp.route('/')
@admin_required
def index():
    """Live stream management dashboard"""
    streams = LiveStreamSettings.query.order_by(LiveStreamSettings.created_at.desc()).all()
    active_stream = LiveStreamSettings.query.filter_by(is_active=True).first()
    return render_template('admin/live_stream/index.html', streams=streams, active_stream=active_stream)

@live_stream_bp.route('/create', methods=['GET', 'POST'])
@admin_required
def create():
    """Create new live stream setting"""
    if request.method == 'POST':
        try:
            name = request.form.get('name', '').strip()
            youtube_url = request.form.get('youtube_url', '').strip()
            description = request.form.get('description', '').strip()
            is_default = request.form.get('is_default') == 'on'
            
            if not name or not youtube_url:
                flash('Yayın adı ve YouTube URL\'si zorunludur', 'error')
                return redirect(request.url)
            
            # Extract video ID from URL
            video_id = extract_youtube_video_id(youtube_url)
            if not video_id:
                flash('Geçerli bir YouTube URL\'si giriniz', 'error')
                return redirect(request.url)
            
            # If this is set as default, unset other defaults
            if is_default:
                LiveStreamSettings.query.update({'is_default': False})
            
            # Create new stream setting
            stream = LiveStreamSettings(
                name=name,
                youtube_url=youtube_url,
                youtube_video_id=video_id,
                description=description,
                is_default=is_default,
                is_active=False,  # Starts inactive, admin needs to activate
                admin_id=current_user.id
            )
            
            db.session.add(stream)
            db.session.commit()
            
            flash('Canlı yayın ayarı başarıyla eklendi', 'success')
            return redirect(url_for('live_stream.index'))
            
        except Exception as e:
            flash(f'Yayın ayarı eklenirken hata oluştu: {str(e)}', 'error')
    
    return render_template('admin/live_stream/create.html')

@live_stream_bp.route('/edit/<int:id>', methods=['GET', 'POST'])
@admin_required
def edit(id):
    """Edit live stream setting"""
    stream = LiveStreamSettings.query.get_or_404(id)
    
    if request.method == 'POST':
        try:
            stream.name = request.form.get('name', '').strip()
            youtube_url = request.form.get('youtube_url', '').strip()
            stream.description = request.form.get('description', '').strip()
            is_default = request.form.get('is_default') == 'on'
            
            if not stream.name or not youtube_url:
                flash('Yayın adı ve YouTube URL\'si zorunludur', 'error')
                return redirect(request.url)
            
            # Extract video ID from URL
            video_id = extract_youtube_video_id(youtube_url)
            if not video_id:
                flash('Geçerli bir YouTube URL\'si giriniz', 'error')
                return redirect(request.url)
            
            # Update URL and video ID
            stream.youtube_url = youtube_url
            stream.youtube_video_id = video_id
            
            # If this is set as default, unset other defaults
            if is_default and not stream.is_default:
                LiveStreamSettings.query.filter(LiveStreamSettings.id != id).update({'is_default': False})
            
            stream.is_default = is_default
            
            db.session.commit()
            
            flash('Canlı yayın ayarı başarıyla güncellendi', 'success')
            return redirect(url_for('live_stream.index'))
            
        except Exception as e:
            flash(f'Yayın ayarı güncellenirken hata oluştu: {str(e)}', 'error')
    
    return render_template('admin/live_stream/edit.html', stream=stream)

@live_stream_bp.route('/delete/<int:id>', methods=['POST'])
@admin_required
def delete(id):
    """Delete live stream setting"""
    try:
        stream = LiveStreamSettings.query.get_or_404(id)
        
        # Don't allow deleting active stream
        if stream.is_active:
            flash('Aktif olan yayın ayarı silinemez. Önce başka bir yayını aktifleştirin.', 'error')
            return redirect(url_for('live_stream.index'))
        
        db.session.delete(stream)
        db.session.commit()
        
        flash('Canlı yayın ayarı başarıyla silindi', 'success')
        
    except Exception as e:
        flash(f'Yayın ayarı silinirken hata oluştu: {str(e)}', 'error')
    
    return redirect(url_for('live_stream.index'))

@live_stream_bp.route('/activate/<int:id>', methods=['POST'])
@admin_required
def activate(id):
    """Activate a live stream setting"""
    try:
        # Deactivate all streams first
        LiveStreamSettings.query.update({'is_active': False})
        
        # Activate the selected stream
        stream = LiveStreamSettings.query.get_or_404(id)
        stream.is_active = True
        
        db.session.commit()
        
        flash(f'"{stream.name}" canlı yayını aktifleştirildi', 'success')
        
    except Exception as e:
        flash(f'Yayın aktifleştirilirken hata oluştu: {str(e)}', 'error')
    
    return redirect(url_for('live_stream.index'))

@live_stream_bp.route('/deactivate', methods=['POST'])
@admin_required
def deactivate():
    """Deactivate all live streams"""
    try:
        LiveStreamSettings.query.update({'is_active': False})
        db.session.commit()
        
        flash('Tüm canlı yayınlar deaktif edildi', 'info')
        
    except Exception as e:
        flash(f'Yayınlar deaktif edilirken hata oluştu: {str(e)}', 'error')
    
    return redirect(url_for('live_stream.index'))

@live_stream_bp.route('/api/active')
def get_active_stream():
    """API endpoint to get active live stream"""
    try:
        active_stream = LiveStreamSettings.query.filter_by(is_active=True).first()
        
        if active_stream:
            return jsonify({
                'status': 'success',
                'stream': active_stream.to_dict()
            })
        else:
            # Return default stream if no active stream
            default_stream = LiveStreamSettings.query.filter_by(is_default=True).first()
            if default_stream:
                return jsonify({
                    'status': 'success',
                    'stream': default_stream.to_dict()
                })
            else:
                return jsonify({
                    'status': 'no_stream',
                    'message': 'Aktif canlı yayın bulunamadı'
                })
                
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@live_stream_bp.route('/preview/<int:id>')
@admin_required
def preview(id):
    """Preview a live stream setting"""
    stream = LiveStreamSettings.query.get_or_404(id)
    return render_template('admin/live_stream/preview.html', stream=stream)