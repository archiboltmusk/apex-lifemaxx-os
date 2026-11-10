import React, { useState } from 'react';
import {
  X,
  ShieldCheck,
  RefreshCw,
  CheckCircle,
  Smartphone,
  Watch,
  Heart,
  Flame,
  Plus,
  Sliders,
  Check,
  TrendingUp,
  Droplets,
  Clock
} from 'lucide-react';
import { playPlunk, playHealthSyncChime, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function AppleHealthModal({ isOpen, onClose, onSyncComplete, healthData, onAddHealthData }) {
  const [activeModalTab, setActiveModalTab] = useState('add'); // 'add' | 'sync' | 'permissions'
  const [isSyncing, setIsSyncing] = useState(false);
  const [syncProgress, setSyncProgress] = useState(100);

  // Form inputs for adding Apple Health records
  const [addCalories, setAddCalories] = useState(250);
  const [addExerciseMin, setAddExerciseMin] = useState(30);
  const [addStandHours, setAddStandHours] = useState(1);
  const [addWaterMl, setAddWaterMl] = useState(500);
  const [addHRV, setAddHRV] = useState(96);
  const [addRHR, setAddRHR] = useState(48);

  // Permission toggles
  const [permissions, setPermissions] = useState({
    activeEnergy: true,
    exerciseTime: true,
    standHours: true,
    heartRate: true,
    hrv: true,
    sleepAnalysis: true,
    vo2max: true,
  });

  if (!isOpen) return null;

  const togglePermission = (key) => {
    playPlunk();
    setPermissions((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const handleSyncNow = () => {
    playPlunk();
    setIsSyncing(true);
    setSyncProgress(15);

    const intv = setInterval(() => {
      setSyncProgress((prev) => {
        if (prev >= 100) {
          clearInterval(intv);
          setIsSyncing(false);
          playHealthSyncChime();
          if (onSyncComplete) onSyncComplete();
          return 100;
        }
        return prev + 25;
      });
    }, 250);
  };

  const handleCommitSample = () => {
    playPlunk();
    playHealthSyncChime();

    if (onAddHealthData) {
      onAddHealthData({
        calories: Number(addCalories),
        exerciseMin: Number(addExerciseMin),
        standHours: Number(addStandHours),
        waterMl: Number(addWaterMl),
        hrv: Number(addHRV),
        rhr: Number(addHRR ? addHRR : addRHR),
      });
    }

    try {
      confetti({
        particleCount: 60,
        spread: 60,
        colors: ['#FA114F', '#92E82A', '#00D6E6'],
      });
    } catch {}

    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-2xl animate-fade-in">
      <div className="liquid-glass-elevated w-full max-w-lg rounded-[32px] p-6 border border-white/20 relative shadow-[0_25px_80px_rgba(0,0,0,0.95)] overflow-hidden">
        {/* Background glow */}
        <div className="absolute top-0 right-0 w-72 h-72 bg-gradient-to-br from-[#FA114F]/15 via-[#00D6E6]/10 to-transparent rounded-full blur-3xl pointer-events-none" />

        {/* Close Button */}
        <button
          onClick={() => {
            playPlunk();
            onClose();
          }}
          className="absolute top-5 right-5 w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white/80 transition"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Header */}
        <div className="flex items-center space-x-3 mb-5">
          <div className="w-12 h-12 rounded-[16px] bg-gradient-to-tr from-[#FA114F] to-[#FF5E7E] flex items-center justify-center shadow-[0_4px_16px_rgba(250,17,79,0.5)]">
            <Heart className="w-6 h-6 text-white fill-white" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h2 className="text-lg font-bold text-white tracking-tight">Apple HealthKit Hub</h2>
              <span className="text-[10px] font-mono font-black px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 flex items-center space-x-1">
                <ShieldCheck className="w-3 h-3" />
                <span>HEALTHKIT v18.2</span>
              </span>
            </div>
            <p className="text-xs text-[#A1A1AA]">
              Direct bidirectional sync with Apple Watch Ultra & iPhone 16 Pro
            </p>
          </div>
        </div>

        {/* SUB-TABS: ADD DATA vs SYNC TELEMETRY vs PERMISSIONS */}
        <div className="p-1 rounded-[14px] bg-black/50 border border-white/10 flex items-center justify-between mb-5 text-xs font-mono">
          <button
            onClick={() => {
              playPlunk();
              setActiveModalTab('add');
            }}
            className={`flex-1 py-2 rounded-[10px] transition font-bold flex items-center justify-center space-x-1.5 ${
              activeModalTab === 'add'
                ? 'bg-[#FA114F] text-white shadow-[0_0_12px_rgba(250,17,79,0.4)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Add Health Data</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setActiveModalTab('sync');
            }}
            className={`flex-1 py-2 rounded-[10px] transition font-bold flex items-center justify-center space-x-1.5 ${
              activeModalTab === 'sync'
                ? 'bg-white/15 text-white shadow-[0_0_12px_rgba(255,255,255,0.2)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Sync Stream</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setActiveModalTab('permissions');
            }}
            className={`flex-1 py-2 rounded-[10px] transition font-bold flex items-center justify-center space-x-1.5 ${
              activeModalTab === 'permissions'
                ? 'bg-white/15 text-white shadow-[0_0_12px_rgba(255,255,255,0.2)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <Sliders className="w-3.5 h-3.5" />
            <span>Permissions</span>
          </button>
        </div>

        {/* ============================================================== */}
        {/* TAB 1: ADD HEALTHKIT SAMPLE DATA (USER-REQUESTED FEATURE)       */}
        {/* ============================================================== */}
        {activeModalTab === 'add' && (
          <div className="space-y-4">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase tracking-wider block">
              LOG NEW BIOMETRIC SAMPLE TO APPLE HEALTHKIT
            </span>

            <div className="grid grid-cols-2 gap-3">
              {/* Calories (Move) */}
              <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                <span className="text-[10px] font-mono text-[#FA114F] font-bold block">
                  MOVE ENERGY (+KCAL)
                </span>
                <input
                  type="number"
                  value={addCalories}
                  onChange={(e) => setAddCalories(e.target.value)}
                  className="w-full bg-transparent font-mono font-black text-lg text-white focus:outline-none"
                  placeholder="250"
                />
                <span className="text-[9px] font-mono text-[#8A8A8A]">Active burn ring</span>
              </div>

              {/* Exercise Minutes */}
              <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                <span className="text-[10px] font-mono text-[#92E82A] font-bold block">
                  EXERCISE (+MINUTES)
                </span>
                <input
                  type="number"
                  value={addExerciseMin}
                  onChange={(e) => setAddExerciseMin(e.target.value)}
                  className="w-full bg-transparent font-mono font-black text-lg text-white focus:outline-none"
                  placeholder="30"
                />
                <span className="text-[9px] font-mono text-[#8A8A8A]">Green exercise ring</span>
              </div>

              {/* Stand Hours */}
              <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                <span className="text-[10px] font-mono text-[#00D6E6] font-bold block">
                  STAND (+HOURS)
                </span>
                <input
                  type="number"
                  value={addStandHours}
                  onChange={(e) => setAddStandHours(e.target.value)}
                  className="w-full bg-transparent font-mono font-black text-lg text-white focus:outline-none"
                  placeholder="1"
                />
                <span className="text-[9px] font-mono text-[#8A8A8A]">Blue stand ring</span>
              </div>

              {/* Hydration */}
              <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                <span className="text-[10px] font-mono text-[#00F0FF] font-bold block">
                  HYDRATION (+ML)
                </span>
                <input
                  type="number"
                  value={addWaterMl}
                  onChange={(e) => setAddWaterMl(e.target.value)}
                  className="w-full bg-transparent font-mono font-black text-lg text-white focus:outline-none"
                  placeholder="500"
                />
                <span className="text-[9px] font-mono text-[#8A8A8A]">Water intake logged</span>
              </div>
            </div>

            <button
              onClick={handleCommitSample}
              className="w-full py-3.5 rounded-[14px] bg-gradient-to-r from-[#FA114F] to-[#FF5E7E] text-white font-mono font-black text-xs uppercase tracking-wider flex items-center justify-center space-x-2 border border-white/20 shadow-[0_0_20px_rgba(250,17,79,0.5)]"
            >
              <Check className="w-4 h-4 stroke-[3]" />
              <span>COMMIT SAMPLE TO APPLE HEALTHKIT</span>
            </button>
          </div>
        )}

        {/* ============================================================== */}
        {/* TAB 2: LIVE SYNC STREAM TELEMETRY                              */}
        {/* ============================================================== */}
        {activeModalTab === 'sync' && (
          <div className="space-y-4">
            <div className="apex-inset rounded-[16px] p-4 border border-white/10 flex items-center justify-between">
              <div>
                <span className="text-[10px] font-mono text-[#8A8A8A] uppercase">SYNC INTEGRITY</span>
                <div className="flex items-center space-x-1.5 mt-0.5">
                  <CheckCircle className="w-4 h-4 text-[#10B981]" />
                  <span className="text-xs font-mono font-bold text-white">Full Read & Write Granted</span>
                </div>
              </div>
              <button
                onClick={handleSyncNow}
                disabled={isSyncing}
                className="px-3.5 py-1.5 rounded-[10px] bg-white/10 hover:bg-white/20 text-xs font-mono font-bold text-white border border-white/15 flex items-center space-x-1.5 transition"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin text-[#00F0FF]' : ''}`} />
                <span>{isSyncing ? `${syncProgress}% SYNCING` : 'SYNC NOW'}</span>
              </button>
            </div>

            <div className="space-y-2">
              {[
                { label: 'Active Energy (Move)', val: `${healthData.activityRings.move.current} kcal / ${healthData.activityRings.move.target} target`, color: '#FA114F' },
                { label: 'High-Res Optical HR', val: `${healthData.metrics.restingHeartRate.value} bpm resting · ${healthData.metrics.hrv.value}ms HRV`, color: '#10B981' },
                { label: 'Sleep Architecture', val: `${healthData.sleepStages.totalHours} (${healthData.sleepStages.deep.time} deep sleep)`, color: '#3B82F6' },
                { label: 'Cardio Fitness', val: `${healthData.metrics.vo2Max.value} mL/kg/min (Top 1% Longevity Tier)`, color: '#00F0FF' },
              ].map((item, idx) => (
                <div key={idx} className="p-2.5 rounded-[12px] bg-white/[0.04] border border-white/5 flex items-center justify-between text-xs font-mono">
                  <span className="text-white font-medium">{item.label}</span>
                  <span className="font-bold" style={{ color: item.color }}>{item.val}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ============================================================== */}
        {/* TAB 3: HEALTHKIT AUTHORIZATION PERMISSIONS                     */}
        {/* ============================================================== */}
        {activeModalTab === 'permissions' && (
          <div className="space-y-2.5">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase tracking-wider block mb-1">
              APPLE HEALTHKIT READ & WRITE PERMISSIONS
            </span>

            {Object.entries(permissions).map(([key, enabled]) => (
              <div
                key={key}
                onClick={() => togglePermission(key)}
                className="p-3 rounded-[12px] bg-white/[0.03] border border-white/5 flex items-center justify-between cursor-pointer hover:border-white/20 transition text-xs font-mono"
              >
                <span className="text-white font-medium capitalize">
                  {key.replace(/([A-Z])/g, ' $1')}
                </span>
                <div className={`w-9 h-5 rounded-full p-0.5 transition ${enabled ? 'bg-[#10B981]' : 'bg-white/20'}`}>
                  <div className={`w-4 h-4 rounded-full bg-white transition-transform ${enabled ? 'translate-x-4' : 'translate-x-0'}`} />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
