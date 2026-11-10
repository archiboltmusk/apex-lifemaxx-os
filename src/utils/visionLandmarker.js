// Computer Vision & Neural Landmarker Engine (MediaPipe Tasks Vision)
// Runs 100% offline using bundled models in /models/ and WASM binaries in /wasm/

import { FilesetResolver, PoseLandmarker, FaceLandmarker } from '@mediapipe/tasks-vision';

let cachedPoseLandmarker = null;
let cachedFaceLandmarker = null;
let isInitializingPose = false;
let isInitializingFace = false;

// 1. Initialize 33-Point 3D Skeletal Pose Landmarker
export async function getPoseLandmarker() {
  if (cachedPoseLandmarker) return cachedPoseLandmarker;
  if (isInitializingPose) return null;

  try {
    isInitializingPose = true;
    const wasmPath = `${window.location.origin}/wasm`;
    const vision = await FilesetResolver.forVisionTasks(wasmPath);
    
    cachedPoseLandmarker = await PoseLandmarker.createFromOptions(vision, {
      baseOptions: {
        modelAssetPath: `${window.location.origin}/models/pose_landmarker_full.task`,
        delegate: 'GPU',
      },
      runningMode: 'VIDEO',
      numPoses: 1,
      minPoseDetectionConfidence: 0.5,
      minPosePresenceConfidence: 0.5,
      minTrackingConfidence: 0.5,
    });
    return cachedPoseLandmarker;
  } catch (err) {
    console.warn('Local WASM init failed, attempting CDN fallback:', err);
    try {
      const visionCDN = await FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm'
      );
      cachedPoseLandmarker = await PoseLandmarker.createFromOptions(visionCDN, {
        baseOptions: {
          modelAssetPath: `${window.location.origin}/models/pose_landmarker_full.task`,
          delegate: 'GPU',
        },
        runningMode: 'VIDEO',
        numPoses: 1,
      });
      return cachedPoseLandmarker;
    } catch (cdnErr) {
      console.warn('PoseLandmarker initialization error:', cdnErr);
      return null;
    }
  } finally {
    isInitializingPose = false;
  }
}

// 2. Initialize 478-Point 3D Face Landmarker
export async function getFaceLandmarker() {
  if (cachedFaceLandmarker) return cachedFaceLandmarker;
  if (isInitializingFace) return null;

  try {
    isInitializingFace = true;
    const wasmPath = `${window.location.origin}/wasm`;
    const vision = await FilesetResolver.forVisionTasks(wasmPath);

    cachedFaceLandmarker = await FaceLandmarker.createFromOptions(vision, {
      baseOptions: {
        modelAssetPath: `${window.location.origin}/models/face_landmarker.task`,
        delegate: 'GPU',
      },
      runningMode: 'VIDEO',
      numFaces: 1,
      minFaceDetectionConfidence: 0.5,
      minFacePresenceConfidence: 0.5,
      minTrackingConfidence: 0.5,
      outputFaceBlendshapes: true,
      outputFacialTransformationMatrixes: true,
    });
    return cachedFaceLandmarker;
  } catch (err) {
    console.warn('Local WASM face init failed, attempting CDN fallback:', err);
    try {
      const visionCDN = await FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm'
      );
      cachedFaceLandmarker = await FaceLandmarker.createFromOptions(visionCDN, {
        baseOptions: {
          modelAssetPath: `${window.location.origin}/models/face_landmarker.task`,
          delegate: 'GPU',
        },
        runningMode: 'VIDEO',
        numFaces: 1,
      });
      return cachedFaceLandmarker;
    } catch (cdnErr) {
      console.warn('FaceLandmarker initialization error:', cdnErr);
      return null;
    }
  } finally {
    isInitializingFace = false;
  }
}

// 3. Mathematical Joint Angle Calculation: angle at vertex p2
// Calculates angle between vectors (p1 - p2) and (p3 - p2) in degrees
export function calculateJointAngle(p1, p2, p3) {
  if (!p1 || !p2 || !p3) return 180;
  const radians =
    Math.atan2(p3.y - p2.y, p3.x - p2.x) - Math.atan2(p1.y - p2.y, p1.x - p2.x);
  let angle = Math.abs((radians * 180.0) / Math.PI);
  if (angle > 180.0) {
    angle = 360.0 - angle;
  }
  return Math.round(angle);
}

// 4. Euclidean distance between two 2D/3D points
export function calculateDistance(p1, p2) {
  if (!p1 || !p2) return 0;
  const dx = p1.x - p2.x;
  const dy = p1.y - p2.y;
  return Math.sqrt(dx * dx + dy * dy);
}

// 5. Connectors definition for 33 MediaPipe pose landmarks
export const POSE_CONNECTIONS = [
  // Face & Head
  [0, 1], [1, 2], [2, 3], [3, 7], [0, 4], [4, 5], [5, 6], [6, 8],
  [9, 10], // Mouth
  // Torso
  [11, 12], // Left shoulder to right shoulder
  [11, 23], // Left shoulder to left hip
  [12, 24], // Right shoulder to right hip
  [23, 24], // Left hip to right hip
  // Left arm
  [11, 13], // Shoulder to elbow
  [13, 15], // Elbow to wrist
  [15, 17], [15, 19], [15, 21], // Wrist to hand
  // Right arm
  [12, 14], // Shoulder to elbow
  [14, 16], // Elbow to wrist
  [16, 18], [16, 20], [16, 22], // Wrist to hand
  // Left leg
  [23, 25], // Hip to knee
  [25, 27], // Knee to ankle
  [27, 29], [27, 31], [29, 31], // Ankle to foot
  // Right leg
  [24, 26], // Hip to knee
  [26, 28], // Knee to ankle
  [28, 30], [28, 32], [30, 32], // Ankle to foot
];
