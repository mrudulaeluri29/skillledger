from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import login_required, current_user
from models import Company, InternshipPosting, Application
from models import db
from datetime import datetime
from functools import wraps

company_bp = Blueprint('company', __name__)

def company_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not hasattr(current_user, 'company_id'):
            flash('Access denied. Companies only.', 'danger')
            return redirect(url_for('auth.index'))
        return f(*args, **kwargs)
    return decorated_function

@company_bp.route('/dashboard')
@login_required
@company_required
def dashboard():
    if current_user.verified_status != 'Verified':
        flash('Your company account is pending verification', 'warning')
    
    postings = InternshipPosting.query.filter_by(company_id=current_user.company_id).all()
    total_applications = sum(len(p.applications) for p in postings)
    
    return render_template('company/dashboard.html',
                         postings=postings,
                         total_applications=total_applications,
                         verified_status=current_user.verified_status)

@company_bp.route('/postings')
@login_required
@company_required
def postings():
    postings = InternshipPosting.query.filter_by(company_id=current_user.company_id).all()
    return render_template('company/postings.html', postings=postings)

@company_bp.route('/posting/add', methods=['GET', 'POST'])
@login_required
@company_required
def add_posting():
    if current_user.verified_status != 'Verified':
        flash('Only verified companies can create postings', 'danger')
        return redirect(url_for('company.dashboard'))
    
    if request.method == 'POST':
        try:
            deadline_str = request.form.get('application_deadline')
            deadline = datetime.strptime(deadline_str, '%Y-%m-%d').date() if deadline_str else None
            
            posting = InternshipPosting(
                company_id=current_user.company_id,
                title=request.form.get('title'),
                description=request.form.get('description'),
                location=request.form.get('location'),
                duration=request.form.get('duration'),
                application_deadline=deadline,
                is_active=True
            )
            db.session.add(posting)
            db.session.commit()
            flash('Posting created successfully!', 'success')
            return redirect(url_for('company.postings'))
        except Exception as e:
            db.session.rollback()
            flash(f'Error creating posting: {str(e)}', 'danger')
    
    return render_template('company/add_posting.html')

@company_bp.route('/posting/<int:posting_id>')
@login_required
@company_required
def view_posting(posting_id):
    posting = InternshipPosting.query.get_or_404(posting_id)
    if posting.company_id != current_user.company_id:
        flash('Access denied', 'danger')
        return redirect(url_for('company.postings'))
    
    return render_template('company/view_posting.html', posting=posting)

@company_bp.route('/posting/<int:posting_id>/toggle', methods=['POST'])
@login_required
@company_required
def toggle_posting(posting_id):
    posting = InternshipPosting.query.get_or_404(posting_id)
    if posting.company_id != current_user.company_id:
        flash('Access denied', 'danger')
        return redirect(url_for('company.postings'))
    
    try:
        posting.is_active = not posting.is_active
        db.session.commit()
        status = 'activated' if posting.is_active else 'deactivated'
        flash(f'Posting {status} successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error toggling posting: {str(e)}', 'danger')
    
    return redirect(url_for('company.postings'))

@company_bp.route('/applications')
@login_required
@company_required
def applications():
    postings = InternshipPosting.query.filter_by(company_id=current_user.company_id).all()
    all_applications = []
    for posting in postings:
        all_applications.extend(posting.applications)
    
    return render_template('company/applications.html', applications=all_applications)

@company_bp.route('/application/<int:application_id>/status', methods=['POST'])
@login_required
@company_required
def update_application_status(application_id):
    application = Application.query.get_or_404(application_id)
    
    # Verify company owns this application's posting
    if application.posting.company_id != current_user.company_id:
        flash('Access denied', 'danger')
        return redirect(url_for('company.applications'))
    
    try:
        new_status = request.form.get('status')
        application.status = new_status
        db.session.commit()
        flash(f'Application status updated to {new_status}', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error updating status: {str(e)}', 'danger')
    
    return redirect(url_for('company.applications'))
