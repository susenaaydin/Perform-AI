import os
import sys
os.environ["HF_SKIP_TORCH_LOAD_SAFETY_CHECK"] = "1" 

os.environ["HF_TRUST_ANONYMOUS_CODE"] = "1"
os.environ["TRANSFORMERS_VERIFY_SCHEDULES"] = "0"
import uvicorn

# Dynamic import path resolver to allow starting from project root or backend folder
current_dir = os.path.dirname(os.path.realpath(__file__))
parent_dir = os.path.dirname(current_dir)

if current_dir not in sys.path:
    sys.path.insert(0, current_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

if __name__ == "__main__":
    uvicorn.run("backend.app:app", host="0.0.0.0", port=8000, reload=False)
