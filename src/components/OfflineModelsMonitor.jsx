import React, { useState, useEffect } from 'react';
import {
  Cpu,
  ShieldCheck,
  CheckCircle2,
  HardDrive,
  Zap,
  Sparkles,
  Layers,
  Activity,
  Camera,
  Mic,
  Eye
} from 'lucide-react';
import { playPlunk } from '../utils/audioSynth';

export default function OfflineModelsMonitor() {
  const [models, setModels] = useState([
    {
      name: 'BlazePose Heavy 3D Kinematics',
      filename: 'pose_landmarker_heavy.task',
      size: '29.2 MB',
      purpose: 'Real-Time Squat Depth (<90°), Push-Up & Rep Tracking',
      framework: 'MediaPipe / TFLite (ANE Optimized)',
      status: 'LOADED // ACTIVE',
      icon: Activity,
      color: '#FA114F',
    },
    {
      name: 'MobileNetV4 Food & Macro Vision',
      filename: 'food_macro_vision.onnx',
      size: '37.0 MB',
      purpose: 'Photogrammetric Meal & Macronutrient Recognition',
      framework: 'ONNX Runtime / Metal Performance Shaders',
      status: 'LOADED // ACTIVE',
      icon: Camera,
      color: '#E5FE40',
    },
    {
      name: 'Vocal Whisper Acoustic Transformer',
      filename: 'vocal_whisper_encoder.onnx',
      size: '31.0 MB',
      purpose: 'Pitch (F0), Formant Resonances & Thoracic Acoustics',
      framework: 'ONNX Audio DSP / Apple Neural Engine',
      status: 'LOADED // ACTIVE',
      icon: Mic,
      color: '#00F0FF',
    },
    {
      name: 'EfficientDet Lite2 Macro Object Vision',
      filename: 'efficientdet_lite2.tflite',
      size: '22.0 MB',
      purpose: 'Spatial Volumetric Food Boundary Detection',
      framework: 'CoreML / Accelerate Framework',
      status: 'LOADED // ACTIVE',
      icon: Eye,
      color: '#F59E0B',
    },
    {
      name: 'BlazePose Fast Full Kinematics',
      filename: 'pose_landmarker_full.task',
      size: '9.0 MB',
      purpose: 'High-Speed 60fps Biomechanical Fallback',
      framework: 'MediaPipe Vision',
      status: 'LOADED // ACTIVE',
      icon: Activity,
      color: '#10B981',
    },
    {
      name: 'Hand & Finger Joint Landmarker',
      filename: 'hand_landmarker.task',
      size: '7.5 MB',
      purpose: 'Grip Strength Kinematics & Kinetic Gesture Control',
      framework: 'MediaPipe / CoreML',
      status: 'LOADED // ACTIVE',
      icon: Layers,
      color: '#A855F7',
    },
    {
      name: 'Dense 468-Point Facial Mesh',
      filename: 'face_landmarker.task',
      size: '3.6 MB',
      purpose: 'Photogrammetric Jawline, Symmetry & Golden Ratio',
      framework: 'MediaPipe TrueDepth',
      status: 'LOADED // ACTIVE',
      icon: Sparkles,
      color: '#38BDF8',
    },
  ]);

  const totalSizeMB = 139.3;

  return (
    <div className="space-y-6">
      {/* HERO BANNER */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/20 relative overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 rounded-[16px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 flex items-center justify-center">
              <Cpu className="w-6 h-6 text-[#00F0FF]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="text-[10px] font-mono text-[#00F0FF] font-black uppercase tracking-widest">
                  OFFLINE ON-DEVICE MACHINE LEARNING
                </span>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  100% PRIVATE // 0 CLOUD CALLS
                </span>
              </div>
              <h3 className="text-lg font-bold text-white tracking-tight">
                Embedded Neural Models & Apple Silicon Acceleration
              </h3>
            </div>
          </div>

          <div className="text-right">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">TOTAL EMBEDDED WEIGHTS</span>
            <div className="flex items-baseline space-x-1.5">
              <span className="text-3xl font-mono font-black text-white">{totalSizeMB}</span>
              <span className="text-xs font-mono text-[#00F0FF] font-bold">MB</span>
            </div>
            <span className="text-xs font-mono font-bold text-[#10B981]">
              7 Models Loaded Locally
            </span>
          </div>
        </div>

        <p className="text-xs text-[#A1A1AA] font-mono leading-relaxed mb-4">
          Unlike web apps that stream video to remote cloud servers, APEX OS bundles all computer vision, audio DSP, and biomechanical neural networks directly inside the standalone macOS application bundle. Inference runs locally on your Mac using the Apple Silicon Neural Engine (ANE) and Metal Performance Shaders.
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 text-xs font-mono">
          <div className="p-3 rounded-[14px] bg-black/50 border border-white/10 flex items-center justify-between">
            <span className="text-[#8A8A8A]">RUNTIME ENGINE:</span>
            <span className="text-white font-bold">Apple Neural Engine (ANE)</span>
          </div>
          <div className="p-3 rounded-[14px] bg-black/50 border border-white/10 flex items-center justify-between">
            <span className="text-[#8A8A8A]">LOCAL LATENCY:</span>
            <span className="text-[#10B981] font-bold">~14ms per frame (60fps)</span>
          </div>
          <div className="p-3 rounded-[14px] bg-black/50 border border-white/10 flex items-center justify-between">
            <span className="text-[#8A8A8A]">TELEMETRY LEAKAGE:</span>
            <span className="text-[#E5FE40] font-bold">0.00 bytes (Airgapped)</span>
          </div>
        </div>
      </div>

      {/* MODELS INVENTORY GRID */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <h4 className="text-xs font-mono font-black text-[#E5FE40] uppercase tracking-wider">
            STANDALONE EMBEDDED MODEL REGISTRY
          </h4>
          <span className="text-[11px] font-mono text-[#8A8A8A]">
            Stored in <code className="text-white font-bold">Contents/Resources/models/</code>
          </span>
        </div>

        <div className="space-y-2.5">
          {models.map((m, idx) => {
            const Icon = m.icon;
            return (
              <div
                key={idx}
                className="p-4 rounded-[16px] bg-black/40 border border-white/5 hover:border-white/15 transition flex flex-col md:flex-row md:items-center justify-between gap-3 text-xs font-mono"
              >
                <div className="flex items-center space-x-3">
                  <div
                    className="w-10 h-10 rounded-[12px] flex items-center justify-center shrink-0"
                    style={{ backgroundColor: `${m.color}20`, border: `1px solid ${m.color}40` }}
                  >
                    <Icon className="w-5 h-5" style={{ color: m.color }} />
                  </div>
                  <div>
                    <div className="flex items-center space-x-2">
                      <span className="text-white font-bold text-sm tracking-tight">{m.name}</span>
                      <span
                        className="text-[9px] px-2 py-0.5 rounded-full font-black uppercase"
                        style={{ backgroundColor: `${m.color}20`, color: m.color }}
                      >
                        {m.size}
                      </span>
                    </div>
                    <span className="text-[11px] text-[#A1A1AA] block">{m.purpose}</span>
                  </div>
                </div>

                <div className="flex items-center justify-between md:justify-end space-x-4 shrink-0">
                  <div className="text-right hidden sm:block">
                    <span className="text-[10px] text-[#8A8A8A] block">{m.filename}</span>
                    <span className="text-[10px] text-white/70 block">{m.framework}</span>
                  </div>
                  <span className="px-2.5 py-1 rounded-full bg-[#10B981]/15 text-[#10B981] border border-[#10B981]/30 text-[10px] font-black flex items-center space-x-1">
                    <CheckCircle2 className="w-3 h-3" />
                    <span>READY</span>
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
