from config.db import get_firestore_db
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

db = get_firestore_db()
users_collection = db.collection('users')

def create_user(name, email, password, role='user'):
    password_hash = generate_password_hash(password)
    created_at = datetime.utcnow().isoformat()

    user_data = {
        'name': name,
        'email': email,
        'password_hash': password_hash,
        'role': role,
        'created_at': created_at
    }

    # Use email as unique document ID or auto-ID
    users_collection.document(email).set(user_data)

def get_user_by_email(email):
    doc = users_collection.document(email).get()
    if doc.exists:
        return doc.to_dict()
    return None

def update_user(email, name, role):
    doc_ref = users_collection.document(email)
    if doc_ref.get().exists:
        doc_ref.update({
            'name': name,
            'role': role
        })

def validate_login(email, password):
    user = get_user_by_email(email)
    if user and check_password_hash(user['password_hash'], password):
        return user
    return None
