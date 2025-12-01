# SkillLedger - Career Growth Platform

A comprehensive web application for tracking, verifying, and showcasing student internships and professional experiences.

## Features

### For Students
- Log and manage internship experiences
- Upload certificates and proof documents
- Track verification status in real-time
- Build and manage skill portfolio
- Apply to company internship postings
- Share verified experiences on public feed
- Like and comment on peer experiences

### For Mentors
- View assigned students
- Review and verify student internships
- Provide ratings (1-5) and feedback comments
- Approve or reject submissions
- Track verification history

### For Administrators
- User management (Students, Mentors, Companies)
- Analytics dashboard with skill trends
- Department-wise internship distribution
- Mentor performance statistics
- Company verification and management
- Skills catalog management

### For Companies
- Create and manage internship postings
- Review student applications
- Track application status
- Update application workflow

### Platform Features
- **Verification Ledger**: Blockchain-like tamper-proof ledger with SHA-256 hash chaining
- **Public Feed**: Social platform for sharing verified experiences
- **Role-based Access Control**: Separate dashboards for each user type
- **Analytics Dashboard**: Comprehensive insights into skills and trends

## Technology Stack

- **Backend**: Flask (Python)
- **Database**: PostgreSQL with skillledger schema
- **ORM**: SQLAlchemy
- **Authentication**: Flask-Login with password hashing
- **Frontend**: Bootstrap 5, Bootstrap Icons
- **Security**: SHA-256 hash chaining for verification ledger

## Database Schema

The application uses the existing `skillledger` schema in PostgreSQL with the following tables:
- Student, Mentor, Administrator, Company
- Skill, StudentSkill
- Internship, Verification, Certificate
- VerificationLedger (blockchain-like)
- InternshipPosting, Application
- Post, Comment, Like

## Installation

### Prerequisites
- Python 3.8+
- PostgreSQL 12+
- pip (Python package manager)

### Setup Steps

1. **Install Python dependencies**:
   ```powershell
   pip install -r requirements.txt
   ```

2. **Configure Database**:
   - Ensure PostgreSQL is running on localhost:5432
   - Database: `postgres`
   - Username: `postgres`
   - Password: `123456789Az#`
   - The application uses the `skillledger` schema

3. **Environment Variables**:
   The `.env` file is already configured with:
   - DATABASE_URL
   - SECRET_KEY
   - FLASK_ENV

4. **Run the Application**:
   ```powershell
   python app.py
   ```

5. **Access the Application**:
   Open your browser and navigate to: `http://localhost:5000`

## Default Access

### Creating Admin Account
Administrators must be created directly in the database:

```sql
INSERT INTO skillledger.administrator (name, email, password_hash, role)
VALUES ('Admin User', 'admin@skillledger.com', 'hashed_password', 'ADMIN');
```

### Creating Mentor Account
Mentors can be created by administrators through the admin dashboard.

### Student & Company Registration
Students and Companies can register through the web interface at `/register`

## Usage Guide

### Student Workflow
1. Register as a student
2. Wait for admin to assign a mentor
3. Add internship experiences
4. Upload certificates
5. Submit for verification
6. Once verified, share on public feed
7. Apply to company postings

### Mentor Workflow
1. Log in with mentor credentials
2. View assigned students
3. Review pending verifications
4. Approve/Reject with ratings and comments
5. Verification automatically adds to blockchain ledger

### Admin Workflow
1. Log in with admin credentials
2. Manage users (Students, Mentors, Companies)
3. Assign mentors to students
4. Verify companies
5. View analytics dashboard
6. Manage skills catalog

### Company Workflow
1. Register as a company
2. Wait for admin verification
3. Create internship postings (only when verified)
4. Review student applications
5. Update application status

## Security Features

- Password hashing using Werkzeug
- Role-based access control
- Verification ledger with SHA-256 hash chaining
- Protected routes with login requirements
- Database triggers for data integrity

## API Routes Structure

### Authentication Routes (`/`)
- `/` - Home page
- `/login` - User login
- `/register` - Student/Company registration
- `/logout` - Logout

### Student Routes (`/student/`)
- `/dashboard` - Student dashboard
- `/internships` - View all internships
- `/internship/add` - Add new internship
- `/internship/<id>` - View internship details
- `/skills` - Manage skills
- `/postings` - Browse internship postings
- `/applications` - View applications

### Mentor Routes (`/mentor/`)
- `/dashboard` - Mentor dashboard
- `/students` - View assigned students
- `/verifications` - Pending verifications
- `/verification/<id>` - Review verification

### Admin Routes (`/admin/`)
- `/dashboard` - Admin dashboard
- `/analytics` - Analytics and insights
- `/students` - Manage students
- `/mentors` - Manage mentors
- `/companies` - Manage companies
- `/skills` - Manage skills catalog

### Company Routes (`/company/`)
- `/dashboard` - Company dashboard
- `/postings` - Manage postings
- `/posting/add` - Create new posting
- `/applications` - View applications

### Feed Routes (`/feed/`)
- `/` - Public feed
- `/post/create/<internship_id>` - Create post
- `/post/<id>` - View post details
- `/my-posts` - Student's posts

## Database Triggers

The application relies on PostgreSQL triggers defined in the schema:
- Auto-sync internship status from verification
- Prevent posts on unverified internships
- Company verification gate for postings
- Verification ledger hash chaining

## Project Structure

```
skillledger/
├── app.py                 # Main application file
├── config.py              # Configuration settings
├── models.py              # SQLAlchemy models
├── requirements.txt       # Python dependencies
├── .env                   # Environment variables
├── routes/
│   ├── auth.py           # Authentication routes
│   ├── student.py        # Student routes
│   ├── mentor.py         # Mentor routes
│   ├── admin.py          # Admin routes
│   ├── company.py        # Company routes
│   └── feed.py           # Feed routes
├── templates/
│   ├── base.html         # Base template
│   ├── index.html        # Home page
│   ├── login.html        # Login page
│   ├── register.html     # Registration page
│   ├── student/          # Student templates
│   ├── mentor/           # Mentor templates
│   ├── admin/            # Admin templates
│   ├── company/          # Company templates
│   └── feed/             # Feed templates
└── skillledger_phase2_ddl.sql  # Database schema

```


