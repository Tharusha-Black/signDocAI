from flask import Flask, jsonify, request
from flask_cors import CORS
from config.db import get_firestore_db
from models.user_model import create_user, validate_login
from services.user_services.user_routes import user_bp
from flask_socketio import SocketIO, emit
import base64
from PIL import Image
import io
import cv2
import numpy as np
import mediapipe as mp
from tensorflow.keras.models import load_model
import HandTrackingModule as htm
import time
from datetime import datetime
import os
# Ensure debug directory exists
os.makedirs("debug", exist_ok=True)

app = Flask(__name__)
CORS(app)

# Initialize Socket.IO
socketio = SocketIO(app, 
                   cors_allowed_origins="*",
                   logger=True,
                   engineio_logger=True)


# Register blueprints
app.register_blueprint(user_bp, url_prefix='/user_services')

# MediaPipe setup
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(static_image_mode=True, max_num_hands=1)
mp_drawing = mp.solutions.drawing_utils

# CNN Model setup
IMG_SIZE = (128, 128)
MODEL_PATH = 'AI-Model/asl_to_text_advanced.h5'

# Class mapping
class_mapping = {
    0: '0', 1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'E', 
    6: 'F', 7: 'G', 8: 'H', 9: 'I', 10: 'J',
    11: 'K', 12: 'L', 13: 'M', 14: 'N', 15: 'O',
    16: 'P', 17: 'Q', 18: 'R', 19: 'S', 20: 'T',
    21: 'U', 22: 'V', 23: 'W', 24: 'X', 25: 'Y', 26: 'Z'
}

AMBIGUOUS_GROUPS = [
    {'M', 'N', 'T'},
    {'D', 'I'},
    {'V', 'U'},
]

CONFIDENCE_THRESHOLD = 0.7

# Load CNN model
try:
    model = load_model(MODEL_PATH)
    print("CNN model loaded successfully")
except Exception as e:
    print(f"Error loading CNN model: {str(e)}")
    raise

# Track connected clients
connected_clients = set()


def predict_sign_language(image):
    """Full processing and prediction pipeline"""
    # Step 1: Preprocess image
    processed_image = preprocess_image(image)  # Use original, clean one
    
    # Step 2: Prepare for model
    model_input = prepare_for_model(processed_image)
    
    # Step 3: Make prediction
    prediction = model.predict(np.expand_dims(model_input, axis=0))
    predicted_class = np.argmax(prediction[0])
    confidence = np.max(prediction[0])
    
    return processed_image, predicted_class, confidence

def preprocess_image(image):
    """Preprocess OpenCV image for CNN"""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 2)
    thresh = cv2.adaptiveThreshold(blur, 255, 
                                   cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY_INV, 11, 2)
    _, final = cv2.threshold(thresh, 70, 255, 
                              cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    return final

def prepare_for_model(image):
    """Prepare the processed image for model input"""
    # Resize to model's expected input
    resized = cv2.resize(image, (128, 128))
    
    # Normalize and add channel dimension
    normalized = resized.astype('float32') / 255.0
    final_image = np.expand_dims(normalized, axis=-1)
    
    return final_image

def is_ambiguous(predictions):
    pred_set = set(predictions)
    for group in AMBIGUOUS_GROUPS:
        if pred_set.issubset(group):
            return True, group
    return False, None

def detect_hand_sign(posList):
    result = ""
    if not posList or len(posList) < 21:  # Need all 21 hand landmarks
        return result
    
    fingers = []
    
    finger_mcp = [5,9,13,17]
    finger_dip = [6,10,14,18]
    finger_pip = [7,11,15,19]
    finger_tip = [8,12,16,20]
    
    for id in range(4):
        if(posList[finger_tip[id]][1]+ 25  < posList[finger_dip[id]][1] and posList[16][2]<posList[20][2]):
            fingers.append(0.25)
        elif(posList[finger_tip[id]][2] > posList[finger_dip[id]][2]):
            fingers.append(0)
        elif(posList[finger_tip[id]][2] < posList[finger_pip[id]][2]): 
            fingers.append(1)
        elif(posList[finger_tip[id]][1] > posList[finger_pip[id]][1] and posList[finger_tip[id]][1] > posList[finger_dip[id]][1]): 
            fingers.append(0.5)
    
    if(posList[3][2] > posList[4][2]) and (posList[3][1] > posList[6][1])and (posList[4][2] < posList[6][2]) and fingers.count(0) == 4:
        result = "A"
        
    elif(posList[3][1] > posList[4][1]) and fingers.count(1) == 4:
        result = "B"
    
    elif(posList[3][1] > posList[6][1]) and fingers.count(0.5) >= 1 and (posList[4][2]> posList[8][2]):
        result = "C"
        
    elif(fingers[0]==1) and fingers.count(0) == 3 and (posList[3][1] > posList[4][1]):
        result = "D"
    
    elif (posList[3][1] < posList[6][1]) and fingers.count(0) == 4 and posList[12][2]<posList[4][2]:
        result = "E"

    elif (fingers.count(1) == 3) and (fingers[0]==0) and (posList[3][2] > posList[4][2]):
        result = "F"

    elif(fingers[0]==0.25) and fingers.count(0) == 3:
        result = "G"

    elif(fingers[0]==0.25) and(fingers[1]==0.25) and fingers.count(0) == 2:
        result = "H"
    
    elif (posList[4][1] < posList[6][1]) and fingers.count(0) == 3:
        if (len(fingers)==4 and fingers[3] == 1):
            result = "I"
    
    elif (posList[4][1] < posList[6][1] and posList[4][1] > posList[10][1] and fingers.count(1) == 2):
        result = "K"
        
    elif(fingers[0]==1) and fingers.count(0) == 3 and (posList[3][1] < posList[4][1]):
        result = "L"
    
    elif (posList[4][1] < posList[16][1]) and fingers.count(0) == 4:
        result = "M"
    
    elif (posList[4][1] < posList[12][1]) and fingers.count(0) == 4:
        result = "N"
        
    elif(posList[4][2] < posList[8][2]) and (posList[4][2] < posList[12][2]) and (posList[4][2] < posList[16][2]) and (posList[4][2] < posList[20][2]):
        result = "O"
    
    elif(fingers[2] == 0)  and (posList[4][2] < posList[12][2]) and (posList[4][2] > posList[6][2]):
        if (len(fingers)==4 and fingers[3] == 0):
            result = "P"
    
    elif(fingers[1] == 0) and (fingers[2] == 0) and (fingers[3] == 0) and (posList[8][2] > posList[5][2]) and (posList[4][2] < posList[1][2]):
        result = "Q"
    
    elif(posList[8][1] < posList[12][1]) and (fingers.count(1) == 2) and (posList[9][1] > posList[4][1]):
        result = "R"
        
    elif (posList[4][1] > posList[12][1]) and posList[4][2]<posList[6][2] and fingers.count(0) == 4:
        result = "T"

    elif (posList[4][1] > posList[12][1]) and posList[4][2]<posList[12][2] and fingers.count(0) == 4:
        result = "S"

    elif (posList[4][1] < posList[6][1] and posList[4][1] < posList[10][1] and fingers.count(1) == 2 and posList[3][2] > posList[4][2] and (posList[8][1] - posList[11][1]) <= 50):
        result = "U"
        
    elif (posList[4][1] < posList[6][1] and posList[4][1] < posList[10][1] and fingers.count(1) == 2 and posList[3][2] > posList[4][2]):
        result = "V"
    
    elif (posList[4][1] < posList[6][1] and posList[4][1] < posList[10][1] and fingers.count(1) == 3):
        result = "W"
    
    elif (fingers[0] == 0.5 and fingers.count(0) == 3 and posList[4][1] > posList[6][1]):
        result = "X"
    
    elif(fingers.count(0) == 3) and (posList[3][1] < posList[4][1]):
        if (len(fingers)==4 and fingers[3] == 1):
            result = "Y"
    
    return result


def handFider(img):
    detector = htm.handDetector(detectionCon = 0)
    img = detector.findHands(img)
    posList = detector.findPosition(img, draw=False)
    while True:
        img = detector.findHands(img)
        posList = detector.findPosition(img, draw=False)
        # print(posList)

        # tips = [4, 8, 12, 16, 20]

        if len(posList) != 0:
            # fingers = []


            # if posList[tips[0]][1] > posList[tips[0]-1][1]:
            #     fingers.append(1)
            # else:
            #     fingers.append(0)

            # for id in range(1,5):
            #     if posList[tips[id]][2] < posList[tips[id]-2][2]:
            #         fingers.append(1)
            #     else:
            #         fingers.append(0)

            # print(fingers)

            # totalfingers = fingers.count(1)
            # print(totalfingers)

            result = ""
            fingers = []

            finger_mcp = [5,9,13,17]
            finger_dip = [6,10,14,18]
            finger_pip = [7,11,15,19]
            finger_tip = [8,12,16,20]

            for id in range(4):
                if(posList[finger_tip[id]][1]+ 25  < posList[finger_dip[id]][1] and posList[16][2]<posList[20][2]):
                    fingers.append(0.25)
                elif(posList[finger_tip[id]][2] > posList[finger_dip[id]][2]):
                    fingers.append(0)
                elif(posList[finger_tip[id]][2] < posList[finger_pip[id]][2]): 
                    fingers.append(1)
                elif(posList[finger_tip[id]][1] > posList[finger_pip[id]][1] and posList[finger_tip[id]][1] > posList[finger_dip[id]][1]): 
                    fingers.append(0.5)

            print(fingers)
            # print(posList)

            if(posList[3][2] > posList[4][2]) and (posList[3][1] > posList[6][1])and (posList[4][2] < posList[6][2]) and fingers.count(0) == 4:
                result = "A"

            elif(posList[3][1] > posList[4][1]) and fingers.count(1) == 4:
                result = "B"

            elif(posList[3][1] > posList[6][1]) and fingers.count(0.5) >= 1 and (posList[4][2]> posList[8][2]):
                result = "C"

            elif(fingers[0]==1) and fingers.count(0) == 3 and (posList[3][1] > posList[4][1]):
                result = "D"

            elif (posList[3][1] < posList[6][1]) and fingers.count(0) == 4 and posList[12][2]<posList[4][2]:
                result = "E"

            elif (fingers.count(1) == 3) and (fingers[0]==0) and (posList[3][2] > posList[4][2]):
                result = "F"

            elif(fingers[0]==0.25) and fingers.count(0) == 3:
                result = "G"

            elif(fingers[0]==0.25) and(fingers[1]==0.25) and fingers.count(0) == 2:
                result = "H"

            elif (posList[4][1] < posList[6][1]) and fingers.count(0) == 3:
                if (len(fingers)==4 and fingers[3] == 1):
                    result = "I"

            elif (posList[4][1] < posList[6][1] and posList[4][1] > posList[10][1] and fingers.count(1) == 2):
                result = "K"

            elif(fingers[0]==1) and fingers.count(0) == 3 and (posList[3][1] < posList[4][1]):
                result = "L"

            elif (posList[4][1] < posList[16][1]) and fingers.count(0) == 4:
                result = "M"

            elif (posList[4][1] < posList[12][1]) and fingers.count(0) == 4:
                result = "N"

            # elif(posList[3][1] > posList[6][1]) and (posList[3][2] < posList[6][2]) and fingers.count(0.5) >= 1:
            #     result = "O"

            elif (posList[4][1] > posList[12][1]) and posList[4][2]<posList[6][2] and fingers.count(0) == 4:
                result = "T"

            elif (posList[4][1] > posList[12][1]) and posList[4][2]<posList[12][2] and fingers.count(0) == 4:
                result = "S"


            elif(posList[4][2] < posList[8][2]) and (posList[4][2] < posList[12][2]) and (posList[4][2] < posList[16][2]) and (posList[4][2] < posList[20][2]):
                result = "O"

            elif(fingers[2] == 0)  and (posList[4][2] < posList[12][2]) and (posList[4][2] > posList[6][2]):
                if (len(fingers)==4 and fingers[3] == 0):
                    result = "P"

            elif(fingers[1] == 0) and (fingers[2] == 0) and (fingers[3] == 0) and (posList[8][2] > posList[5][2]) and (posList[4][2] < posList[1][2]):
                result = "Q"

            # elif(posList[10][2] < posList[8][2] and fingers.count(0) == 4 and posList[4][2] > posList[14][2]):
            #     result = "Q" 

            elif(posList[8][1] < posList[12][1]) and (fingers.count(1) == 2) and (posList[9][1] > posList[4][1]):
                result = "R"

            # elif (posList[3][1] < posList[6][1]) and fingers.count(0) == 4:
            #     result = "S"

            elif (posList[4][1] < posList[6][1] and posList[4][1] < posList[10][1] and fingers.count(1) == 2 and posList[3][2] > posList[4][2] and (posList[8][1] - posList[11][1]) <= 50):
                result = "U"

            elif (posList[4][1] < posList[6][1] and posList[4][1] < posList[10][1] and fingers.count(1) == 2 and posList[3][2] > posList[4][2]):
                result = "V"

            elif (posList[4][1] < posList[6][1] and posList[4][1] < posList[10][1] and fingers.count(1) == 3):
                result = "W"

            elif (fingers[0] == 0.5 and fingers.count(0) == 3 and posList[4][1] > posList[6][1]):
                result = "X"

            elif(fingers.count(0) == 3) and (posList[3][1] < posList[4][1]):
                if (len(fingers)==4 and fingers[3] == 1):
                    result = "Y"

            # if(posList[4][1] < posList[])


            cv2.rectangle(img, (28,255), (178, 425), (0, 225, 0), cv2.FILLED)
            cv2.putText(img, str(result), (55,400), cv2.FONT_HERSHEY_COMPLEX,5, (255,0,0), 15)

        cv2.imshow("Image", img)
        cv2.waitKey(1)

# Socket.IO and route handlers
@socketio.on('connect')
def handle_connect():
    client_id = request.sid
    connected_clients.add(client_id)
    print(f'Client connected: {client_id}')
    emit('connection_response', {'status': 'connected'})

@socketio.on('disconnect')
def handle_disconnect():
    client_id = request.sid
    if client_id in connected_clients:
        connected_clients.remove(client_id)
    print(f'Client disconnected: {client_id}')

@socketio.on('predict')
def handle_prediction(data):
    try:
        base64_image = data['image']
        header, encoded = base64_image.split(',', 1) if ',' in base64_image else ('', base64_image)
        image_data = base64.b64decode(encoded)
        
        # Convert base64 to OpenCV image
        pil_image = Image.open(io.BytesIO(image_data)).convert('RGB')
        open_cv_image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
        #open_cv_image = cv2.rotate(open_cv_image, cv2.ROTATE_180)

        # Optional: get landmarks using Mediapipe
        rgb_image = cv2.cvtColor(open_cv_image, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_image)

        hand_sign = ""
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                posList = []
                for id, lm in enumerate(hand_landmarks.landmark):
                    h, w, _ = open_cv_image.shape
                    cx, cy = int(lm.x * w), int(lm.y * h)
                    posList.append((id, cx, cy))
                hand_sign = detect_hand_sign(posList)
                break

        # Use OpenCV image for prediction
        processed, pred_class, confidence = predict_sign_language(open_cv_image)

            # Generate timestamp for filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save original image with timestamp
        cv2.imwrite(f"debug/original_{timestamp}.jpg", open_cv_image)
        
        # Process and predict
        processed, pred_class, confidence = predict_sign_language(open_cv_image)
        
        # Save processed image with same timestamp
        success = cv2.imwrite(f"debug/processed_{timestamp}.jpg", processed)
        if success:
            print(f"image saved in debug/processed_{timestamp}.jpg")
        else:
            print("Failed to save processed image!")

        predictions = [class_mapping[pred_class]]  # You can build your own logic here
        is_ambig, group = is_ambiguous(predictions)
        
        emit('prediction_response', {
            'cnn_prediction': class_mapping[pred_class],
            'hand_sign': hand_sign,
            'confidence': float(round(confidence, 3)),
            'ambiguous': is_ambig,
            'group': list(group) if is_ambig else []
        })


    except Exception as e:
        emit('prediction_response', {
            'error': str(e)
        })
        print(f"[ERROR] Prediction failed: {str(e)}")

if __name__ == '__main__':
    print("Starting server...")
    socketio.run(app, 
                 host='0.0.0.0', 
                 port=5000, 
                 debug=True, 
                 use_reloader=False)