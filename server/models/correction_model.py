from config.db import get_db_connection

def get_corrected_name(predicted_text):
    conn = get_db_connection()
    cursor = conn.execute(
        'SELECT corrected_name FROM signature_corrections WHERE predicted_text = ?', 
        (predicted_text,))
    row = cursor.fetchone()
    conn.close()
    return row['corrected_name'] if row else None

def save_corrected_name(predicted_text, corrected_name):
    conn = get_db_connection()
    conn.execute(
        'INSERT OR REPLACE INTO signature_corrections (predicted_text, corrected_name) VALUES (?, ?)', 
        (predicted_text, corrected_name))
    conn.commit()
    conn.close()
