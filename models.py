from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

db = SQLAlchemy()

class Student(db.Model, UserMixin):
    __tablename__ = 'student'
    __table_args__ = {'schema': 'skillledger'}
    
    student_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    major = db.Column(db.String(100), nullable=False)
    year = db.Column(db.Integer, nullable=False)
    department = db.Column(db.String(100), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='STUDENT')
    mentor_id = db.Column(db.Integer, db.ForeignKey('skillledger.mentor.mentor_id', ondelete='SET NULL'))
    
    # Relationships
    internships = db.relationship('Internship', backref='student', lazy=True, cascade='all, delete-orphan')
    skills = db.relationship('StudentSkill', backref='student', lazy=True, cascade='all, delete-orphan')
    posts = db.relationship('Post', backref='author', lazy=True, cascade='all, delete-orphan')
    applications = db.relationship('Application', backref='student', lazy=True, cascade='all, delete-orphan')
    
    def get_id(self):
        return f"student_{self.student_id}"
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Mentor(db.Model, UserMixin):
    __tablename__ = 'mentor'
    __table_args__ = {'schema': 'skillledger'}
    
    mentor_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    department = db.Column(db.String(100), nullable=False)
    designation = db.Column(db.String(100))
    role = db.Column(db.String(20), nullable=False, default='MENTOR')
    
    # Relationships
    students = db.relationship('Student', backref='mentor', lazy=True)
    verifications = db.relationship('Verification', backref='mentor', lazy=True)
    
    def get_id(self):
        return f"mentor_{self.mentor_id}"
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Administrator(db.Model, UserMixin):
    __tablename__ = 'administrator'
    __table_args__ = {'schema': 'skillledger'}
    
    admin_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='ADMIN')
    
    def get_id(self):
        return f"admin_{self.admin_id}"
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Company(db.Model, UserMixin):
    __tablename__ = 'company'
    __table_args__ = {'schema': 'skillledger'}
    
    company_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), unique=True, nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    industry = db.Column(db.String(100))
    verified_status = db.Column(db.String(20), nullable=False, default='Pending')
    
    # Relationships
    postings = db.relationship('InternshipPosting', backref='company', lazy=True, cascade='all, delete-orphan')
    
    def get_id(self):
        return f"company_{self.company_id}"
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Skill(db.Model):
    __tablename__ = 'skill'
    __table_args__ = {'schema': 'skillledger'}
    
    skill_id = db.Column(db.Integer, primary_key=True)
    skill_name = db.Column(db.String(100), unique=True, nullable=False)
    category = db.Column(db.String(50), nullable=False)

class StudentSkill(db.Model):
    __tablename__ = 'student_skill'
    __table_args__ = {'schema': 'skillledger'}
    
    student_id = db.Column(db.Integer, db.ForeignKey('skillledger.student.student_id', ondelete='CASCADE'), primary_key=True)
    skill_id = db.Column(db.Integer, db.ForeignKey('skillledger.skill.skill_id', ondelete='CASCADE'), primary_key=True)
    proficiency_level = db.Column(db.Integer, nullable=False)
    
    skill = db.relationship('Skill', backref='student_skills')

class Internship(db.Model):
    __tablename__ = 'internship'
    __table_args__ = {'schema': 'skillledger'}
    
    internship_id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('skillledger.student.student_id', ondelete='CASCADE'), nullable=False)
    organization = db.Column(db.String(150), nullable=False)
    position = db.Column(db.String(150), nullable=False)
    start_date = db.Column(db.Date, nullable=False)
    end_date = db.Column(db.Date, nullable=False)
    description = db.Column(db.Text)
    status = db.Column(db.String(20), nullable=False, default='Draft')
    verified = db.Column(db.Boolean, nullable=False, default=False)
    
    # Relationships
    verification = db.relationship('Verification', backref='internship', uselist=False, cascade='all, delete-orphan')
    certificates = db.relationship('Certificate', backref='internship', lazy=True, cascade='all, delete-orphan')
    posts = db.relationship('Post', backref='internship', lazy=True, cascade='all, delete-orphan')

class Verification(db.Model):
    __tablename__ = 'verification'
    __table_args__ = {'schema': 'skillledger'}
    
    verification_id = db.Column(db.Integer, primary_key=True)
    internship_id = db.Column(db.Integer, db.ForeignKey('skillledger.internship.internship_id', ondelete='CASCADE'), unique=True, nullable=False)
    mentor_id = db.Column(db.Integer, db.ForeignKey('skillledger.mentor.mentor_id', ondelete='RESTRICT'), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='Pending')
    rating = db.Column(db.Integer)
    comments = db.Column(db.Text)
    verified_on = db.Column(db.DateTime)

class Certificate(db.Model):
    __tablename__ = 'certificate'
    __table_args__ = {'schema': 'skillledger'}
    
    certificate_id = db.Column(db.Integer, primary_key=True)
    internship_id = db.Column(db.Integer, db.ForeignKey('skillledger.internship.internship_id', ondelete='CASCADE'), nullable=False)
    file_link = db.Column(db.String(500), nullable=False)
    issue_date = db.Column(db.Date, nullable=False)
    certificate_type = db.Column(db.String(50))
    issuer = db.Column(db.String(150))

class VerificationLedger(db.Model):
    __tablename__ = 'verification_ledger'
    __table_args__ = {'schema': 'skillledger'}
    
    ledger_id = db.Column(db.Integer, primary_key=True)
    internship_id = db.Column(db.Integer, db.ForeignKey('skillledger.internship.internship_id', ondelete='CASCADE'), nullable=False)
    mentor_id = db.Column(db.Integer, db.ForeignKey('skillledger.mentor.mentor_id', ondelete='RESTRICT'), nullable=False)
    action = db.Column(db.String(50), nullable=False)
    hash_value = db.Column(db.String(64), nullable=False)
    previous_hash = db.Column(db.String(64))
    timestamp = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

class InternshipPosting(db.Model):
    __tablename__ = 'internship_posting'
    __table_args__ = {'schema': 'skillledger'}
    
    posting_id = db.Column(db.Integer, primary_key=True)
    company_id = db.Column(db.Integer, db.ForeignKey('skillledger.company.company_id', ondelete='CASCADE'), nullable=False)
    title = db.Column(db.String(150), nullable=False)
    description = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(150))
    duration = db.Column(db.String(100))
    application_deadline = db.Column(db.Date)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    
    # Relationships
    applications = db.relationship('Application', backref='posting', lazy=True, cascade='all, delete-orphan')

class Application(db.Model):
    __tablename__ = 'application'
    __table_args__ = {'schema': 'skillledger'}
    
    application_id = db.Column(db.Integer, primary_key=True)
    posting_id = db.Column(db.Integer, db.ForeignKey('skillledger.internship_posting.posting_id', ondelete='CASCADE'), nullable=False)
    student_id = db.Column(db.Integer, db.ForeignKey('skillledger.student.student_id', ondelete='CASCADE'), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='Applied')
    applied_on = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

class Post(db.Model):
    __tablename__ = 'post'
    __table_args__ = {'schema': 'skillledger'}
    
    post_id = db.Column(db.Integer, primary_key=True)
    internship_id = db.Column(db.Integer, db.ForeignKey('skillledger.internship.internship_id', ondelete='CASCADE'), nullable=False)
    student_id = db.Column(db.Integer, db.ForeignKey('skillledger.student.student_id', ondelete='CASCADE'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    visibility = db.Column(db.String(20), nullable=False, default='Public')
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    
    # Relationships
    comments = db.relationship('Comment', backref='post', lazy=True, cascade='all, delete-orphan')
    likes = db.relationship('Like', backref='post', lazy=True, cascade='all, delete-orphan')

class Comment(db.Model):
    __tablename__ = 'comment'
    __table_args__ = {'schema': 'skillledger'}
    
    comment_id = db.Column(db.Integer, primary_key=True)
    post_id = db.Column(db.Integer, db.ForeignKey('skillledger.post.post_id', ondelete='CASCADE'), nullable=False)
    student_id = db.Column(db.Integer, db.ForeignKey('skillledger.student.student_id', ondelete='CASCADE'), nullable=False)
    text = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    
    # Relationship
    student = db.relationship('Student', backref='comments', foreign_keys=[student_id])

class Like(db.Model):
    __tablename__ = 'like'
    __table_args__ = {'schema': 'skillledger'}
    
    post_id = db.Column(db.Integer, db.ForeignKey('skillledger.post.post_id', ondelete='CASCADE'), primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('skillledger.student.student_id', ondelete='CASCADE'), primary_key=True)
    liked_on = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
