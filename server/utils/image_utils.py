import cv2
import numpy as np
from PIL import Image

def extract_signature_regions(pil_image):
    # Convert to grayscale and detect edges
    open_cv_image = np.array(pil_image)
    gray = cv2.cvtColor(open_cv_image, cv2.COLOR_RGB2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blur, 127, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    # Find contours
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    signature_images = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)

        # Heuristic: Signature-like bounding box (adjust as needed)
        if w > 100 and h > 30 and w/h > 2:
            cropped = pil_image.crop((x, y, x + w, y + h))
            signature_images.append(cropped)

    return signature_images
