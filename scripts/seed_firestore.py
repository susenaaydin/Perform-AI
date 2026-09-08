#!/usr/bin/env python3
"""
PerformAI - Firestore Database Seeder
This script populates the Cloud Firestore 'triads' collection with default theatrical monologue scripts.
"""

import os
import re
import json
import firebase_admin
from firebase_admin import credentials, firestore

def get_slug(name: str) -> str:
    slug = name.lower()
    replacements = {
        'ı': 'i', 'ğ': 'g', 'ü': 'u', 'ş': 's', 'ö': 'o', 'ç': 'c',
        'â': 'a', 'î': 'i', 'û': 'u'
    }
    for tr, eng in replacements.items():
        slug = slug.replace(tr, eng)
    slug = re.sub(r'[^a-z0-9\s/]', '', slug)
    slug = slug.replace('/', '_')
    slug = re.sub(r'\s+', '_', slug)
    return slug

def main():
    script_dir = os.path.dirname(os.path.realpath(__file__))
    project_root = os.path.dirname(script_dir)
    
    # 1. Locate service account credentials
    cred_paths = [
        os.path.join(project_root, "backend", "config", "serviceAccountKey.json"),
        os.path.join(project_root, "serviceAccountKey.json"),
        os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "")
    ]
    
    selected_cred = None
    for p in cred_paths:
        if p and os.path.exists(p):
            selected_cred = p
            break
            
    if selected_cred:
        cred = credentials.Certificate(selected_cred)
        firebase_admin.initialize_app(cred)
        print(f"[INFO] Firebase initialized with: {selected_cred}")
    else:
        try:
            firebase_admin.initialize_app()
            print("[INFO] Firebase initialized with default application credentials.")
        except Exception as e:
            print(f"[ERROR] Could not initialize Firebase Admin SDK: {e}")
            print("Please place 'serviceAccountKey.json' in 'backend/config/' or set GOOGLE_APPLICATION_CREDENTIALS.")
            return

    db = firestore.client()

    # 2. Load triads JSON
    json_path = os.path.join(script_dir, "data", "triads.json")
    if not os.path.exists(json_path):
        print(f"[ERROR] Monologue data not found at: {json_path}")
        return

    with open(json_path, "r", encoding="utf-8") as f:
        triads = json.load(f)

    print(f"[INFO] Loaded {len(triads)} monologues from {json_path}.")

    # Default character imagery
    img_hamlet = "https://lh3.googleusercontent.com/aida-public/AB6AXuBLNlgRkqU2euc_mW1Tz_YSZVjIcVrEc-TGOGDZCHay3GaNjLqUstcs-XngHIUjWGpHWuqRCeO98wjL_PT-Q0wsy-1ZNJIxa2ZGg5iUctOQ7HjAHo-gTs451PJySrjRqxWXDbHb8HYoZe2UA9EHLWASWNkEYABqjMDKM-X6_62lOi4hlFRTtL3Pe_IV0EmOYqMNoZh9tlAwrRKyN-3mR_lb3FANXUHHg1YY14JJpqTgtIxHrvPJ9Y2Jf8zVzw_Hd-HVULsM-EPYJ7I"
    img_ophelia = "https://lh3.googleusercontent.com/aida-public/AB6AXuCw9pMJSDsCkdOVITlRhHP9ZYf5VGOrdjuAaZ-EnFbb6zg-_yrOx3AXxUEEgDhx-EWN_sDGJ8wQXhGTJPRsVCLXTc0jkB_-EHVIVJcIGMommQE7IWQ1QaDB1ev3HJlvgh0AY4v-eEJxqrjvpcEFTqTmNJCGl8BLgY1FIG76M0N4z5p45I3QSK0Jbo0LHF1vhakNh0qzi9CLXYqosimEcZKGU-xjm_7gIu4BDMGM2pcw4ZtMP54oLpH2sUdSNTHgiHNpC1XxgKiXiiQ"
    img_macbeth = "https://lh3.googleusercontent.com/aida-public/AB6AXuAFmS7fSkntC4CZhAgojLUXznhsGc6uLPskAxfm5wcWtpBNjUi2qOAkSRBFzIUYu5sJqMC0F6ROdqmBU_ZlNUBVgQ9htIQ11k7nHlCeqWC8sEFZcRATueR78Sy0fGFcT8H5u8dKLj_ababZ-1ca5fSUwd0WYM7MPMHnRJ9Tf4wWndwoDgrbkpnO6ZmIF4k1kO-TUX2MB0QEBnZexCCW1NCYE9Q-5s_mGAaQ4ezooxgteLU3fgsI9sNBkISb53pD7gPZwsHJyBCbLhg"

    def resolve_image(char_name: str) -> str:
        lower = char_name.lower()
        if "ophelia" in lower or any(k in char_name for k in ["Gülseren", "Yalnız Kadın", "Nina", "Nilüfer"]):
            return img_ophelia
        if "macbeth" in lower or "harpagon" in lower:
            return img_macbeth
        return img_hamlet

    batch = db.batch()
    for item in triads:
        char_name = item.get("name", "Unknown")
        doc_id = get_slug(char_name)
        doc_ref = db.collection("triads").document(doc_id)
        
        data = {
            "id": doc_id,
            "name": char_name,
            "author": item.get("author", "Anonim"),
            "difficulty": item.get("difficulty", "Orta"),
            "duration": item.get("duration", "2dk"),
            "targetEmotion": item.get("targetEmotion", "Dramatik"),
            "rules": item.get("rules", ""),
            "script": item.get("script", ""),
            "imageUrl": resolve_image(char_name),
        }
        batch.set(doc_ref, data, merge=True)

    batch.commit()
    print(f"[SUCCESS] Successfully seeded {len(triads)} monologues into Firestore 'triads' collection.")

if __name__ == "__main__":
    main()
