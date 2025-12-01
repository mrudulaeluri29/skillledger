from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import login_required, current_user
from models import Administrator, Student, Mentor, Company, Internship, Verification, Skill, StudentSkill
from models import db
from sqlalchemy import func
from functools import wraps

admin_bp = Blueprint('admin', __name__)

def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not hasattr(current_user, 'admin_id'):
            flash('Access denied. Administrators only.', 'danger')
            return redirect(url_for('auth.index'))
        return f(*args, **kwargs)
    return decorated_function

@admin_bp.route('/dashboard')
@login_required
@admin_required
def dashboard():
    total_students = Student.query.count()
    total_mentors = Mentor.query.count()
    total_companies = Company.query.count()
    total_internships = Internship.query.count()
    verified_internships = Internship.query.filter_by(verified=True).count()
    pending_verifications = Verification.query.filter_by(status='Pending').count()
    pending_companies = Company.query.filter_by(verified_status='Pending').count()
    
    return render_template('admin/dashboard.html',
                         total_students=total_students,
                         total_mentors=total_mentors,
                         total_companies=total_companies,
                         total_internships=total_internships,
                         verified_internships=verified_internships,
                         pending_verifications=pending_verifications,
                         pending_companies=pending_companies)

@admin_bp.route('/analytics')
@login_required
@admin_required
def analytics():
    from sqlalchemy import case
    
    # Top skills analysis
    top_skills = db.session.query(
        Skill.skill_name,
        func.count(StudentSkill.student_id).label('count')
    ).join(StudentSkill).group_by(Skill.skill_name).order_by(func.count(StudentSkill.student_id).desc()).limit(10).all()
    
    # Department-wise internship distribution
    dept_internships = db.session.query(
        Student.department,
        func.count(Internship.internship_id).label('count')
    ).join(Internship).group_by(Student.department).all()
    
    # Verification statistics by mentor
    mentor_stats = db.session.query(
        Mentor.name,
        func.count(Verification.verification_id).label('total'),
        func.sum(case((Verification.status == 'Approved', 1), else_=0)).label('approved')
    ).join(Verification).group_by(Mentor.mentor_id).all()
    
    return render_template('admin/analytics.html',
                         top_skills=top_skills,
                         dept_internships=dept_internships,
                         mentor_stats=mentor_stats)

@admin_bp.route('/students')
@login_required
@admin_required
def students():
    students = Student.query.all()
    mentors = Mentor.query.all()
    return render_template('admin/students.html', students=students, mentors=mentors)

@admin_bp.route('/mentors')
@login_required
@admin_required
def mentors():
    mentors = Mentor.query.all()
    return render_template('admin/mentors.html', mentors=mentors)

@admin_bp.route('/mentor/add', methods=['GET', 'POST'])
@login_required
@admin_required
def add_mentor():
    if request.method == 'POST':
        try:
            mentor = Mentor(
                name=request.form.get('name'),
                email=request.form.get('email'),
                department=request.form.get('department'),
                designation=request.form.get('designation'),
                role='MENTOR'
            )
            mentor.set_password(request.form.get('password'))
            db.session.add(mentor)
            db.session.commit()
            flash('Mentor added successfully!', 'success')
            return redirect(url_for('admin.mentors'))
        except Exception as e:
            db.session.rollback()
            flash(f'Error adding mentor: {str(e)}', 'danger')
    
    return render_template('admin/add_mentor.html')

@admin_bp.route('/student/<int:student_id>/assign_mentor', methods=['POST'])
@login_required
@admin_required
def assign_mentor(student_id):
    student = Student.query.get_or_404(student_id)
    mentor_id = request.form.get('mentor_id')
    
    try:
        student.mentor_id = int(mentor_id) if mentor_id else None
        db.session.commit()
        flash('Mentor assigned successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error assigning mentor: {str(e)}', 'danger')
    
    return redirect(url_for('admin.students'))

@admin_bp.route('/companies')
@login_required
@admin_required
def companies():
    companies = Company.query.all()
    return render_template('admin/companies.html', companies=companies)

@admin_bp.route('/company/<int:company_id>/verify', methods=['POST'])
@login_required
@admin_required
def verify_company(company_id):
    company = Company.query.get_or_404(company_id)
    status = request.form.get('status')
    
    try:
        company.verified_status = status
        db.session.commit()
        flash(f'Company status updated to {status}', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error updating company: {str(e)}', 'danger')
    
    return redirect(url_for('admin.companies'))

@admin_bp.route('/skills')
@login_required
@admin_required
def skills():
    skills = Skill.query.all()
    return render_template('admin/skills.html', skills=skills)

@admin_bp.route('/skill/add', methods=['POST'])
@login_required
@admin_required
def add_skill():
    try:
        skill = Skill(
            skill_name=request.form.get('skill_name'),
            category=request.form.get('category')
        )
        db.session.add(skill)
        db.session.commit()
        flash('Skill added successfully!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error adding skill: {str(e)}', 'danger')
    
    return redirect(url_for('admin.skills'))
