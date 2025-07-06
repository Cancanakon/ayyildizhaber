"""
Advertisement Management Routes
Admin interface for managing ads on the website
"""

from flask import Blueprint, render_template, request, redirect, url_for, flash, jsonify
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
import os
import json
from datetime import datetime
from models import db, Advertisement
from functools import wraps

ad_bp = Blueprint('ads', __name__, url_prefix='/admin/ads')

def admin_required(f):
    """Decorator to require admin access"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated:
            return redirect(url_for('admin.login'))
        return f(*args, **kwargs)
    return decorated_function

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
UPLOAD_FOLDER = 'static/uploads/ads'

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@ad_bp.route('/')
@admin_required
def index():
    """Advertisement management dashboard"""
    ads = Advertisement.query.order_by(Advertisement.created_at.desc()).all()
    return render_template('admin/ads/index.html', ads=ads)

@ad_bp.route('/create', methods=['GET', 'POST'])
@admin_required
def create():
    """Create new advertisement"""
    if request.method == 'POST':
        try:
            # Get form data
            ad_type = request.form.get('ad_type')
            position = request.form.get('position')
            title = request.form.get('title', '')
            link_url = request.form.get('link_url', '')
            is_active = request.form.get('is_active') == 'on'
            
            # Handle file upload
            if 'image' not in request.files:
                flash('Reklam görseli seçilmedi', 'error')
                return redirect(request.url)
            
            file = request.files['image']
            if file.filename == '':
                flash('Dosya seçilmedi', 'error')
                return redirect(request.url)
            
            if file and file.filename and allowed_file(file.filename):
                # Ensure upload directory exists
                os.makedirs(UPLOAD_FOLDER, exist_ok=True)
                
                # Generate unique filename
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = secure_filename(file.filename)
                name, ext = os.path.splitext(filename)
                unique_filename = f"{name}_{timestamp}{ext}"
                
                file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
                file.save(file_path)
                
                # Get additional form data
                slot_number = request.form.get('slot_number', type=int) or 1
                description = request.form.get('description', '')
                
                # Validate slot number for sidebar ads
                if ad_type == 'sidebar' and (slot_number < 1 or slot_number > 2):
                    flash('Sidebar reklamlar için slot numarası 1 veya 2 olmalıdır', 'error')
                    return redirect(request.url)
                
                # Set position for banner ads
                if ad_type == 'top_banner':
                    position = 'top'
                elif ad_type == 'bottom_banner':
                    position = 'bottom'
                
                # Validate - only one active banner per position
                if ad_type in ['top_banner', 'bottom_banner']:
                    existing_banner = Advertisement.query.filter_by(
                        ad_type=ad_type,
                        is_active=True
                    ).first()
                    if existing_banner:
                        flash(f'Bu pozisyon için zaten aktif bir banner bulunmaktadır', 'error')
                        return redirect(request.url)
                
                # Check if slot is already occupied
                if ad_type == 'sidebar':
                    existing_ad = Advertisement.query.filter_by(
                        ad_type='sidebar',
                        position=position,
                        slot_number=slot_number,
                        is_active=True
                    ).first()
                    
                    if existing_ad:
                        flash(f'{position.title()} tarafında {slot_number}. slot zaten dolu', 'error')
                        return redirect(url_for('ads.create'))
                
                # Create advertisement record
                ad = Advertisement()
                ad.ad_type = ad_type
                ad.position = position
                ad.slot_number = slot_number if ad_type == 'sidebar' else None
                ad.title = title
                ad.description = description
                ad.image_path = f'/static/uploads/ads/{unique_filename}'
                ad.link_url = link_url
                ad.is_active = is_active
                ad.admin_id = current_user.id
                
                db.session.add(ad)
                db.session.commit()
                
                flash('Reklam başarıyla eklendi', 'success')
                return redirect(url_for('ads.index'))
            else:
                flash('Geçersiz dosya formatı. Sadece resim dosyaları kabul edilir.', 'error')
        
        except Exception as e:
            flash(f'Reklam eklenirken hata oluştu: {str(e)}', 'error')
    
    return render_template('admin/ads/create.html')

@ad_bp.route('/edit/<int:id>', methods=['GET', 'POST'])
@admin_required
def edit(id):
    """Edit advertisement"""
    ad = Advertisement.query.get_or_404(id)
    
    if request.method == 'POST':
        try:
            # Update basic fields
            ad.ad_type = request.form.get('ad_type')
            ad.position = request.form.get('position')
            ad.title = request.form.get('title', '')
            ad.link_url = request.form.get('link_url', '')
            ad.is_active = request.form.get('is_active') == 'on'
            ad.updated_at = datetime.utcnow()
            
            # Handle new image upload if provided
            if 'image' in request.files and request.files['image'].filename != '':
                file = request.files['image']
                if file and file.filename and allowed_file(file.filename):
                    # Delete old image
                    if ad.image_path and os.path.exists(ad.image_path.lstrip('/')):
                        os.remove(ad.image_path.lstrip('/'))
                    
                    # Save new image
                    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
                    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                    filename = secure_filename(file.filename)
                    name, ext = os.path.splitext(filename)
                    unique_filename = f"{name}_{timestamp}{ext}"
                    
                    file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
                    file.save(file_path)
                    ad.image_path = f'/static/uploads/ads/{unique_filename}'
            
            db.session.commit()
            flash('Reklam başarıyla güncellendi', 'success')
            return redirect(url_for('ads.index'))
            
        except Exception as e:
            flash(f'Reklam güncellenirken hata oluştu: {str(e)}', 'error')
    
    return render_template('admin/ads/edit.html', ad=ad)

@ad_bp.route('/delete/<int:id>', methods=['POST'])
@admin_required
def delete(id):
    """Delete advertisement"""
    try:
        ad = Advertisement.query.get_or_404(id)
        
        # Delete image file
        if ad.image_path and os.path.exists(ad.image_path.lstrip('/')):
            os.remove(ad.image_path.lstrip('/'))
        
        db.session.delete(ad)
        db.session.commit()
        
        flash('Reklam başarıyla silindi', 'success')
    except Exception as e:
        flash(f'Reklam silinirken hata oluştu: {str(e)}', 'error')
    
    return redirect(url_for('ads.index'))

@ad_bp.route('/toggle/<int:id>', methods=['POST'])
@admin_required
def toggle_status(id):
    """Toggle advertisement active status"""
    try:
        ad = Advertisement.query.get_or_404(id)
        ad.is_active = not ad.is_active
        ad.updated_at = datetime.utcnow()
        db.session.commit()
        
        status = 'aktif' if ad.is_active else 'pasif'
        flash(f'Reklam durumu {status} olarak değiştirildi', 'success')
    except Exception as e:
        flash(f'Durum değiştirilirken hata oluştu: {str(e)}', 'error')
    
    return redirect(url_for('ads.index'))

@ad_bp.route('/api/active-ads')
def get_active_ads():
    """API endpoint to get active advertisements"""
    try:
        # Get sidebar ads - 2 per side for vertical layout
        left_ads = Advertisement.query.filter_by(
            is_active=True, 
            ad_type='sidebar',
            position='left'
        ).order_by(Advertisement.slot_number.asc()).limit(2).all()
        
        right_ads = Advertisement.query.filter_by(
            is_active=True, 
            ad_type='sidebar',
            position='right'
        ).order_by(Advertisement.slot_number.asc()).limit(2).all()
        
        popup_ads = Advertisement.query.filter_by(
            is_active=True, 
            ad_type='popup'
        ).order_by(Advertisement.created_at.desc()).limit(1).all()
        
        result = {
            'sidebar_left': [ad.to_dict() for ad in left_ads],
            'sidebar_right': [ad.to_dict() for ad in right_ads],
            'popup': [ad.to_dict() for ad in popup_ads]
        }
        
        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500