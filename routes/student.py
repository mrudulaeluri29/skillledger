from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import login_required, current_user
from models import Student, Internship, Certificate, Verification, StudentSkill, Skill, InternshipPosting, Application
from models import db
from datetime import datetime
from functools import wraps

student_bp = Blueprint('student', __name__)

def student_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not hasattr(current_user, 'student_id'):
            flash('Access denied. Students only.', 'danger')
            return redirect(url_for('auth.index'))
        return f(*args, **kwargs)
    return decorated_function

@student_bp.route('/dashboard')
@login_required
@student_required
def dashboard():
    internships = Internship.query.filter_by(student_id=current_user.student_id).all()
    pending_count = sum(1 for i in internships if i.status == 'Submitted')
    verified_count = sum(1 for i in internships if i.verified)
    
    # Get available internship postings
    postings = InternshipPosting.query.filter_by(is_active=True).limit(5).all()
    
    return render_template('student/dashboard.html', 
                         internships=internships,
                         pending_count=pending_count,
                         verified_count=verified_count,
                         postings=postings)

@student_bp.route('/internships')
@login_required
@student_required
def internships():
    internships = Internship.query.filter_by(student_id=current_user.student_id).all()
    return render_template('student/internships.html', internships=internships)

@student_bp.route('/internship/add', methods=['GET', 'POST'])
@login_required
@student_required
def add_internship():
    if request.method == 'POST':
        try:
            internship = Internship(
                student_id=current_user.student_id,
                organization=request.form.get('organization'),
                position=request.form.get('position'),
                start_date=datetime.strptime(request.form.get('start_date'), '%Y-%m-%d').date(),
                end_date=datetime.strptime(request.form.get('end_date'), '%Y-%m-%d').date(),
                description=request.form.get('description'),
                status='Draft'
            )
            db.session.add(internship)
            db.session.commit()
            flash('Internship added successfully!', 'success')
            return redirect(url_for('student.internships'))
        except Exception as e:
            db.session.rollback()
            flash(f'Error adding internship: {str(e)}', 'danger')
    
    return render_template('student/add_internship.html')

@student_bp.route('/internship/<int:internship_id>')
@login_required
@student_required
def view_internship(internship_id):
    internship = Internship.query.get_or_404(internship_id)
    if internship.student_id != current_user.student_id:
        flash('Access denied', 'danger')
        return redirect(url_for('student.internships'))
    return render_template('student/view_internship.html', internship=internship)

@student_bp.route('/internship/<int:internship_id>/submit', methods=['POST'])
@login_required
@student_required
def submit_internship(internship_id):
    internship = Internship.query.get_or_404(internship_id)
    if internship.student_id != current_user.student_id:
        flash('Access denied', 'danger')
        return redirect(url_for('student.internships'))
    
    if not current_user.mentor_id:
        flash('You need to be assigned a mentor before submitting', 'warning')
        return redirect(url_for('student.view_internship', internship_id=internship_id))
    
    try:
        # Create verification record
        verification = Verification(
            internship_id=internship.internship_id,
            mentor_id=current_user.mentor_id,
            status='Pending'
        )
        db.session.add(verification)
        db.session.commit()
        flash('Internship submitted for verification!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error submitting internship: {str(e)}', 'danger')
    
    return redirect(url_for('student.view_internship', internship_id=internship_id))

@student_bp.route('/internship/<int:internship_id>/certificate', methods=['POST'])
@login_required
@student_required
def add_certificate(internship_id):
    internship = Internship.query.get_or_404(internship_id)
    if internship.student_id != current_user.student_id:
        flash('Access denied', 'danger')
        return redirect(url_for('student.internships'))
    
    try:
        certificate = Certificate(
            internship_id=internship_id,
            file_link=request.form.get('file_link'),
            issue_date=datetime.strptime(request.form.get('issue_date'), '%Y-%m-%d').date(),
            certificate_type=request.form.get('certificate_type'),
            issuer=request.form.get('issuer')
        )
        db.session.add(certificate)
        db.session.commit()
        flash('Certificate added successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error adding certificate: {str(e)}', 'danger')
    
    return redirect(url_for('student.view_internship', internship_id=internship_id))

@student_bp.route('/skills')
@login_required
@student_required
def skills():
    student_skills = StudentSkill.query.filter_by(student_id=current_user.student_id).all()
    all_skills = Skill.query.all()
    return render_template('student/skills.html', student_skills=student_skills, all_skills=all_skills)

@student_bp.route('/skills/add', methods=['POST'])
@login_required
@student_required
def add_skill():
    try:
        skill_id = int(request.form.get('skill_id'))
        proficiency_text = request.form.get('proficiency_level')
        
        # Map text to integer (database expects integer)
        proficiency_map = {
            'Beginner': 1,
            'Intermediate': 2,
            'Advanced': 3,
            'Expert': 4
        }
        proficiency = proficiency_map.get(proficiency_text, 1)
        
        # Check if already exists
        existing = StudentSkill.query.filter_by(
            student_id=current_user.student_id,
            skill_id=skill_id
        ).first()
        
        if existing:
            existing.proficiency_level = proficiency
        else:
            student_skill = StudentSkill(
                student_id=current_user.student_id,
                skill_id=skill_id,
                proficiency_level=proficiency
            )
            db.session.add(student_skill)
        
        db.session.commit()
        flash('Skill added/updated successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error adding skill: {str(e)}', 'danger')
    
    return redirect(url_for('student.skills'))

@student_bp.route('/skills/remove/<int:skill_id>', methods=['POST'])
@login_required
@student_required
def remove_skill(skill_id):
    try:
        student_skill = StudentSkill.query.filter_by(
            student_id=current_user.student_id,
            skill_id=skill_id
        ).first_or_404()
        
        db.session.delete(student_skill)
        db.session.commit()
        flash('Skill removed successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error removing skill: {str(e)}', 'danger')
    
    return redirect(url_for('student.skills'))

@student_bp.route('/postings')
@login_required
@student_required
def view_postings():
    postings = InternshipPosting.query.filter_by(is_active=True).all()
    # Get student's applications to check status
    student_applications = Application.query.filter_by(student_id=current_user.student_id).all()
    # Create a dict mapping posting_id to application for quick lookup
    application_dict = {app.posting_id: app for app in student_applications}
    return render_template('student/postings.html', postings=postings, application_dict=application_dict)

@student_bp.route('/posting/<int:posting_id>/apply', methods=['POST'])
@login_required
@student_required
def apply_posting(posting_id):
    posting = InternshipPosting.query.get_or_404(posting_id)
    
    # Check if already applied
    existing = Application.query.filter_by(
        posting_id=posting_id,
        student_id=current_user.student_id
    ).first()
    
    if existing:
        flash('You have already applied to this posting', 'warning')
        return redirect(url_for('student.view_postings'))
    
    try:
        application = Application(
            posting_id=posting_id,
            student_id=current_user.student_id,
            status='Applied'
        )
        db.session.add(application)
        db.session.commit()
        flash('Application submitted successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error applying: {str(e)}', 'danger')
    
    return redirect(url_for('student.view_postings'))

@student_bp.route('/applications')
@login_required
@student_required
def applications():
    applications = Application.query.filter_by(student_id=current_user.student_id).all()
    return render_template('student/applications.html', applications=applications)
