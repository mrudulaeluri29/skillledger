from flask import Flask
from flask_login import LoginManager
from config import Config

login_manager = LoginManager()

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    
    # Import db from models and initialize it
    from models import db
    db.init_app(app)
    
    login_manager.init_app(app)
    login_manager.login_view = 'auth.login'
    
    # Setup user loader
    from models import Student, Mentor, Administrator, Company
    
    @login_manager.user_loader
    def load_user(user_id):
        user_type, user_id_num = user_id.split('_')
        if user_type == 'student':
            return Student.query.get(int(user_id_num))
        elif user_type == 'mentor':
            return Mentor.query.get(int(user_id_num))
        elif user_type == 'admin':
            return Administrator.query.get(int(user_id_num))
        elif user_type == 'company':
            return Company.query.get(int(user_id_num))
        return None
    
    # Register blueprints
    from routes.auth import auth_bp
    from routes.student import student_bp
    from routes.mentor import mentor_bp
    from routes.admin import admin_bp
    from routes.company import company_bp
    from routes.feed import feed_bp
    
    app.register_blueprint(auth_bp)
    app.register_blueprint(student_bp, url_prefix='/student')
    app.register_blueprint(mentor_bp, url_prefix='/mentor')
    app.register_blueprint(admin_bp, url_prefix='/admin')
    app.register_blueprint(company_bp, url_prefix='/company')
    app.register_blueprint(feed_bp, url_prefix='/feed')
    
    return app

if __name__ == '__main__':
    app = create_app()
    app.run(debug=True, host='0.0.0.0', port=5000)
