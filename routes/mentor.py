from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import login_required, current_user
from models import Mentor, Student, Verification, Internship, VerificationLedger
from models import db
from datetime import datetime
from functools import wraps
import hashlib

mentor_bp = Blueprint('mentor', __name__)

def mentor_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not hasattr(current_user, 'mentor_id'):
            flash('Access denied. Mentors only.', 'danger')
            return redirect(url_for('auth.index'))
        return f(*args, **kwargs)
    return decorated_function

@mentor_bp.route('/dashboard')
@login_required
@mentor_required
def dashboard():
    students = Student.query.filter_by(mentor_id=current_user.mentor_id).all()
    pending_verifications = Verification.query.filter_by(
        mentor_id=current_user.mentor_id,
        status='Pending'
    ).count()
    
    return render_template('mentor/dashboard.html', 
                         students=students,
                         pending_verifications=pending_verifications)

@mentor_bp.route('/students')
@login_required
@mentor_required
def students():
    students = Student.query.filter_by(mentor_id=current_user.mentor_id).all()
    return render_template('mentor/students.html', students=students)

@mentor_bp.route('/verifications')
@login_required
@mentor_required
def verifications():
    verifications = Verification.query.filter_by(mentor_id=current_user.mentor_id).all()
    return render_template('mentor/verifications.html', verifications=verifications)

@mentor_bp.route('/verification/<int:verification_id>')
@login_required
@mentor_required
def view_verification(verification_id):
    verification = Verification.query.get_or_404(verification_id)
    if verification.mentor_id != current_user.mentor_id:
        flash('Access denied', 'danger')
        return redirect(url_for('mentor.verifications'))
    
    return render_template('mentor/view_verification.html', verification=verification)

@mentor_bp.route('/verification/<int:verification_id>/approve', methods=['POST'])
@login_required
@mentor_required
def approve_verification(verification_id):
    verification = Verification.query.get_or_404(verification_id)
    if verification.mentor_id != current_user.mentor_id:
        flash('Access denied', 'danger')
        return redirect(url_for('mentor.verifications'))
    
    try:
        rating = int(request.form.get('rating', 0))
        comments = request.form.get('comments', '')
        
        verification.status = 'Approved'
        verification.rating = rating
        verification.comments = comments
        verification.verified_on = datetime.utcnow()
        
        # Add to verification ledger with hash
        add_to_ledger(verification.internship_id, current_user.mentor_id, 'APPROVE')
        
        db.session.commit()
        flash('Internship verified successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error verifying internship: {str(e)}', 'danger')
    
    return redirect(url_for('mentor.verifications'))

@mentor_bp.route('/verification/<int:verification_id>/reject', methods=['POST'])
@login_required
@mentor_required
def reject_verification(verification_id):
    verification = Verification.query.get_or_404(verification_id)
    if verification.mentor_id != current_user.mentor_id:
        flash('Access denied', 'danger')
        return redirect(url_for('mentor.verifications'))
    
    try:
        comments = request.form.get('comments', '')
        
        verification.status = 'Rejected'
        verification.comments = comments
        verification.verified_on = datetime.utcnow()
        
        # Add to verification ledger
        add_to_ledger(verification.internship_id, current_user.mentor_id, 'REJECT')
        
        db.session.commit()
        flash('Internship rejected', 'info')
    except Exception as e:
        db.session.rollback()
        flash(f'Error rejecting internship: {str(e)}', 'danger')
    
    return redirect(url_for('mentor.verifications'))

def add_to_ledger(internship_id, mentor_id, action):
    """Add entry to verification ledger with hash chaining"""
    # Get previous hash
    last_entry = VerificationLedger.query.filter_by(
        internship_id=internship_id
    ).order_by(VerificationLedger.timestamp.desc()).first()
    
    previous_hash = last_entry.hash_value if last_entry else None
    timestamp = datetime.utcnow()
    
    # Create hash
    hash_input = f"{internship_id}|{mentor_id}|{action}|{timestamp.isoformat()}"
    if previous_hash:
        hash_input = f"{previous_hash}|{hash_input}"
    
    hash_value = hashlib.sha256(hash_input.encode()).hexdigest()
    
    # Create ledger entry
    ledger_entry = VerificationLedger(
        internship_id=internship_id,
        mentor_id=mentor_id,
        action=action,
        hash_value=hash_value,
        previous_hash=previous_hash,
        timestamp=timestamp
    )
    db.session.add(ledger_entry)
