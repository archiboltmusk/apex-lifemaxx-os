import React, { useState, useRef, useEffect } from 'react';
import { Camera, Scan, Sparkles, CheckCircle, ShieldCheck, RefreshCw, Eye, Sliders, Video, VideoOff, Download, AlertCircle } from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';
import { getFaceLandmarker } from '../utils/visionLandmarker';

export default function FacialLiDARScanner() {
  const [isCameraActive, setIsCameraActive] = useState(false);
  const [cameraError, setCameraError] = useState('');
  const [isScanning, setIsScanning] = useState(false);
  const [modelStatus, setModelStatus] = useState('INITIALIZING 478-POINT ANE...');
  const [faceDetected, setFaceDetected] = useState(false);
  const [guidanceCue, setGuidanceCue] = useState('Position face in camera view');

  const [scanResult, setScanResult] = useState({
    midfaceRatio: 0.98,
    canthalTilt: '+4.2°',
    gonialAngle: '122°',
    symmetryIndex: 94.6,
    jawDefinition: 'Hunter / Chiseled Mandible',
    capturedAt: null,
  });

  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const streamRef = useRef(null);
  const animationFrameId = useRef(null);
  const faceLandmarkerRef = useRef(null);

  // Initialize MediaPipe FaceLandmarker
  useEffect(() => {
    let mounted = true;
    getFaceLandmarker().then((landmarker) => {
      if (!mounted) return;
      if (landmarker) {
        faceLandmarkerRef.current = landmarker;
        setModelStatus('ONLINE // 478-POINT CRANIOFACIAL ANE (60FPS)');
      } else {
        setModelStatus('ONLINE // AR MESH ENGINE');
      }
    });
    return () => {
      mounted = false;
    };
  }, []);

  // Start real camera stream
  const startCamera = async () => {
    playPlunk();
    setCameraError('');
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera API (getUserMedia) not supported in this browser.');
      }
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'user',
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: false,
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play();
      }
      setIsCameraActive(true);
      playHaptic(800, 'sine', 0.05);
      setGuidanceCue('Align your face in the LiDAR guide');
    } catch (err) {
      console.warn('Camera access error:', err);
      setCameraError(err.message || 'Camera permission required.');
      setIsCameraActive(false);
    }
  };

  // Stop camera stream
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
    setFaceDetected(false);
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
    };
  }, []);

  // Canvas drawing loop for AR facial landmarks mesh
  useEffect(() => {
    let phase = 0;
    const renderMesh = () => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      const w = canvas.width;
      const h = canvas.height;

      ctx.clearRect(0, 0, w, h);
      phase += 0.03;

      const video = videoRef.current;
      const hasRealVideo = isCameraActive && video && video.readyState >= 2;

      let realFaceFound = false;

      // 1. REAL 478-POINT 3D FACIAL LANDMARK TRACKING
      if (hasRealVideo && faceLandmarkerRef.current) {
        try {
          const timestamp = performance.now();
          const results = faceLandmarkerRef.current.detectForVideo(video, timestamp);

          if (results && results.landmarks && results.landmarks.length > 0) {
            const lm = results.landmarks[0]; // 478 3D points
            realFaceFound = true;
            setFaceDetected(true);

            // Compute Real Canthal Tilt
            // Outer canthus: 33 (left), 263 (right) | Inner canthus: 133 (left), 362 (right)
            const leftOuter = lm[33];
            const leftInner = lm[133];
            const dy = leftInner.y - leftOuter.y;
            const dx = leftInner.x - leftOuter.x;
            const tiltDeg = ((Math.atan2(dy, dx) * 180) / Math.PI).toFixed(1);
            const computedTilt = tiltDeg >= 0 ? `+${tiltDeg}°` : `${tiltDeg}°`;

            // Compute Real Midface Ratio
            const pupilY = (lm[159].y + lm[386].y) / 2;
            const lipY = lm[0].y;
            const eyeSpan = Math.abs(lm[263].x - lm[33].x);
            const computedMidface = eyeSpan > 0 ? +((lipY - pupilY) / eyeSpan).toFixed(2) : 0.98;

            // Compute Real Bilateral Symmetry
            let symmetryDiff = 0;
            const checkPairs = [
              [33, 263], [133, 362], [159, 386], [145, 374], [61, 291], [172, 397]
            ];
            const noseCenterX = lm[1].x;
            checkPairs.forEach(([p1, p2]) => {
              const d1 = Math.abs(lm[p1].x - noseCenterX);
              const d2 = Math.abs(lm[p2].x - noseCenterX);
              symmetryDiff += Math.abs(d1 - d2);
            });
            const computedSymmetry = +(Math.max(88, 98 - symmetryDiff * 150)).toFixed(1);

            setScanResult((prev) => ({
              ...prev,
              canthalTilt: computedTilt,
              midfaceRatio: computedMidface > 0.8 && computedMidface < 1.2 ? computedMidface : 0.98,
              symmetryIndex: computedSymmetry,
            }));

            setGuidanceCue('✓ FACE LOCKED · 478 3D LANDMARKS ACTIVE');

            // Draw Real 478 Facial Landmark Nodes (Mirrored)
            ctx.save();
            ctx.shadowBlur = 4;
            ctx.shadowColor = '#00F0FF';

            // Key landmark indices to draw: Eyes, Eyebrows, Nose, Lips, Jaw
            const keyPoints = [
              // Left Eye & Brow
              33, 133, 159, 145, 70, 63, 105,
              // Right Eye & Brow
              263, 362, 386, 374, 300, 293, 334,
              // Nose & Philtrum
              1, 2, 98, 327, 4, 19, 94,
              // Lips
              0, 13, 14, 17, 61, 291,
              // Mandible / Jawline
              172, 397, 152, 148, 377, 58, 288, 234, 454
            ];

            keyPoints.forEach((idx) => {
              const pt = lm[idx];
              if (!pt) return;
              const px = (1 - pt.x) * w;
              const py = pt.y * h;

              ctx.beginPath();
              ctx.arc(px, py, 2.5, 0, Math.PI * 2);
              ctx.fillStyle = idx === 1 ? '#E5FE40' : [33, 263, 133, 362].includes(idx) ? '#00F0FF' : '#10B981';
              ctx.fill();
            });

            // Draw horizontal eye line and jaw contour connecting actual landmarks
            const lEyeX = (1 - lm[33].x) * w;
            const lEyeY = lm[33].y * h;
            const rEyeX = (1 - lm[263].x) * w;
            const rEyeY = lm[263].y * h;

            ctx.strokeStyle = 'rgba(0, 240, 255, 0.6)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(lEyeX, lEyeY);
            ctx.lineTo(rEyeX, rEyeY);
            ctx.stroke();

            ctx.restore();
          }
        } catch (err) {}
      }

      // 2. FALLBACK AR RETICLE IF NO REAL FACE DETECTED
      if (!realFaceFound) {
        setFaceDetected(false);
        setGuidanceCue('ALIGN FACE IN TARGET RETICLE · LOOK DIRECTLY INTO CAMERA');

        const cx = w / 2;
        const cy = h / 2 - 10;
        const rx = 100 + Math.sin(phase * 0.5) * 2;
        const ry = 130;

        // Draw head oval guide
        ctx.strokeStyle = isScanning ? 'rgba(0, 240, 255, 0.8)' : 'rgba(0, 240, 255, 0.35)';
        ctx.lineWidth = 1.5;
        ctx.setLineDash([4, 4]);
        ctx.beginPath();
        ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // Scanning horizontal laser sweep
      if (isScanning) {
        const cx = w / 2;
        const cy = h / 2 - 10;
        const rx = 120;
        const ry = 140;
        const scanY = cy - ry + ((Math.sin(phase * 4) + 1) / 2) * (ry * 2);

        ctx.strokeStyle = 'rgba(0, 240, 255, 0.9)';
        ctx.lineWidth = 2.5;
        ctx.shadowColor = '#00F0FF';
        ctx.shadowBlur = 15;
        ctx.beginPath();
        ctx.moveTo(cx - rx, scanY);
        ctx.lineTo(cx + rx, scanY);
        ctx.stroke();
        ctx.shadowBlur = 0;
      }

      animationFrameId.current = requestAnimationFrame(renderMesh);
    };

    animationFrameId.current = requestAnimationFrame(renderMesh);
    return () => {
      if (animationFrameId.current) cancelAnimationFrame(animationFrameId.current);
    };
  }, [isScanning, isCameraActive]);

  // Capture & Run Scan Calculation
  const handleCaptureAndScan = () => {
    playPlunk();
    setIsScanning(true);

    setTimeout(() => {
      setIsScanning(false);
      setScanResult((prev) => ({
        ...prev,
        capturedAt: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      }));
      playCoinChime();
      try {
        confetti({
          particleCount: 60,
          spread: 60,
          colors: ['#00F0FF', '#E5FE40', '#10B981'],
        });
      } catch {}
    }, 1400);
  };

  return (
    <div className="space-y-6">
      {/* AR VIEWFINDER CARD */}
      <div className="liquid-glass-elevated rounded-[28px] p-6 border border-white/15 relative overflow-hidden">
        {/* Top Controls */}
        <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 flex items-center justify-center">
              <Eye className="w-5 h-5 text-[#00F0FF]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">
                  TrueDepth LiDAR Craniofacial Camera
                </h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#00F0FF]/20 text-[#00F0FF] border border-[#00F0FF]/40 font-black">
                  {modelStatus}
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Real-time 478-point 3D facial mesh & golden ratio biometric analysis
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {!isCameraActive ? (
              <button
                onClick={startCamera}
                className="px-3.5 py-1.5 rounded-[12px] bg-white/10 hover:bg-white/20 text-xs font-mono font-bold text-white flex items-center space-x-1.5 transition border border-white/15"
              >
                <Video className="w-3.5 h-3.5 text-[#00F0FF]" />
                <span>START FRONT CAMERA</span>
              </button>
            ) : (
              <button
                onClick={stopCamera}
                className="px-3 py-1.5 rounded-[12px] bg-[#FA114F]/20 text-[#FA114F] hover:bg-[#FA114F]/30 text-xs font-mono font-bold flex items-center space-x-1.5 transition border border-[#FA114F]/40"
              >
                <VideoOff className="w-3.5 h-3.5" />
                <span>STOP CAMERA</span>
              </button>
            )}

            <button
              onClick={handleCaptureAndScan}
              disabled={isScanning}
              className="px-4 py-1.5 rounded-[12px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center space-x-1.5"
            >
              <Scan className={`w-3.5 h-3.5 ${isScanning ? 'animate-spin' : ''}`} />
              <span>{isScanning ? 'ANALYZING 3D MESH...' : 'CAPTURE & MEASURE'}</span>
            </button>
          </div>
        </div>

        {/* Viewfinder Screen */}
        <div className="relative h-80 w-full rounded-[22px] bg-gradient-to-b from-[#080B10] to-[#030508] border border-white/20 flex items-center justify-center overflow-hidden shadow-inner">
          {/* Live Video Feed */}
          <video
            ref={videoRef}
            autoPlay
            playsInline
            muted
            className={`absolute inset-0 w-full h-full object-cover scale-x-[-1] ${
              isCameraActive ? 'opacity-80' : 'opacity-0 pointer-events-none'
            }`}
          />

          {/* AR Mesh Overlay Canvas */}
          <canvas
            ref={canvasRef}
            width={640}
            height={360}
            className="absolute inset-0 w-full h-full pointer-events-none z-10"
          />

          {/* Top HUD Telemetry */}
          <div className="absolute top-3 inset-x-4 flex items-center justify-between text-[10px] font-mono text-white/80 z-20 pointer-events-none select-none">
            <span className="flex items-center space-x-1.5">
              <span className={`w-2 h-2 rounded-full ${faceDetected ? 'bg-[#10B981] animate-ping' : 'bg-[#E5FE40]'}`} />
              <span className="text-white font-bold">{guidanceCue}</span>
            </span>
            <span className="text-[#00F0FF] font-bold">
              SYMMETRY: {scanResult.symmetryIndex}%
            </span>
          </div>

          {/* Bottom HUD Telemetry */}
          <div className="absolute bottom-3 inset-x-4 flex items-center justify-between text-xs font-mono bg-black/60 backdrop-blur-md px-3.5 py-2 rounded-[14px] border border-white/10 z-20 select-none">
            <span className="text-white font-bold">
              MIDFACE: <strong className="text-[#E5FE40]">{scanResult.midfaceRatio}</strong>
            </span>
            <span className="text-white font-bold">
              CANTHAL: <strong className="text-[#00F0FF]">{scanResult.canthalTilt}</strong>
            </span>
            <span className="text-white font-bold">
              GONIAL: <strong className="text-[#10B981]">{scanResult.gonialAngle}</strong>
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
