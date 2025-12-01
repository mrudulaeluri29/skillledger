from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import login_user, logout_user, login_required, current_user
from models import Student, Mentor, Administrator, Company, db

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/')
def index():
    if current_user.is_authenticated:
        if hasattr(current_user, 'student_id'):
            return redirect(url_for('student.dashboard'))
        elif hasattr(current_user, 'mentor_id'):
            return redirect(url_for('mentor.dashboard'))
        elif hasattr(current_user, 'admin_id'):
            return redirect(url_for('admin.dashboard'))
        elif hasattr(current_user, 'company_id'):
            return redirect(url_for('company.dashboard'))
    return render_template('index.html')

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('auth.index'))
    
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')
        role = request.form.get('role')
        
        user = None
        if role == 'STUDENT':
            user = Student.query.filter_by(email=email).first()
        elif role == 'MENTOR':
            user = Mentor.query.filter_by(email=email).first()
        elif role == 'ADMIN':
            user = Administrator.query.filter_by(email=email).first()
        elif role == 'COMPANY':
            user = Company.query.filter_by(email=email).first()
        
        if user and user.check_password(password):
            login_user(user)
            next_page = request.args.get('next')
            if next_page:
                return redirect(next_page)
            
            if role == 'STUDENT':
                return redirect(url_for('student.dashboard'))
            elif role == 'MENTOR':
                return redirect(url_for('mentor.dashboard'))
            elif role == 'ADMIN':
                return redirect(url_for('admin.dashboard'))
            elif role == 'COMPANY':
                return redirect(url_for('company.dashboard'))
        else:
            flash('Invalid email or password', 'danger')
    
    return render_template('login.html')

@auth_bp.route('/register', methods=['GET', 'POST'])
def register():
    if current_user.is_authenticated:
        return redirect(url_for('auth.index'))
    
    if request.method == 'POST':
        role = request.form.get('role')
        email = request.form.get('email')
        name = request.form.get('name')
        password = request.form.get('password')
        
        # Check if email already exists
        existing_user = (Student.query.filter_by(email=email).first() or
                        Mentor.query.filter_by(email=email).first() or
                        Administrator.query.filter_by(email=email).first() or
                        Company.query.filter_by(email=email).first())
        
        if existing_user:
            flash('Email already registered', 'danger')
            return redirect(url_for('auth.register'))
        
        try:
            if role == 'STUDENT':
                user = Student(
                    name=name,
                    email=email,
                    major=request.form.get('major'),
                    year=int(request.form.get('year')),
                    department=request.form.get('department'),
                    role='STUDENT'
                )
            elif role == 'COMPANY':
                user = Company(
                    name=name,
                    email=email,
                    industry=request.form.get('industry'),
                    verified_status='Pending'
                )
            else:
                flash('Invalid registration type', 'danger')
                return redirect(url_for('auth.register'))
            
            user.set_password(password)
            db.session.add(user)
            db.session.commit()
            flash('Registration successful! Please login.', 'success')
            return redirect(url_for('auth.login'))
        except Exception as e:
            db.session.rollback()
            flash(f'Registration failed: {str(e)}', 'danger')
    
    return render_template('register.html')

@auth_bp.route('/logout')
@login_required
def logout():
    logout_user()
    flash('You have been logged out', 'info')
    return redirect(url_for('auth.index'))
