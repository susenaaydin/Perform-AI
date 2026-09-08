import os
import firebase_admin
from firebase_admin import credentials, firestore

db = None
try:
    base_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    cred_path = os.path.join(base_dir, "config", "serviceAccountKey.json")
    
    fallback_paths = [
        cred_path,
        "backend/config/serviceAccountKey.json",
        "config/serviceAccountKey.json",
        "serviceAccountKey.json"
    ]
    
    selected_cred = None
    for path in fallback_paths:
        if os.path.exists(path):
            selected_cred = path
            break
            
    if selected_cred:
        cred = credentials.Certificate(selected_cred)
        firebase_admin.initialize_app(cred)
        print(f"[INFO] Firebase initialized with Service Account Key at: {selected_cred}")
    else:
        firebase_admin.initialize_app()
        print("[INFO] Firebase initialized with default credentials.")
    db = firestore.client()
except Exception as e:
    print(f"[WARN] Failed to initialize Firebase: {e}. Firestore operations will fallback to console prints.")
