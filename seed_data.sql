-- Script to create a default admin user
-- Run this after setting up the database

-- First, you need to generate a password hash
-- You can use Python:
-- from werkzeug.security import generate_password_hash
-- print(generate_password_hash('your_password'))

-- Example with a sample password hash (change this!)
INSERT INTO skillledger.administrator (name, email, password_hash, role)
VALUES ('System Administrator', 'admin@skillledger.com', 'scrypt:32768:8:1$yourhashedpassword', 'ADMIN');

-- Create a sample mentor
INSERT INTO skillledger.mentor (name, email, password_hash, department, designation, role)
VALUES ('Dr. John Smith', 'mentor@skillledger.com', 'scrypt:32768:8:1$yourhashedpassword', 'Computer Science', 'Professor', 'MENTOR');

-- Create some sample skills
INSERT INTO skillledger.skill (skill_name, category) VALUES
('Python', 'Technical'),
('JavaScript', 'Technical'),
('React', 'Technical'),
('Node.js', 'Technical'),
('SQL', 'Technical'),
('Machine Learning', 'Technical'),
('Data Analysis', 'Technical'),
('Communication', 'Soft'),
('Teamwork', 'Soft'),
('Leadership', 'Soft'),
('Problem Solving', 'Soft'),
('Project Management', 'Soft');
