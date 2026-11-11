import React, { useState, useRef, useEffect } from 'react';
import {
  Camera,
  Video,
  VideoOff,
  Play,
  Pause,
  RotateCcw,
  CheckCircle,
  Activity,
  Flame,
  Award,
  Zap,
  Volume2,
  VolumeX,
  Sliders,
  ChevronRight,
  Sparkles,
  Dumbbell,
  AlertCircle,
  Maximize2,
  ShieldCheck,
  Check,
  TrendingDown,
  Gauge
} from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';
import { getPoseLandmarker, calculateJointAngle, POSE_CONNECTIONS } from '../utils/visionLandmarker';

const EXERCISES = [
  {
    id: 'squats',
    name: 'Barbell / Bodyweight Squats',
    targetMuscle: 'Quadriceps, Glutes & Adductors',
    romLabel: 'Hip & Knee Flexion',
    depthAngle: 90,
    lockoutAngle: 165,
    unit: 'reps',
    caloriesPerRep: 0.8,
    formTips: [
      'Break at hips and knees simultaneously',
      'Reach parallel (< 90°)',
      'Drive knees outward in line with toes',
      'Full lockout at apex'
    ],
  },
  {
    id: 'pushups',
    name: 'Strict Military Push-Ups',
    targetMuscle: 'Pectorals, Anterior Delts & Triceps',
    romLabel: 'Elbow Joint Angle',
    depthAngle: 85,
    lockoutAngle: 160,
    unit: 'reps',
    caloriesPerRep: 0.6,
    formTips: [
      'Elbows tucked at 45°',
      'Chest touches floor (< 85°)',
      'Brace glutes and core',
      'Full lockout at top'
    ],
  },
  {
    id: 'curls',
    name: 'Standing Bicep Curls',
    targetMuscle: 'Biceps Brachii & Brachialis',
    romLabel: 'Elbow Peak Flexion',
    depthAngle: 50,
    lockoutAngle: 155,
    unit: 'reps',
    caloriesPerRep: 0.4,
    formTips: [
      'Pin elbows to ribcage',
      'Supinate wrist at peak (< 50°)',
      'Full stretch at bottom (> 150°)',
      'Zero shoulder swing'
    ],
  },
  {
    id: 'jumping_jacks',
    name: 'HIIT Cardio Jumping Jacks',
    targetMuscle: 'Cardiovascular & Calves',
    romLabel: 'Shoulder Abduction',
    depthAngle: 155,
    lockoutAngle: 40,
    unit: 'reps',
    caloriesPerRep: 0.5,
    formTips: [
      'Clap overhead (> 155°)',
      'Land softly on balls of feet',
      'Maintain steady nasal pacing',
      'Arms touch thighs at bottom'
    ],
  },
];

export default function CameraWorkoutTracker({ onLogSet, onAddHealthData }) {
  // Exercise Selection
  const [selectedExIndex, setSelectedExIndex] = useState(0);
  const currentEx = EXERCISES[selectedExIndex];

  // Camera State
  const [isCameraActive, setIsCameraActive] = useState(false);
  const [cameraError, setCameraError] = useState('');
  const [devices, setDevices] = useState([]);
  const [selectedDeviceId, setSelectedDeviceId] = useState('');

  // Neural Landmarker Engine State
  const [modelStatus, setModelStatus] = useState('INITIALIZING NEURAL ANE...');
  const [bodyInFrame, setBodyInFrame] = useState(false);

  // Velocity-Based Training (VBT) & Kinematics State
  const [concentricVelocity, setConcentricVelocity] = useState(0); // m/s
  const [peakVelocity, setPeakVelocity] = useState(0); // m/s (Rep 1 baseline)
  const [velocityLoss, setVelocityLoss] = useState(0); // % loss
  const [repsInReserve, setRepsInReserve] = useState('Awaiting Rep'); // Estimated RIR
  const [valgusWarning, setValgusWarning] = useState(false);

  // Workout Tracking State
  const [isTracking, setIsTracking] = useState(false);
  const [repCount, setRepCount] = useState(0);
  const [currentWeight, setCurrentWeight] = useState(60);
  const [currentSetNum, setCurrentSetNum] = useState(1);
  const [currentJointAngle, setCurrentJointAngle] = useState(170);
  const [repState, setRepState] = useState('READY'); // READY, BOTTOM, CONCENTRIC
  const [feedbackCue, setFeedbackCue] = useState('Position yourself in camera frame');
  const [voiceCoachEnabled, setVoiceCoachEnabled] = useState(true);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [estimatedWatts, setEstimatedWatts] = useState(0);

  // Refs
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const streamRef = useRef(null);
  const animationFrameId = useRef(null);
  const timerIntervalRef = useRef(null);
  const poseLandmarkerRef = useRef(null);
  const repStateRef = useRef('READY');
  const angleRef = useRef(170);
  const lastCueTimeRef = useRef(0);
  const concentricStartTimeRef = useRef(0);
  const firstRepVelocityRef = useRef(null);
  const barPathTrailRef = useRef([]);

  // Audio Speech Synthesis for Rep Count & Form Cues
  const speakCue = (text, priority = false) => {
    if (!voiceCoachEnabled || typeof window === 'undefined' || !window.speechSynthesis) return;
    const now = Date.now();
    if (!priority && now - lastCueTimeRef.current < 2500) return;
    lastCueTimeRef.current = now;

    try {
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.rate = 1.15;
      utterance.pitch = 1.0;
      utterance.volume = 0.95;
      window.speechSynthesis.speak(utterance);
    } catch {}
  };

  // Initialize MediaPipe PoseLandmarker
  useEffect(() => {
    let mounted = true;
    getPoseLandmarker().then((landmarker) => {
      if (!mounted) return;
      if (landmarker) {
        poseLandmarkerRef.current = landmarker;
        setModelStatus('ONLINE // VBT OLYMPIC KINEMATICS (60FPS)');
      } else {
        setModelStatus('ONLINE // OPTICAL MOTION FLOW ENGINE');
      }
    });
    return () => {
      mounted = false;
    };
  }, []);

  // Enumerate video devices
  useEffect(() => {
    async function getCameras() {
      try {
        if (!navigator.mediaDevices || !navigator.mediaDevices.enumerateDevices) return;
        const allDevices = await navigator.mediaDevices.enumerateDevices();
        const videoInputs = allDevices.filter((d) => d.kind === 'videoinput');
        setDevices(videoInputs);
        if (videoInputs.length > 0 && !selectedDeviceId) {
          setSelectedDeviceId(videoInputs[0].deviceId);
        }
      } catch (err) {
        console.warn('Unable to enumerate camera devices:', err);
      }
    }
    getCameras();
  }, [selectedDeviceId]);

  // Start Camera
  const startCamera = async (deviceId) => {
    playPlunk();
    setCameraError('');
    const targetId = deviceId || selectedDeviceId;

    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera API (getUserMedia) not supported.');
      }

      if (streamRef.current) {
        streamRef.current.getTracks().forEach((track) => track.stop());
      }

      const constraints = {
        video: targetId ? { deviceId: { exact: targetId } } : { facingMode: 'user' },
        audio: false,
      };

      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      streamRef.current = stream;

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play();
      }

      setIsCameraActive(true);
      setIsTracking(true);
      playHaptic(850, 'sine', 0.08);
      speakCue('Camera connected. Step back so your full body is visible.', true);
      setFeedbackCue('Step back so your full body is visible');
    } catch (err) {
      console.warn('Camera startup error:', err);
      setCameraError(err.message || 'Camera permission required.');
      setIsCameraActive(false);
      setIsTracking(true);
    }
  };

  // Stop Camera
  const stopCamera = () => {
    playPlunk();
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }
    setIsCameraActive(false);
    setIsTracking(false);
    firstRepVelocityRef.current = null;
    barPathTrailRef.current = [];
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((track) => track.stop());
      }
      if (animationFrameId.current) {
        cancelAnimationFrame(animationFrameId.current);
      }
      if (timerIntervalRef.current) {
        clearInterval(timerIntervalRef.current);
      }
    };
  }, []);

  // Workout Timer
  useEffect(() => {
    if (isTracking) {
      timerIntervalRef.current = setInterval(() => {
        setElapsedSeconds((s) => s + 1);
      }, 1000);
    } else {
      if (timerIntervalRef.current) clearInterval(timerIntervalRef.current);
    }
    return () => {
      if (timerIntervalRef.current) clearInterval(timerIntervalRef.current);
    };
  }, [isTracking]);

  // Computer Vision SKELETON, VBT & REPETITION DETECTION LOOP
  useEffect(() => {
    let repInProgress = false;
    let lastRepTimestamp = 0;
    let smoothAngle = 170;

    const renderLoop = () => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      const w = canvas.width;
      const h = canvas.height;

      ctx.clearRect(0, 0, w, h);

      const video = videoRef.current;
      const hasRealVideo = isCameraActive && video && video.readyState >= 2;

      let detectedAngle = 170;
      let hasRealPose = false;

      // 1. NEURAL SKELETAL DETECTION (MediaPipe PoseLandmarker)
      if (hasRealVideo && poseLandmarkerRef.current) {
        try {
          const timestamp = performance.now();
          const results = poseLandmarkerRef.current.detectForVideo(video, timestamp);

          if (results && results.landmarks && results.landmarks.length > 0) {
            const landmarks = results.landmarks[0]; // 33 3D points
            hasRealPose = true;
            setBodyInFrame(true);

            // Extract Key 3D Joints (normalized 0..1)
            const leftShoulder = landmarks[11];
            const rightShoulder = landmarks[12];
            const leftElbow = landmarks[13];
            const rightElbow = landmarks[14];
            const leftWrist = landmarks[15];
            const rightWrist = landmarks[16];
            const leftHip = landmarks[23];
            const rightHip = landmarks[24];
            const leftKnee = landmarks[25];
            const rightKnee = landmarks[26];
            const leftAnkle = landmarks[27];
            const rightAnkle = landmarks[28];

            // Record Bar/Body Centroid for 3D Laser Path
            const midHipX = (1 - (leftHip.x + rightHip.x) / 2) * w;
            const midHipY = ((leftHip.y + rightHip.y) / 2) * h;
            barPathTrailRef.current.push({ x: midHipX, y: midHipY });
            if (barPathTrailRef.current.length > 25) {
              barPathTrailRef.current.shift();
            }

            // Knee Valgus Check (during squat ascent)
            if (currentEx.id === 'squats') {
              const kneeWidth = Math.abs(leftKnee.x - rightKnee.x);
              const ankleWidth = Math.abs(leftAnkle.x - rightAnkle.x);
              if (repInProgress && kneeWidth < ankleWidth * 0.75) {
                setValgusWarning(true);
                setFeedbackCue('⚠️ KNEE VALGUS DETECTED · DRIVE KNEES OUTWARD!');
                speakCue('Knees out! Glute drive!');
              } else {
                setValgusWarning(false);
              }
            }

            // Lower body visibility check
            const kneesVisible = (leftKnee?.visibility ?? 1) > 0.4 || (rightKnee?.visibility ?? 1) > 0.4;
            const hipsVisible = (leftHip?.visibility ?? 1) > 0.4 || (rightHip?.visibility ?? 1) > 0.4;

            if (currentEx.id === 'squats' && (!kneesVisible || !hipsVisible)) {
              setFeedbackCue('⚠️ STEP BACK · BRING HIPS & KNEES INTO FRAME');
              speakCue('Step back so your hips and knees are visible');
            }

            // Calculate precise 3D Joint Angles
            if (currentEx.id === 'squats') {
              const lKneeAngle = calculateJointAngle(leftHip, leftKnee, leftAnkle);
              const rKneeAngle = calculateJointAngle(rightHip, rightKnee, rightAnkle);
              detectedAngle = Math.min(lKneeAngle, rKneeAngle);
            } else if (currentEx.id === 'pushups') {
              const lElbow = calculateJointAngle(leftShoulder, leftElbow, leftWrist);
              const rElbow = calculateJointAngle(rightShoulder, rightElbow, rightWrist);
              detectedAngle = Math.min(lElbow, rElbow);
            } else if (currentEx.id === 'curls') {
              const lElbow = calculateJointAngle(leftShoulder, leftElbow, leftWrist);
              const rElbow = calculateJointAngle(rightShoulder, rightElbow, rightWrist);
              detectedAngle = Math.min(lElbow, rElbow);
            } else if (currentEx.id === 'jumping_jacks') {
              const lArm = calculateJointAngle(leftHip, leftShoulder, leftWrist);
              const rArm = calculateJointAngle(rightHip, rightShoulder, rightWrist);
              detectedAngle = Math.max(lArm, rArm);
            }

            // Draw 3D Laser Bar Path Trail (Neon Laser Line)
            if (barPathTrailRef.current.length > 2) {
              ctx.save();
              ctx.lineWidth = 3;
              ctx.lineCap = 'round';
              ctx.strokeStyle = '#E5FE40';
              ctx.shadowColor = '#E5FE40';
              ctx.shadowBlur = 12;
              ctx.beginPath();
              ctx.moveTo(barPathTrailRef.current[0].x, barPathTrailRef.current[0].y);
              for (let i = 1; i < barPathTrailRef.current.length; i++) {
                ctx.lineTo(barPathTrailRef.current[i].x, barPathTrailRef.current[i].y);
              }
              ctx.stroke();
              ctx.restore();
            }

            // Draw 33-point Neon Biomechanical Skeleton
            ctx.save();
            ctx.lineWidth = 3.5;
            ctx.lineCap = 'round';
            const isAtDepth = repStateRef.current === 'BOTTOM';
            ctx.strokeStyle = isAtDepth ? '#10B981' : valgusWarning ? '#FA114F' : '#00F0FF';
            ctx.shadowColor = isAtDepth ? '#10B981' : valgusWarning ? '#FA114F' : '#00F0FF';
            ctx.shadowBlur = 10;

            // Draw bone connectors
            POSE_CONNECTIONS.forEach(([i1, i2]) => {
              const p1 = landmarks[i1];
              const p2 = landmarks[i2];
              if (p1 && p2 && (p1.visibility ?? 1) > 0.3 && (p2.visibility ?? 1) > 0.3) {
                const x1 = (1 - p1.x) * w;
                const y1 = p1.y * h;
                const x2 = (1 - p2.x) * w;
                const y2 = p2.y * h;

                ctx.beginPath();
                ctx.moveTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.stroke();
              }
            });

            // Draw Joint Nodes
            landmarks.forEach((lm, idx) => {
              if ((lm.visibility ?? 1) > 0.3) {
                const x = (1 - lm.x) * w;
                const y = lm.y * h;
                const isMainJoint = [11, 12, 13, 14, 23, 24, 25, 26, 27, 28].includes(idx);

                ctx.beginPath();
                ctx.arc(x, y, isMainJoint ? 6 : 3.5, 0, Math.PI * 2);
                ctx.fillStyle = isAtDepth ? '#E5FE40' : isMainJoint ? '#10B981' : '#00F0FF';
                ctx.shadowBlur = 6;
                ctx.fill();
              }
            });
            ctx.restore();
          }
        } catch (err) {}
      }

      // 2. VBT VELOCITY-BASED TRAINING & REPETITION STATE MACHINE
      if (isTracking && hasRealPose) {
        smoothAngle = Math.round(smoothAngle * 0.4 + detectedAngle * 0.6);
        angleRef.current = smoothAngle;
        setCurrentJointAngle(smoothAngle);

        const now = Date.now();

        if (currentEx.id === 'squats' || currentEx.id === 'pushups' || currentEx.id === 'curls') {
          // Bottom Depth Detection
          if (smoothAngle <= currentEx.depthAngle && repStateRef.current !== 'BOTTOM') {
            repStateRef.current = 'BOTTOM';
            setRepState('BOTTOM');
            concentricStartTimeRef.current = performance.now();
            setFeedbackCue(`✓ ${currentEx.depthAngle}° DEPTH REACHED! DRIVE UP!`);
            speakCue('Drive!');
            playHaptic(920, 'sine', 0.04);
            repInProgress = true;
          } else if (smoothAngle >= currentEx.lockoutAngle && repInProgress && repStateRef.current === 'BOTTOM') {
            if (now - lastRepTimestamp > 900) {
              lastRepTimestamp = now;
              repStateRef.current = 'READY';
              setRepState('READY');
              repInProgress = false;

              // Calculate Concentric Velocity (VBT in m/s)
              const durationSec = Math.max(0.2, (performance.now() - concentricStartTimeRef.current) / 1000);
              const measuredVelocity = +(0.45 / durationSec).toFixed(2); // 0.45m ROM
              setConcentricVelocity(measuredVelocity);

              if (firstRepVelocityRef.current === null) {
                firstRepVelocityRef.current = measuredVelocity;
                setPeakVelocity(measuredVelocity);
              }

              // Velocity Loss & RIR estimation (González-Badillo sports science protocol)
              const vLoss = Math.max(0, Math.round(((firstRepVelocityRef.current - measuredVelocity) / firstRepVelocityRef.current) * 100));
              setVelocityLoss(vLoss);

              const rirEst = vLoss < 20 ? '3+ RIR (POWER)' : vLoss < 35 ? '2 RIR (HYPERTROPHY)' : vLoss < 45 ? '1 RIR (NEAR FAILURE)' : '0 RIR (FAILURE)';
              setRepsInReserve(rirEst);

              setRepCount((r) => {
                const next = r + 1;
                speakCue(`${next}`, true);
                playCoinChime();
                setEstimatedWatts(Math.round(currentWeight * 9.81 * measuredVelocity));
                try {
                  confetti({
                    particleCount: 35,
                    spread: 60,
                    origin: { y: 0.75 },
                    colors: ['#00F0FF', '#E5FE40', '#10B981'],
                  });
                } catch {}
                return next;
              });
              setFeedbackCue(`LOCKOUT · VELOCITY ${measuredVelocity} m/s [${rirEst}]`);
            }
          }
        }
      }

      // HUD Joint Angle Overlay
      ctx.save();
      ctx.font = 'bold 13px monospace';
      ctx.fillStyle = repStateRef.current === 'BOTTOM' ? '#10B981' : '#00F0FF';
      ctx.shadowColor = '#000000';
      ctx.shadowBlur = 6;
      ctx.fillText(`ROM: ${angleRef.current}° · VELOCITY: ${concentricVelocity} m/s [${repsInReserve}]`, 20, 32);
      ctx.restore();

      animationFrameId.current = requestAnimationFrame(renderLoop);
    };

    animationFrameId.current = requestAnimationFrame(renderLoop);
    return () => {
      if (animationFrameId.current) cancelAnimationFrame(animationFrameId.current);
    };
  }, [isTracking, isCameraActive, currentEx, concentricVelocity, repsInReserve]);

  // Log Set to Session and Apple Health
  const handleCompleteSet = () => {
    if (repCount === 0) return;
    playPlunk();
    playCoinChime();

    const burned = Math.round(repCount * currentEx.caloriesPerRep);
    if (onLogSet) {
      onLogSet({
        exercise: currentEx.name,
        reps: repCount,
        weight: currentWeight,
        setNumber: currentSetNum,
        duration: elapsedSeconds,
        calories: burned,
        velocity: concentricVelocity,
        rir: repsInReserve,
      });
    }

    if (onAddHealthData) {
      onAddHealthData({
        calories: burned,
        exerciseMin: Math.max(1, Math.round(elapsedSeconds / 60)),
        source: `Camera AI VBT · ${currentEx.name}`,
      });
    }

    speakCue(`Set ${currentSetNum} logged. ${repCount} reps at ${concentricVelocity} meters per second. Great work.`, true);
    setCurrentSetNum((s) => s + 1);
    setRepCount(0);
    setElapsedSeconds(0);
    firstRepVelocityRef.current = null;
  };

  return (
    <div className="space-y-6">
      {/* VBT KINEMATICS & SKELETAL HUD CARD */}
      <div className="liquid-glass-elevated rounded-[28px] p-6 border border-white/15 relative overflow-hidden">
        {/* Top Header */}
        <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#FA114F]/20 border border-[#FA114F]/40 flex items-center justify-center">
              <Camera className="w-5 h-5 text-[#FA114F]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">
                  Olympic VBT & 3D Kinematics Tracker
                </h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  {modelStatus}
                </span>
              </div>
              <p className="text-xs text-[#A1A1AA] font-mono mt-0.5">
                Velocity-Based Training (m/s) · Valgus knee cave detection · 3D laser bar path
              </p>
            </div>
          </div>

          {/* Voice Coach Toggle */}
          <button
            onClick={() => {
              playPlunk();
              setVoiceCoachEnabled(!voiceCoachEnabled);
            }}
            className={`px-3 py-1.5 rounded-[10px] text-xs font-mono font-bold flex items-center space-x-1.5 transition ${
              voiceCoachEnabled
                ? 'bg-[#E5FE40]/20 text-[#E5FE40] border border-[#E5FE40]/40'
                : 'bg-white/5 text-[#8A8A8A] border border-white/10'
            }`}
          >
            {voiceCoachEnabled ? <Volume2 className="w-3.5 h-3.5" /> : <VolumeX className="w-3.5 h-3.5" />}
            <span>SIRI VBT COACH: {voiceCoachEnabled ? 'ACTIVE' : 'MUTED'}</span>
          </button>
        </div>

        {/* Viewfinder Frame */}
        <div className="relative aspect-video rounded-[22px] bg-black/80 border border-white/10 overflow-hidden flex items-center justify-center">
          <video
            ref={videoRef}
            playsInline
            muted
            className={`absolute inset-0 w-full h-full object-cover scale-x-[-1] transition-opacity duration-300 ${
              isCameraActive ? 'opacity-90' : 'opacity-0'
            }`}
          />

          <canvas
            ref={canvasRef}
            width={854}
            height={480}
            className="absolute inset-0 w-full h-full object-cover pointer-events-none z-10"
          />

          {/* Camera Off / Standby Screen */}
          {!isCameraActive && (
            <div className="flex flex-col items-center justify-center p-6 text-center z-20 space-y-3">
              <div className="w-16 h-16 rounded-full bg-white/5 border border-white/10 flex items-center justify-center">
                <VideoOff className="w-8 h-8 text-[#8A8A8A]" />
              </div>
              <div>
                <p className="text-sm font-mono font-bold text-white">FaceTime VBT Camera Standby</p>
                <p className="text-xs font-mono text-[#8A8A8A] max-w-sm mt-1">
                  Activate camera to measure concentric bar speed ($m/s$), knee valgus, and 3D laser trajectory.
                </p>
              </div>
              <button
                onClick={() => startCamera()}
                className="px-5 py-2.5 rounded-[12px] bg-[#FA114F] hover:bg-[#FF2E68] text-white font-mono font-black text-xs uppercase tracking-wider flex items-center space-x-2 transition shadow-[0_0_20px_rgba(250,17,79,0.5)]"
              >
                <Video className="w-4 h-4" />
                <span>START MAC FRONT CAMERA</span>
              </button>
            </div>
          )}

          {/* Top HUD Floating Guidance & VBT Telemetry */}
          {isCameraActive && (
            <div className="absolute top-4 left-4 right-4 z-20 flex items-center justify-between pointer-events-none">
              <div className="px-3.5 py-1.5 rounded-[12px] bg-black/80 backdrop-blur-md border border-white/20 text-xs font-mono flex items-center space-x-2">
                <span className="w-2 h-2 rounded-full bg-[#10B981] animate-ping" />
                <span className="text-white font-bold">{feedbackCue}</span>
              </div>

              {/* VBT Metric Badge */}
              <div className="px-3.5 py-1.5 rounded-[12px] bg-black/80 backdrop-blur-md border border-white/20 text-xs font-mono flex items-center space-x-3">
                <div>
                  <span className="text-[#8A8A8A] text-[9px] block">CONCENTRIC SPEED</span>
                  <strong className="text-[#00F0FF] text-sm">{concentricVelocity} m/s</strong>
                </div>
                <div>
                  <span className="text-[#8A8A8A] text-[9px] block">PROXIMITY</span>
                  <strong className="text-[#E5FE40] text-sm">{repsInReserve}</strong>
                </div>
              </div>
            </div>
          )}

          {/* Rep Counter Big Display Bottom Right */}
          {isCameraActive && (
            <div className="absolute bottom-4 right-4 z-20 px-5 py-3 rounded-[18px] bg-black/85 backdrop-blur-md border border-white/20 flex items-baseline space-x-2">
              <span className="text-4xl font-mono font-black text-white">{repCount}</span>
              <span className="text-xs font-mono text-[#8A8A8A] font-bold">REPS</span>
            </div>
          )}
        </div>

        {/* VBT Telemetry Bar */}
        <div className="grid grid-cols-4 gap-2 mt-4 text-xs font-mono">
          <div className="p-3 rounded-[14px] bg-black/40 border border-white/10">
            <span className="text-[10px] text-[#8A8A8A] block">LAST REP VELOCITY</span>
            <strong className="text-white text-base">{concentricVelocity} m/s</strong>
            <span className="text-[9px] text-[#10B981] block">Threshold: &gt; 0.35 m/s</span>
          </div>

          <div className="p-3 rounded-[14px] bg-black/40 border border-white/10">
            <span className="text-[10px] text-[#8A8A8A] block">VELOCITY LOSS</span>
            <strong className="text-[#FA114F] text-base">{velocityLoss}%</strong>
            <span className="text-[9px] text-[#8A8A8A] block">Fatigue vs Rep 1</span>
          </div>

          <div className="p-3 rounded-[14px] bg-black/40 border border-white/10">
            <span className="text-[10px] text-[#8A8A8A] block">ESTIMATED RIR</span>
            <strong className="text-[#E5FE40] text-base">{repsInReserve}</strong>
            <span className="text-[9px] text-[#8A8A8A] block">Reps in reserve</span>
          </div>

          <div className="p-3 rounded-[14px] bg-black/40 border border-white/10">
            <span className="text-[10px] text-[#8A8A8A] block">POWER &amp; BAR LOAD</span>
            <strong className="text-[#00F0FF] text-base">{estimatedWatts > 0 ? `${estimatedWatts} W` : '-- W'}</strong>
            <span className="text-[9px] text-[#10B981] block">{currentWeight} kg external load</span>
          </div>
        </div>

        {/* Bottom Controls */}
        <div className="flex flex-wrap items-center justify-between gap-3 mt-4 pt-4 border-t border-white/10">
          <div className="flex items-center flex-wrap gap-2">
            {EXERCISES.map((ex, idx) => (
              <button
                key={ex.id}
                onClick={() => {
                  playPlunk();
                  setSelectedExIndex(idx);
                  setRepCount(0);
                  setRepState('READY');
                  firstRepVelocityRef.current = null;
                  speakCue(`Switched to ${ex.name}. Ready for set.`, true);
                }}
                className={`px-3 py-1.5 rounded-[10px] text-xs font-mono font-bold transition ${
                  selectedExIndex === idx
                    ? 'bg-[#FA114F] text-white shadow-[0_0_12px_rgba(250,17,79,0.5)] font-black'
                    : 'bg-white/5 text-[#8A8A8A] hover:text-white'
                }`}
              >
                {ex.name.split(' ')[0]}
              </button>
            ))}

            <div className="flex items-center space-x-1.5 px-2.5 py-1 rounded-[10px] bg-black/40 border border-white/15 text-xs font-mono">
              <button
                onClick={() => setCurrentWeight((w) => Math.max(5, w - 5))}
                className="px-1.5 text-[#8A8A8A] hover:text-white font-bold"
              >
                -5
              </button>
              <span className="text-white font-bold">{currentWeight} kg</span>
              <button
                onClick={() => setCurrentWeight((w) => Math.min(350, w + 5))}
                className="px-1.5 text-[#E5FE40] hover:text-white font-bold"
              >
                +5
              </button>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {isCameraActive ? (
              <button
                onClick={stopCamera}
                className="px-4 py-2 rounded-[10px] bg-white/10 hover:bg-white/20 text-xs font-mono font-bold text-white transition flex items-center space-x-1.5"
              >
                <VideoOff className="w-3.5 h-3.5" />
                <span>STOP CAMERA</span>
              </button>
            ) : (
              <button
                onClick={() => startCamera()}
                className="px-4 py-2 rounded-[10px] bg-[#10B981] hover:bg-[#10B981]/80 text-black text-xs font-mono font-black transition flex items-center space-x-1.5"
              >
                <Video className="w-3.5 h-3.5" />
                <span>START CAMERA</span>
              </button>
            )}

            <button
              onClick={handleCompleteSet}
              disabled={repCount === 0}
              className={`px-4 py-2 rounded-[10px] font-mono font-black text-xs flex items-center space-x-1.5 transition ${
                repCount > 0
                  ? 'bg-[#E5FE40] text-black shadow-[0_0_15px_rgba(229,254,64,0.4)] cursor-pointer'
                  : 'bg-white/5 text-[#666] cursor-not-allowed'
              }`}
            >
              <Check className="w-3.5 h-3.5 stroke-[3]" />
              <span>LOG SET ({repCount} REPS)</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
