#!/bin/bash
# ==============================================================================
# PerformAI Backend - Cloud GPU & Linux Server Setup Script
# Compatible with: Ubuntu 22.04 / 24.04 (RunPod, Vast.ai, AWS, GCP, Azure)
# ==============================================================================

set -e

echo "=== [1/6] Updating System Repositories and Installing System Dependencies ==="
apt-get update && apt-get install -y software-properties-common
apt-get install -y \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    ffmpeg \
    libsndfile1 \
    libsndfile1-dev \
    libgl1 \
    libglib2.0-0t64 \
    git \
    curl \
    libxrender1 \
    libxext6

WORKSPACE_DIR=${WORKSPACE_DIR:-/workspace}
cd "$WORKSPACE_DIR"

echo "=== [2/6] Setting Up Python 3.12 Virtual Environment ==="
python3.12 -m venv "$WORKSPACE_DIR/venv"
source "$WORKSPACE_DIR/venv/bin/activate"

pip install --upgrade pip setuptools wheel

echo "=== [3/6] Installing PyTorch with CUDA 12.4 Acceleration ==="
pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124

echo "=== [4/6] Installing Transformers, Audio & ML Libraries ==="
pip install huggingface-hub==0.28.1 tokenizers==0.21.0
pip install transformers==4.48.3 accelerate==1.3.0 soundfile==0.13.1 librosa==0.10.2.post1 scikit-learn

echo "=== [5/6] Installing FastAPI, MediaPipe & AI Orchestration Dependencies ==="
pip install fastapi "uvicorn[standard]" websockets pydantic firebase-admin opencv-python mediapipe aiohttp python-multipart google-genai google-generativeai

# Remove conflicting torchvision if pulled as transitive dependency
pip uninstall -y torchvision || true
pip cache purge

pip install nvidia-cublas-cu12 nvidia-cudnn-cu12

echo "=== [6/6] Configuring Environment Paths ==="
export PYTHONPATH="$WORKSPACE_DIR"
export HF_SKIP_TORCH_LOAD_SAFETY_CHECK=1
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$WORKSPACE_DIR/venv/lib/python3.12/site-packages/nvidia/cublas/lib/:$WORKSPACE_DIR/venv/lib/python3.12/site-packages/nvidia/cudnn/lib/"

# Persist environment variables
if [ -f ~/.bashrc ]; then
    echo "export PYTHONPATH=$WORKSPACE_DIR" >> ~/.bashrc
    echo "export HF_SKIP_TORCH_LOAD_SAFETY_CHECK=1" >> ~/.bashrc
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$WORKSPACE_DIR/venv/lib/python3.12/site-packages/nvidia/cublas/lib/:$WORKSPACE_DIR/venv/lib/python3.12/site-packages/nvidia/cudnn/lib/" >> ~/.bashrc
fi

echo "=============================================================================="
echo "PerformAI Backend Environment Setup Completed Successfully!"
echo "To start the server, activate the virtual environment and run:"
echo "  source $WORKSPACE_DIR/venv/bin/activate"
echo "  python3 -m backend.main"
echo "=============================================================================="
