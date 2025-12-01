from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import login_required, current_user
from models import Post, Comment, Like, Student, Internship
from models import db
from datetime import datetime
from functools import wraps

feed_bp = Blueprint('feed', __name__)

def student_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not hasattr(current_user, 'student_id'):
            flash('Access denied. Students only.', 'danger')
            return redirect(url_for('auth.index'))
        return f(*args, **kwargs)
    return decorated_function

@feed_bp.route('/')
@login_required
def index():
    posts = Post.query.filter_by(visibility='Public').order_by(Post.created_at.desc()).all()
    return render_template('feed/index.html', posts=posts)

@feed_bp.route('/post/create/<int:internship_id>', methods=['GET', 'POST'])
@login_required
@student_required
def create_post(internship_id):
    internship = Internship.query.get_or_404(internship_id)
    
    # Verify ownership and verification status
    if internship.student_id != current_user.student_id:
        flash('Access denied', 'danger')
        return redirect(url_for('feed.index'))
    
    if not internship.verified:
        flash('Only verified internships can be posted', 'warning')
        return redirect(url_for('student.view_internship', internship_id=internship_id))
    
    if request.method == 'POST':
        try:
            post = Post(
                internship_id=internship_id,
                student_id=current_user.student_id,
                content=request.form.get('content'),
                visibility=request.form.get('visibility', 'Public')
            )
            db.session.add(post)
            db.session.commit()
            flash('Post created successfully!', 'success')
            return redirect(url_for('feed.index'))
        except Exception as e:
            db.session.rollback()
            flash(f'Error creating post: {str(e)}', 'danger')
    
    return render_template('feed/create_post.html', internship=internship)

@feed_bp.route('/post/<int:post_id>')
@login_required
def view_post(post_id):
    post = Post.query.get_or_404(post_id)
    return render_template('feed/view_post.html', post=post)

@feed_bp.route('/post/<int:post_id>/like', methods=['POST'])
@login_required
@student_required
def like_post(post_id):
    post = Post.query.get_or_404(post_id)
    
    # Check if already liked
    existing_like = Like.query.filter_by(
        post_id=post_id,
        student_id=current_user.student_id
    ).first()
    
    try:
        if existing_like:
            db.session.delete(existing_like)
            db.session.commit()
            flash('Post unliked', 'info')
        else:
            like = Like(
                post_id=post_id,
                student_id=current_user.student_id
            )
            db.session.add(like)
            db.session.commit()
            flash('Post liked!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error: {str(e)}', 'danger')
    
    return redirect(url_for('feed.view_post', post_id=post_id))

@feed_bp.route('/post/<int:post_id>/comment', methods=['POST'])
@login_required
@student_required
def add_comment(post_id):
    post = Post.query.get_or_404(post_id)
    
    try:
        comment = Comment(
            post_id=post_id,
            student_id=current_user.student_id,
            text=request.form.get('text')
        )
        db.session.add(comment)
        db.session.commit()
        flash('Comment added!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Error adding comment: {str(e)}', 'danger')
    
    return redirect(url_for('feed.view_post', post_id=post_id))

@feed_bp.route('/my-posts')
@login_required
@student_required
def my_posts():
    posts = Post.query.filter_by(student_id=current_user.student_id).order_by(Post.created_at.desc()).all()
    return render_template('feed/my_posts.html', posts=posts)
