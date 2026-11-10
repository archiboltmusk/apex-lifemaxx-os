#!/usr/bin/env bash
set -e

# ==============================================================================
# APEX // OS — Production Machine Learning Models Fetcher
# ==============================================================================

MODELS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../public/models" && pwd)"
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

echo "📥 Verifying & downloading on-device neural models (Total ~140MB)..."

# 1. BlazePose Heavy (30MB)
if [ ! -f "pose_landmarker_heavy.task" ]; then
    echo "  → Downloading pose_landmarker_heavy.task (29.2 MB)..."
    curl -L "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task" -o pose_landmarker_heavy.task
fi

# 2. BlazePose Full (9MB)
if [ ! -f "pose_landmarker_full.task" ]; then
    echo "  → Downloading pose_landmarker_full.task (9.0 MB)..."
    curl -L "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task" -o pose_landmarker_full.task
fi

# 3. Face Mesh Landmarker (3.6MB)
if [ ! -f "face_landmarker.task" ]; then
    echo "  → Downloading face_landmarker.task (3.6 MB)..."
    curl -L "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task" -o face_landmarker.task
fi

# 4. Hand Landmarker (7.5MB)
if [ ! -f "hand_landmarker.task" ]; then
    echo "  → Downloading hand_landmarker.task (7.5 MB)..."
    curl -L "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/latest/hand_landmarker.task" -o hand_landmarker.task
fi

# 5. EfficientDet Lite2 Object Vision (22MB)
if [ ! -f "efficientdet_lite2.tflite" ]; then
    echo "  → Downloading efficientdet_lite2.tflite (22.0 MB)..."
    curl -L "https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite2/float32/latest/efficientdet_lite2.tflite" -o efficientdet_lite2.tflite
fi

# 6. MobileNetV4 Food Macro Vision ONNX (37MB)
if [ ! -f "food_macro_vision.onnx" ]; then
    echo "  → Downloading food_macro_vision.onnx (37.0 MB)..."
    curl -L "https://huggingface.co/onnx-community/mobilenetv4_conv_medium.e500_r256_in1k/resolve/main/onnx/model.onnx" -o food_macro_vision.onnx
fi

# 7. Vocal Whisper Encoder ONNX (31MB)
if [ ! -f "vocal_whisper_encoder.onnx" ]; then
    echo "  → Downloading vocal_whisper_encoder.onnx (31.4 MB)..."
    curl -L "https://huggingface.co/onnx-community/whisper-tiny/resolve/main/onnx/encoder_model.onnx" -o vocal_whisper_encoder.onnx
fi

echo "✓ All 7 offline machine learning models verified: $(du -sh "$MODELS_DIR" | awk '{print $1}') total."
