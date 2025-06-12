from flask import Blueprint, request, jsonify
from models.user_model import create_user, get_user_by_email, update_user, validate_login

user_bp = Blueprint('user_services', __name__)

@user_bp.route('/create', methods=['POST'])
def create():
    data = request.get_json()
    if not all(k in data for k in ('name', 'email', 'password')):
        return jsonify({'error': 'Missing fields'}), 400

    if get_user_by_email(data['email']):
        return jsonify({'error': 'User already exists'}), 409

    create_user(data['name'], data['email'], data['password'], data.get('role', 'user'))
    return jsonify({'message': 'User created'}), 201

@user_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = validate_login(data.get('email'), data.get('password'))
    if user:
        return jsonify({'message': 'Login successful', 'user': dict(user)})
    return jsonify({'error': 'Invalid credentials'}), 401

@user_bp.route('/update/<int:user_id>', methods=['PUT'])
def update(user_id):
    data = request.get_json()
    update_user(user_id, data.get('name'), data.get('role', 'user'))
    return jsonify({'message': 'User updated'})
