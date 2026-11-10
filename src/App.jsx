import React, { useState, useEffect } from 'react';
import {
  Sparkles,
  Activity,
  Brain,
  TrendingUp,
  Moon,
  Shield,
  Check,
  Zap,
  Flame,
  Clock,
  Play,
  Pause,
  RotateCcw,
  Volume2,
  VolumeX,
  Target,
  Award,
  ChevronRight,
  ArrowUpRight,
  Heart,
  Sun,
  ShieldCheck,
  Wind,
  Layers,
  Compass,
  Plus,
  Smartphone,
  Monitor,
  Watch,
  Disc,
  Trophy,
  Droplets,
  Pill,
  RefreshCw,
  Gift,
  Dumbbell,
  Camera,
  MapPin,
  Eye,
  Sliders,
  Plane,
  Lock,
  Waves,
  Mic,
  FileText,
  Crown,
  User,
  Bot,
  Snowflake,
  CreditCard
} from 'lucide-react';
import confetti from 'canvas-confetti';
import {
  INITIAL_PILLARS,
  DAILY_PROTOCOLS,
  BIOMARKER_DATA,
  LOOKSMAXXING_METRICS,
  MASTER_BLUEPRINTS,
  APPLE_HEALTH_DATA,
  RECOVERY_STRAIN_DATA
} from './utils/lifemaxxData';
import {
  playPlunk,
  playCoinChime,
  playHealthSyncChime,
  playHaptic,
  toggleBinaural
} from './utils/audioSynth';
import ActivityRings from './components/ActivityRings';
import WheelOfMaxxing from './components/WheelOfMaxxing';
import AppleHealthModal from './components/AppleHealthModal';
import DynamicIsland from './components/DynamicIsland';
import HardwareGarage from './components/HardwareGarage';
import RecoveryStrainView from './components/RecoveryStrainView';
import NutritionView from './components/NutritionView';
import WorkoutLogger from './components/WorkoutLogger';
import StravaActivityHub from './components/StravaActivityHub';
import BreathworkCoach from './components/BreathworkCoach';
import MealScanner from './components/MealScanner';
import HabitCorrelations from './components/HabitCorrelations';
import PhenoAgeCalculator from './components/PhenoAgeCalculator';
import FacialLiDARScanner from './components/FacialLiDARScanner';
import NeuralSoundEngine from './components/NeuralSoundEngine';
import BurnVaultStaking from './components/BurnVaultStaking';
import GlucoseCircadianHub from './components/GlucoseCircadianHub';
import IOS18WidgetsShowcase from './components/IOS18WidgetsShowcase';
import CentenarianDecathlon from './components/CentenarianDecathlon';
import MuscleRecoveryMap from './components/MuscleRecoveryMap';
import BloodworkScanner from './components/BloodworkScanner';
import DopamineDetoxMeter from './components/DopamineDetoxMeter';
import VocalResonanceAnalyzer from './components/VocalResonanceAnalyzer';
import CameraWorkoutTracker from './components/CameraWorkoutTracker';
import AccountTesterModal from './components/AccountTesterModal';
import AIConsigliere from './components/AIConsigliere';
import ThermalSuite from './components/ThermalSuite';
import OfflineModelsMonitor from './components/OfflineModelsMonitor';

export default function App() {
  // Navigation & View mode
  const [activeTab, setActiveTab] = useState('hub'); // 'hub' | 'fitness' | 'looks' | 'bio' | 'brain' | 'nutrition' | 'garage'
  const [fitnessSubTab, setFitnessSubTab] = useState('camera'); // 'camera' | 'recovery' | 'thermal' | 'decathlon' | 'muscles' | 'workout' | 'strava' | 'cgm' | 'breathwork' | 'habits'
  const [looksSubTab, setLooksSubTab] = useState('mewing'); // 'mewing' | 'lidar' | 'voice'
  const [bioSubTab, setBioSubTab] = useState('overview'); // 'overview' | 'consigliere' | 'phenoage' | 'ocr'
  const [brainSubTab, setBrainSubTab] = useState('sprint'); // 'sprint' | 'soundengine' | 'dopamine'
  const [nutritionSubTab, setNutritionSubTab] = useState('macros'); // 'macros' | 'scanner'
  const [garageSubTab, setGarageSubTab] = useState('hardware'); // 'hardware' | 'burnvault' | 'ios18'

  const [isMobileFrame, setIsMobileFrame] = useState(false);
  const [isHealthModalOpen, setIsHealthModalOpen] = useState(false);
  const [isAccountTesterOpen, setIsAccountTesterOpen] = useState(false);

  // Apple Health Live State
  const [appleHealthState, setAppleHealthState] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_health_data');
      return saved ? JSON.parse(saved) : APPLE_HEALTH_DATA;
    } catch {
      return APPLE_HEALTH_DATA;
    }
  });

  const handleAddHealthData = (sample) => {
    setAppleHealthState((prev) => {
      const isAbs = sample.setAbsolute;
      const newMove = isAbs ? (sample.calories ?? prev.activityRings.move.current) : prev.activityRings.move.current + (sample.calories || 0);
      const newEx = isAbs ? (sample.exerciseMin ?? prev.activityRings.exercise.current) : prev.activityRings.exercise.current + (sample.exerciseMin || 0);
      const newStand = isAbs ? (sample.standHours ?? prev.activityRings.stand.current) : prev.activityRings.stand.current + (sample.standHours || 0);

      const updated = {
        ...prev,
        deviceSource: sample.source || prev.deviceSource,
        lastSynced: 'Just now',
        activityRings: {
          move: {
            ...prev.activityRings.move,
            current: Math.round(newMove),
            percentage: Math.round((newMove / prev.activityRings.move.target) * 100),
          },
          exercise: {
            ...prev.activityRings.exercise,
            current: Math.round(newEx),
            percentage: Math.round((newEx / prev.activityRings.exercise.target) * 100),
          },
          stand: {
            ...prev.activityRings.stand,
            current: Math.round(newStand),
            percentage: Math.round((newStand / prev.activityRings.stand.target) * 100),
          },
        },
        metrics: {
          ...prev.metrics,
          hrv: { ...prev.metrics.hrv, value: sample.hrv || prev.metrics.hrv.value },
          restingHeartRate: {
            ...prev.metrics.restingHeartRate,
            value: sample.rhr || prev.metrics.restingHeartRate.value,
          },
          vo2Max: {
            ...prev.metrics.vo2Max,
            value: sample.vo2Max || prev.metrics.vo2Max.value,
          },
        },
        sleepStages: {
          ...prev.sleepStages,
          totalHours: sample.sleepHours ? `${sample.sleepHours}h` : prev.sleepStages.totalHours,
          deep: {
            ...prev.sleepStages.deep,
            time: sample.deepSleepHours ? `${sample.deepSleepHours}h` : prev.sleepStages.deep.time,
          },
        },
      };
      try {
        localStorage.setItem('apex_health_data', JSON.stringify(updated));
      } catch {}
      return updated;
    });

    if (sample.setAbsolute) {
      showToast(`Apple HealthKit Calibrated · ${sample.source || 'Verified Data'}`);
    } else {
      showToast(`Committed +${sample.calories || 0} kcal & +${sample.exerciseMin || 0}m to Apple HealthKit`);
    }
  };

  // Global Real-Time Listener for HealthKit Packets from Swift Native Server
  useEffect(() => {
    const handleGlobalHealthKitPacket = (e) => {
      const payload = e.detail;
      if (!payload) return;
      playHealthSyncChime();
      handleAddHealthData({
        calories: payload.move || payload.calories,
        exerciseMin: payload.exercise || payload.exerciseMin,
        standHours: payload.stand || payload.standHours,
        hrv: payload.hrv,
        rhr: payload.hr || payload.rhr,
        vo2Max: payload.vo2 || payload.vo2Max,
        source: payload.source || 'Apple Watch Ultra (Real-Time Ingest)',
        setAbsolute: payload.setAbsolute || false,
      });
    };

    window.addEventListener('appleHealthSync', handleGlobalHealthKitPacket);
    return () => {
      window.removeEventListener('appleHealthSync', handleGlobalHealthKitPacket);
    };
  }, []);

  // Global Cross-Component Navigation Listener
  useEffect(() => {
    const handleNavEvent = (e) => {
      const detail = e.detail;
      if (!detail) return;
      if (detail.tab) setActiveTab(detail.tab);
      if (detail.subTab) {
        if (detail.tab === 'fitness') setFitnessSubTab(detail.subTab);
        else if (detail.tab === 'looks') setLooksSubTab(detail.subTab);
        else if (detail.tab === 'bio') setBioSubTab(detail.subTab);
        else if (detail.tab === 'brain') setBrainSubTab(detail.subTab);
        else if (detail.tab === 'nutrition') setNutritionSubTab(detail.subTab);
        else if (detail.tab === 'garage') setGarageSubTab(detail.subTab);
      }
    };
    window.addEventListener('apex:navigate-tab', handleNavEvent);
    return () => window.removeEventListener('apex:navigate-tab', handleNavEvent);
  }, []);

  // Real User Account Profile & Membership
  const [membershipPlan, setMembershipPlan] = useState('lifetime');
  const [userProfile, setUserProfile] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_user_profile');
      if (saved) return JSON.parse(saved);
    } catch {}
    const defaultName = (typeof window !== 'undefined' && window.__macDeviceTelemetry?.userName) || 'Anupam Mahato';
    const defaultLogin = (typeof window !== 'undefined' && window.__macDeviceTelemetry?.userLogin) || 'anupam';
    return {
      name: defaultName,
      handle: `@${defaultLogin}`,
      tier: 'SOVEREIGN FOUNDER (LIFETIME ACCESS)',
      badge: '👑 VERIFIED MAC USER',
      appleId: `${defaultLogin}@icloud.com`,
      status: 'VERIFIED LOCAL HOST',
      device: 'MacBook Air (Apple M5 · 16 GB)',
    };
  });

  // Economy & Streaks
  const [coins, setCoins] = useState(10000);
  const [streakDays, setStreakDays] = useState(42);
  const [protocols, setProtocols] = useState(DAILY_PROTOCOLS);
  const [toastMessage, setToastMessage] = useState('');

  // 40Hz Gamma Flow State
  const [isGammaPlaying, setIsGammaPlaying] = useState(false);
  const [flowMinutes, setFlowMinutes] = useState(25);
  const [flowSeconds, setFlowSeconds] = useState(0);
  const [isFlowActive, setIsFlowActive] = useState(false);

  // Mewing Timer State
  const [mewingSeconds, setMewingSeconds] = useState(0);
  const [isMewingActive, setIsMewingActive] = useState(false);

  // Dual N-Back Memory Game
  const [nBackPosition, setNBackPosition] = useState(null);
  const [nBackLetter, setNBackLetter] = useState('');
  const [nBackScore, setNBackScore] = useState(0);
  const [nBackHistory, setNBackHistory] = useState([]);

  // Toast trigger
  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(''), 2600);
  };

  // Toggle protocol check
  const toggleProtocol = (id) => {
    playPlunk();
    setProtocols((prev) =>
      prev.map((p) => {
        if (p.id === id) {
          const updated = !p.completed;
          if (updated) {
            playCoinChime();
            setCoins((c) => c + p.xp);
            try {
              confetti({
                particleCount: 60,
                spread: 60,
                origin: { y: 0.7 },
                colors: ['#E5FE40', '#00F0FF', '#FA114F', '#10B981'],
              });
            } catch {}
            showToast(`+${p.xp} APEX Coins: ${p.title}`);
          }
          return { ...p, completed: updated };
        }
        return p;
      })
    );
  };

  // Complete all protocols (Tester shortcut)
  const completeAllProtocols = () => {
    playCoinChime();
    setProtocols((prev) => prev.map((p) => ({ ...p, completed: true })));
    setCoins((c) => c + 1500);
    showToast('All Daily Protocols Completed (+1,500 Coins)');
  };

  // Flow State Timer Interval
  useEffect(() => {
    let interval = null;
    if (isFlowActive) {
      interval = setInterval(() => {
        if (flowSeconds > 0) {
          setFlowSeconds((s) => s - 1);
        } else if (flowMinutes > 0) {
          setFlowMinutes((m) => m - 1);
          setFlowSeconds(59);
        } else {
          setIsFlowActive(false);
          setIsGammaPlaying(false);
          toggleBinaural('gamma', false);
          playCoinChime();
          setCoins((c) => c + 200);
          try {
            confetti({
              particleCount: 120,
              spread: 80,
              origin: { y: 0.6 },
              colors: ['#8B5CF6', '#00F0FF', '#E5FE40'],
            });
          } catch {}
          showToast('Deep Flow Block Complete (+200 APEX Coins)');
        }
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isFlowActive, flowMinutes, flowSeconds]);

  // Mewing Timer Interval
  useEffect(() => {
    let interval = null;
    if (isMewingActive) {
      interval = setInterval(() => {
        setMewingSeconds((s) => s + 1);
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isMewingActive]);

  // Toggle 40Hz Gamma Audio
  const handleToggleGamma = () => {
    playPlunk();
    const nextState = !isGammaPlaying;
    setIsGammaPlaying(nextState);
    toggleBinaural('gamma', nextState);
    showToast(nextState ? '40Hz Gamma Flow Beats: ACTIVATED' : '40Hz Gamma Beats: MUTED');
  };

  // Dual N-Back Step
  const stepNBack = () => {
    const letters = ['A', 'C', 'H', 'K', 'L', 'O', 'T', 'X'];
    const nextPos = Math.floor(Math.random() * 9);
    const nextLetter = letters[Math.floor(Math.random() * letters.length)];
    setNBackPosition(nextPos);
    setNBackLetter(nextLetter);
    setNBackHistory((prev) => [...prev.slice(-3), { pos: nextPos, letter: nextLetter }]);
    playHaptic(850, 'sine', 0.04);
  };

  const completedProtocolsCount = protocols.filter((p) => p.completed).length;
  const protocolPercentage = Math.round((completedProtocolsCount / protocols.length) * 100);

  const mainContent = (
    <div className="flex-1 overflow-y-auto no-scrollbar pb-28 px-4 md:px-8 pt-4 space-y-6">
      {/* ============================================================== */}
      {/* TAB 1: COMMAND HUB (TODAY'S APEX PULSE)                        */}
      {/* ============================================================== */}
      {activeTab === 'hub' && (
        <div className="space-y-6 animate-fade-in">
          {/* CRED-STYLE LIQUID GLASS HERO CARD */}
          <div className="liquid-glass-elevated rounded-[28px] p-6 border border-white/20 relative overflow-hidden">
            <div className="absolute top-0 right-0 w-80 h-80 bg-gradient-to-br from-[#FA114F]/15 via-[#E5FE40]/10 to-transparent rounded-full blur-3xl pointer-events-none" />

            {/* Top row */}
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div>
                <div className="flex items-center space-x-2">
                  <span className="text-[10px] font-mono font-black tracking-widest text-[#E5FE40] uppercase">
                    HUMAN OPTIMIZATION ENGINE
                  </span>
                  <span className="w-1.5 h-1.5 rounded-full bg-[#10B981] animate-ping" />
                </div>
                <h1 className="text-2xl md:text-3xl font-black text-white tracking-tight mt-0.5">
                  Apex Biomarker Status: <span className="holo-glow">ELITE 0.01%</span>
                </h1>
                <p className="text-xs text-[#A1A1AA] font-mono mt-1">
                  Chronological: 29.0y · Biological: 22.8y (-6.2y) · Pace: 0.74x/yr
                </p>
              </div>

              {/* Apple Activity Rings Interactive Pod */}
              <div
                onClick={() => {
                  playPlunk();
                  setIsHealthModalOpen(true);
                }}
                className="flex items-center space-x-4 bg-black/40 hover:bg-black/60 transition p-3 rounded-[20px] border border-white/10 cursor-pointer group"
                title="Click to view & add Apple Health telemetry"
              >
                <ActivityRings
                  move={appleHealthState.activityRings.move}
                  exercise={appleHealthState.activityRings.exercise}
                  stand={appleHealthState.activityRings.stand}
                  size={96}
                  strokeWidth={9}
                />
                <div className="space-y-1 text-xs font-mono">
                  <div className="flex items-center space-x-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-[#FA114F]" />
                    <span className="text-white font-bold">{appleHealthState.activityRings.move.current}</span>
                    <span className="text-[#8A8A8A]">/ {appleHealthState.activityRings.move.target} kcal</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-[#92E82A]" />
                    <span className="text-white font-bold">{appleHealthState.activityRings.exercise.current}</span>
                    <span className="text-[#8A8A8A]">/ {appleHealthState.activityRings.exercise.target} min</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-[#00D6E6]" />
                    <span className="text-white font-bold">{appleHealthState.activityRings.stand.current}</span>
                    <span className="text-[#8A8A8A]">/ {appleHealthState.activityRings.stand.target} hrs</span>
                  </div>
                </div>
              </div>
            </div>

            {/* WHAT TO DO RIGHT NOW — PROACTIVE AI EXECUTIVE DIRECTIVE */}
            <div className="mt-6 p-5 rounded-[24px] bg-gradient-to-r from-black/80 via-[#0A0D14]/90 to-black/80 border border-white/20 shadow-[0_15px_40px_rgba(0,0,0,0.8)] relative overflow-hidden">
              <div className="absolute top-0 right-0 w-64 h-32 bg-[#E5FE40]/10 rounded-full blur-3xl pointer-events-none" />

              <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
                <div className="flex items-center space-x-2">
                  <span className="w-2.5 h-2.5 rounded-full bg-[#10B981] animate-ping" />
                  <span className="text-[11px] font-mono font-black text-[#E5FE40] uppercase tracking-wider">
                    PROACTIVE AI DIRECTIVE // WHAT TO DO RIGHT NOW
                  </span>
                </div>
                <span className="text-[10px] font-mono font-bold px-2.5 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40">
                  AUTONOMIC RECOVERY 94% · GREEN LIGHT TO PUSH
                </span>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs font-mono mb-4">
                <div className="p-3 rounded-[14px] bg-white/[0.04] border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#FA114F] font-bold block">1. PHYSICAL STRAIN DIRECTIVE</span>
                  <p className="text-white font-bold text-sm">Hit 18.0 Day Strain (+1.2 needed)</p>
                  <p className="text-[11px] text-[#A1A1AA]">
                    Execute 3 sets of 15 bodyweight squats using FaceTime AI Kinematics. Verify 90° depth.
                  </p>
                </div>

                <div className="p-3 rounded-[14px] bg-white/[0.04] border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#00F0FF] font-bold block">2. NUTRITION & ANABOLISM</span>
                  <p className="text-white font-bold text-sm">320 kcal & 14g Protein Remaining</p>
                  <p className="text-[11px] text-[#A1A1AA]">
                    Consume grass-fed whey or Greek yogurt with 5g creatine before 7:30 PM.
                  </p>
                </div>

                <div className="p-3 rounded-[14px] bg-white/[0.04] border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#38BDF8] font-bold block">3. CIRCADIAN SLEEP ARCHITECTURE</span>
                  <p className="text-white font-bold text-sm">Target Bedtime: 10:30 PM (8.2h Goal)</p>
                  <p className="text-[11px] text-[#A1A1AA]">
                    Digital sunset at 9:30 PM. 144mg Magnesium L-Threonate + palatal tongue posture.
                  </p>
                </div>
              </div>

              {/* Actionable Launchers */}
              <div className="flex flex-wrap items-center gap-2 pt-2 border-t border-white/10 text-xs font-mono">
                <span className="text-[#8A8A8A] text-[11px] mr-1">EXECUTE NOW:</span>
                <button
                  onClick={() => {
                    playPlunk();
                    setActiveTab('fitness');
                    setFitnessSubTab('camera');
                  }}
                  className="px-3 py-1.5 rounded-[10px] bg-[#FA114F]/20 text-[#FA114F] hover:bg-[#FA114F]/30 border border-[#FA114F]/40 font-bold transition flex items-center space-x-1.5"
                >
                  <Camera className="w-3.5 h-3.5" />
                  <span>START CAMERA SQUATS</span>
                </button>

                <button
                  onClick={() => {
                    playPlunk();
                    setActiveTab('looks');
                    setLooksSubTab('lidar');
                  }}
                  className="px-3 py-1.5 rounded-[10px] bg-[#00F0FF]/20 text-[#00F0FF] hover:bg-[#00F0FF]/30 border border-[#00F0FF]/40 font-bold transition flex items-center space-x-1.5"
                >
                  <Eye className="w-3.5 h-3.5" />
                  <span>RUN CRANIOFACIAL LIDAR MESH</span>
                </button>

                <button
                  onClick={() => {
                    playPlunk();
                    setActiveTab('looks');
                    setLooksSubTab('voice');
                  }}
                  className="px-3 py-1.5 rounded-[10px] bg-[#E5FE40]/20 text-[#E5FE40] hover:bg-[#E5FE40]/30 border border-[#E5FE40]/40 font-bold transition flex items-center space-x-1.5"
                >
                  <Mic className="w-3.5 h-3.5" />
                  <span>VOICE RESONANCE TEST</span>
                </button>

                <button
                  onClick={() => {
                    playPlunk();
                    setActiveTab('fitness');
                    setFitnessSubTab('muscles');
                  }}
                  className="px-3 py-1.5 rounded-[10px] bg-[#E5FE40]/20 text-[#E5FE40] hover:bg-[#E5FE40]/30 border border-[#E5FE40]/40 font-bold transition flex items-center space-x-1.5"
                >
                  <Dumbbell className="w-3.5 h-3.5" />
                  <span>14-MUSCLE VOLUME MAP</span>
                </button>

                <button
                  onClick={() => {
                    playPlunk();
                    setActiveTab('fitness');
                    setFitnessSubTab('decathlon');
                  }}
                  className="px-3 py-1.5 rounded-[10px] bg-[#10B981]/20 text-[#10B981] hover:bg-[#10B981]/30 border border-[#10B981]/40 font-bold transition flex items-center space-x-1.5"
                >
                  <Trophy className="w-3.5 h-3.5" />
                  <span>CENTENARIAN DECATHLON</span>
                </button>

                <button
                  onClick={() => {
                    playPlunk();
                    setActiveTab('nutrition');
                    setNutritionSubTab('scanner');
                  }}
                  className="px-3 py-1.5 rounded-[10px] bg-[#00F0FF]/20 text-[#00F0FF] hover:bg-[#00F0FF]/30 border border-[#00F0FF]/40 font-bold transition flex items-center space-x-1.5"
                >
                  <Target className="w-3.5 h-3.5" />
                  <span>AI MEAL SCANNER</span>
                </button>

                <button
                  onClick={() => {
                    playPlunk();
                    setActiveTab('bio');
                    setBioSubTab('consigliere');
                  }}
                  className="px-3 py-1.5 rounded-[10px] bg-white/10 hover:bg-white/20 text-white border border-white/20 font-bold transition flex items-center space-x-1.5"
                >
                  <Bot className="w-3.5 h-3.5" />
                  <span>OPEN AI COACH BRIEFING</span>
                </button>
              </div>
            </div>

            {/* Quick Action Matrix */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 mt-6">
              <button
                onClick={() => {
                  playPlunk();
                  setActiveTab('bio');
                  setBioSubTab('consigliere');
                }}
                className="p-3 rounded-[16px] bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 text-left transition"
              >
                <div className="flex items-center justify-between mb-1">
                  <Bot className="w-4 h-4 text-[#E5FE40]" />
                  <span className="text-[10px] font-mono text-[#10B981] font-bold">ONLINE</span>
                </div>
                <span className="text-xs font-mono font-bold text-white block">AI Consigliere</span>
                <span className="text-[10px] font-mono text-[#8A8A8A]">Clinical Longevity Q&A</span>
              </button>

              <button
                onClick={() => {
                  playPlunk();
                  setActiveTab('fitness');
                  setFitnessSubTab('thermal');
                }}
                className="p-3 rounded-[16px] bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 text-left transition"
              >
                <div className="flex items-center justify-between mb-1">
                  <Snowflake className="w-4 h-4 text-[#00F0FF]" />
                  <span className="text-[10px] font-mono text-[#00F0FF] font-bold">RBM3 PROTEIN</span>
                </div>
                <span className="text-xs font-mono font-bold text-white block">Cryo & Sauna</span>
                <span className="text-[10px] font-mono text-[#8A8A8A]">Thermal Shock Engine</span>
              </button>

              <button
                onClick={() => {
                  playPlunk();
                  setActiveTab('bio');
                  setBioSubTab('phenoage');
                }}
                className="p-3 rounded-[16px] bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 text-left transition"
              >
                <div className="flex items-center justify-between mb-1">
                  <Activity className="w-4 h-4 text-[#10B981]" />
                  <span className="text-[10px] font-mono text-[#10B981] font-bold">-6.2y AGE</span>
                </div>
                <span className="text-xs font-mono font-bold text-white block">PhenoAge Lab</span>
                <span className="text-[10px] font-mono text-[#8A8A8A]">Epigenetic Reversal</span>
              </button>

              <button
                onClick={() => {
                  playPlunk();
                  setActiveTab('garage');
                  setGarageSubTab('burnvault');
                }}
                className="p-3 rounded-[16px] bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 text-left transition"
              >
                <div className="flex items-center justify-between mb-1">
                  <Flame className="w-4 h-4 text-[#FA114F]" />
                  <span className="text-[10px] font-mono text-[#E5FE40] font-bold">2X STAKE</span>
                </div>
                <span className="text-xs font-mono font-bold text-white block">The Burn Vault</span>
                <span className="text-[10px] font-mono text-[#8A8A8A]">Anti-Charity Stakes</span>
              </button>
            </div>
          </div>

          {/* AI CAMERA WORKOUT TRACKER HERO BANNER */}
          <div
            onClick={() => {
              playPlunk();
              setActiveTab('fitness');
              setFitnessSubTab('camera');
            }}
            className="liquid-glass-elevated rounded-[24px] p-5 border border-[#E5FE40]/40 bg-gradient-to-r from-black/80 via-[#0B0F17] to-black/80 hover:border-[#E5FE40] transition cursor-pointer group relative overflow-hidden shadow-[0_10px_30px_rgba(0,0,0,0.5)]"
          >
            <div className="absolute top-0 right-0 w-80 h-full bg-[#E5FE40]/10 blur-2xl pointer-events-none group-hover:bg-[#E5FE40]/20 transition" />
            <div className="flex flex-wrap items-center justify-between gap-4 relative z-10">
              <div className="flex items-center space-x-3.5">
                <div className="w-12 h-12 rounded-[16px] bg-[#E5FE40] text-black flex items-center justify-center font-black shadow-[0_0_20px_rgba(229,254,64,0.4)]">
                  <Camera className="w-6 h-6" />
                </div>
                <div>
                  <div className="flex items-center space-x-2">
                    <span className="text-sm font-black text-white tracking-tight">
                      AI Camera Workout Tracker // Mac FaceTime Vision
                    </span>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                      NEW 2026
                    </span>
                  </div>
                  <p className="text-xs font-mono text-[#A1A1AA] mt-0.5">
                    Real-time biomechanical skeleton, automated rep counter, ROM depth check & audio coach
                  </p>
                </div>
              </div>

              <div className="flex items-center space-x-2">
                <span className="text-xs font-mono font-bold text-[#E5FE40] group-hover:underline flex items-center space-x-1">
                  <span>LAUNCH MAC CAM WORKOUT</span>
                  <span>→</span>
                </span>
              </div>
            </div>
          </div>

          {/* CRED REWARDS JACKPOT DROP */}
          <WheelOfMaxxing
            coins={coins}
            setCoins={setCoins}
            onRewardWon={(item) => showToast(`Claimed: ${item.title}`)}
          />

          {/* DAILY NON-NEGOTIABLE PROTOCOLS CHECKLIST */}
          <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <span className="text-[10px] font-mono text-[#E5FE40] uppercase font-black tracking-widest">
                  CIRCADIAN EXECUTION
                </span>
                <h3 className="text-base font-bold text-white tracking-tight">
                  Daily Lifemaxx Protocol Engine
                </h3>
              </div>
              <div className="flex items-center space-x-2">
                <span className="text-xs font-mono font-bold text-[#E5FE40]">
                  {completedProtocolsCount} / {protocols.length} ({protocolPercentage}%)
                </span>
              </div>
            </div>

            {/* Protocol checklist */}
            <div className="space-y-2">
              {protocols.map((proto) => (
                <div
                  key={proto.id}
                  onClick={() => toggleProtocol(proto.id)}
                  className={`p-3.5 rounded-[16px] border transition cursor-pointer flex items-center justify-between ${
                    proto.completed
                      ? 'bg-white/[0.02] border-white/5 opacity-75'
                      : 'bg-white/[0.06] border-white/15 hover:border-white/30'
                  }`}
                >
                  <div className="flex items-center space-x-3.5">
                    <div
                      className={`w-6 h-6 rounded-[8px] flex items-center justify-center border transition ${
                        proto.completed
                          ? 'bg-[#E5FE40] border-[#E5FE40] text-black font-bold shadow-[0_0_10px_rgba(229,254,64,0.5)]'
                          : 'border-white/30 bg-black/40'
                      }`}
                    >
                      {proto.completed && <Check className="w-4 h-4 stroke-[3]" />}
                    </div>
                    <div>
                      <div className="flex items-center space-x-2">
                        <span className="text-[10px] font-mono font-bold text-[#8A8A8A]">
                          {proto.time}
                        </span>
                        <span
                          className={`text-xs font-bold font-mono ${
                            proto.completed ? 'line-through text-[#8A8A8A]' : 'text-white'
                          }`}
                        >
                          {proto.title}
                        </span>
                      </div>
                      <p className="text-[11px] text-[#A1A1AA] line-clamp-1">{proto.desc}</p>
                    </div>
                  </div>

                  <span className="text-[10px] font-mono font-black px-2 py-0.5 rounded bg-black/60 text-[#E5FE40] border border-white/10">
                    +{proto.xp} XP
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ============================================================== */}
      {/* TAB 2: FITNESS SUITE (WHOOP/STRAVA/THERMAL/HEVY/DECATHLON)      */}
      {/* ============================================================== */}
      {activeTab === 'fitness' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex items-center justify-between">
            <div>
              <span className="text-[10px] font-mono text-[#FA114F] font-black uppercase tracking-widest">
                COMPLETE FITNESS ECOSYSTEM
              </span>
              <h2 className="text-xl font-bold text-white tracking-tight">Fitness Telemetry & Engine</h2>
            </div>
            <button
              onClick={() => {
                playPlunk();
                setIsHealthModalOpen(true);
              }}
              className="px-3 py-1.5 rounded-[12px] cred-plunk-dark text-xs font-mono font-bold flex items-center space-x-1.5 border border-[#FA114F]/40"
            >
              <RefreshCw className="w-3.5 h-3.5 text-[#FA114F]" />
              <span>HEALTHKIT SYNC</span>
            </button>
          </div>

          {/* Sub-navigation across top fitness apps */}
          <div className="flex items-center space-x-2 border-b border-white/10 pb-3 overflow-x-auto no-scrollbar">
            {[
              { id: 'camera', label: 'AI Camera Pose Tracker', icon: Camera, color: '#E5FE40' },
              { id: 'recovery', label: 'Whoop Recovery & Strain', icon: Heart, color: '#FA114F' },
              { id: 'thermal', label: 'Cryo & Sauna Suite', icon: Snowflake, color: '#00F0FF' },
              { id: 'decathlon', label: 'Centenarian Decathlon', icon: Trophy, color: '#E5FE40' },
              { id: 'muscles', label: 'Muscular Heatmap', icon: Dumbbell, color: '#00F0FF' },
              { id: 'workout', label: 'Hevy Sets & 1RM', icon: Dumbbell, color: '#E5FE40' },
              { id: 'strava', label: 'Strava GPS & KOM', icon: Compass, color: '#FC5200' },
              { id: 'cgm', label: 'Dexcom CGM & Jetlag', icon: Zap, color: '#10B981' },
              { id: 'breathwork', label: 'Apple Fit+ Breath', icon: Wind, color: '#00D6E6' },
              { id: 'habits', label: 'Habit Matrix', icon: ShieldCheck, color: '#8B5CF6' },
            ].map((sub) => {
              const Icon = sub.icon;
              const isSelected = fitnessSubTab === sub.id;
              return (
                <button
                  key={sub.id}
                  onClick={() => {
                    playPlunk();
                    setFitnessSubTab(sub.id);
                  }}
                  className={`px-3.5 py-1.5 rounded-[12px] text-xs font-mono font-bold flex items-center space-x-1.5 transition shrink-0 ${
                    isSelected
                      ? 'bg-white/15 text-white border border-white/30 shadow-[0_0_12px_rgba(255,255,255,0.15)] font-black'
                      : 'bg-white/[0.03] text-[#8A8A8A] hover:text-white border border-white/5'
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" style={{ color: sub.color }} />
                  <span>{sub.label}</span>
                </button>
              );
            })}
          </div>

          {fitnessSubTab === 'camera' && (
            <CameraWorkoutTracker
              onAddHealthData={handleAddHealthData}
              onLogSet={(set) => showToast(`Camera Reps Logged: ${set.reps} ${set.exercise}`)}
            />
          )}
          {fitnessSubTab === 'recovery' && <RecoveryStrainView healthData={appleHealthState} />}
          {fitnessSubTab === 'thermal' && <ThermalSuite />}
          {fitnessSubTab === 'decathlon' && <CentenarianDecathlon />}
          {fitnessSubTab === 'muscles' && <MuscleRecoveryMap />}
          {fitnessSubTab === 'workout' && <WorkoutLogger />}
          {fitnessSubTab === 'strava' && <StravaActivityHub />}
          {fitnessSubTab === 'cgm' && <GlucoseCircadianHub />}
          {fitnessSubTab === 'breathwork' && <BreathworkCoach />}
          {fitnessSubTab === 'habits' && <HabitCorrelations />}
        </div>
      )}

      {/* ============================================================== */}
      {/* TAB 3: LOOKSMAXXING STUDIO (MEWING, LIDAR AR, VOCAL RESONANCE)  */}
      {/* ============================================================== */}
      {activeTab === 'looks' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <span className="text-[10px] font-mono text-[#00F0FF] font-black uppercase tracking-widest">
                CRANIOFACIAL & MORPHOLOGY
              </span>
              <h2 className="text-xl font-bold text-white tracking-tight">Looksmaxxing Studio</h2>
            </div>
            {/* Sub-nav */}
            <div className="flex items-center space-x-1.5 bg-black/40 p-1 rounded-[12px] border border-white/10 overflow-x-auto max-w-full no-scrollbar">
              <button
                onClick={() => {
                  playPlunk();
                  setLooksSubTab('mewing');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  looksSubTab === 'mewing' ? 'bg-[#00F0FF] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                Mewing & Ratios
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setLooksSubTab('lidar');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  looksSubTab === 'lidar' ? 'bg-[#00F0FF] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                LiDAR AR Scanner
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setLooksSubTab('voice');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  looksSubTab === 'voice' ? 'bg-[#00F0FF] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                Vocal Resonance
              </button>
            </div>
          </div>

          {looksSubTab === 'lidar' && <FacialLiDARScanner />}
          {looksSubTab === 'voice' && <VocalResonanceAnalyzer />}
          {looksSubTab === 'mewing' && (
            <div className="space-y-6">
              {/* MEWING TIMER & SUCTION CUES */}
              <div className="liquid-glass-elevated rounded-[24px] p-6 border border-white/15">
                <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 rounded-[12px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 flex items-center justify-center">
                      <Sparkles className="w-5 h-5 text-[#00F0FF]" />
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-white">Palatal Tongue Suction Timer</h3>
                      <p className="text-[11px] font-mono text-[#8A8A8A]">
                        Maxillary upswing, gonial definition & nasal airway expansion
                      </p>
                    </div>
                  </div>

                  <div className="text-right">
                    <span className="text-3xl font-mono font-black text-white">
                      {Math.floor(mewingSeconds / 60)}:
                      {(mewingSeconds % 60).toString().padStart(2, '0')}
                    </span>
                    <span className="text-[10px] font-mono text-[#00F0FF] block">SUCTION ACTIVE</span>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-2.5 my-4">
                  <div className="p-3 rounded-[12px] bg-black/40 border border-white/10 text-xs font-mono">
                    <span className="text-[#00F0FF] font-bold block mb-1">1. POSTERIOR 1/3 TONGUE</span>
                    <p className="text-[#A1A1AA] text-[11px]">Push back against soft palate with "NG" sound.</p>
                  </div>
                  <div className="p-3 rounded-[12px] bg-black/40 border border-white/10 text-xs font-mono">
                    <span className="text-[#00F0FF] font-bold block mb-1">2. BUTTERFLY CONTACT</span>
                    <p className="text-[#A1A1AA] text-[11px]">Molars lightly touching or 1mm apart. Lips sealed.</p>
                  </div>
                  <div className="p-3 rounded-[12px] bg-black/40 border border-white/10 text-xs font-mono">
                    <span className="text-[#00F0FF] font-bold block mb-1">3. VACUUM SWALLOW</span>
                    <p className="text-[#A1A1AA] text-[11px]">Create negative intraoral pressure lock.</p>
                  </div>
                </div>

                <div className="flex items-center space-x-3">
                  <button
                    onClick={() => {
                      playPlunk();
                      setIsMewingActive(!isMewingActive);
                    }}
                    className="flex-1 py-3 rounded-[14px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center justify-center space-x-2"
                  >
                    {isMewingActive ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                    <span>{isMewingActive ? 'PAUSE SUCTION' : 'START MEWING POSTURE SESSION'}</span>
                  </button>
                  <button
                    onClick={() => {
                      playPlunk();
                      setMewingSeconds(0);
                      setIsMewingActive(false);
                    }}
                    className="px-4 py-3 rounded-[14px] cred-plunk-dark text-xs font-mono font-bold"
                  >
                    <RotateCcw className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* FACIAL RATIOS & BODY MORPHOLOGY */}
              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
                {Object.entries(LOOKSMAXXING_METRICS).map(([key, data]) => (
                  <div key={key} className="liquid-glass rounded-[18px] p-4 border border-white/10">
                    <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">
                      {data.label}
                    </span>
                    <div className="flex items-baseline space-x-2 my-1">
                      <span className="text-2xl font-mono font-black text-white">{data.value}</span>
                      <span className="text-[11px] font-mono text-[#10B981] font-bold">
                        Target: {data.target}
                      </span>
                    </div>
                    <div className="w-full h-1 bg-black/40 rounded-full overflow-hidden mt-2">
                      <div className="h-full bg-[#00F0FF] rounded-full w-4/5" />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ============================================================== */}
      {/* TAB 4: BIOMAXXING & EPIGENETICS (AI CONSIGLIERE & PHENOAGE)     */}
      {/* ============================================================== */}
      {activeTab === 'bio' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <span className="text-[10px] font-mono text-[#10B981] font-black uppercase tracking-widest">
                EPIGENETICS & BIOMARKERS
              </span>
              <h2 className="text-xl font-bold text-white tracking-tight">Biomaxxing Index</h2>
            </div>
            {/* Sub-nav */}
            <div className="flex items-center space-x-1.5 bg-black/40 p-1 rounded-[12px] border border-white/10 overflow-x-auto max-w-full no-scrollbar">
              <button
                onClick={() => {
                  playPlunk();
                  setBioSubTab('overview');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  bioSubTab === 'overview' ? 'bg-[#10B981] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                Lab Markers
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setBioSubTab('consigliere');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  bioSubTab === 'consigliere' ? 'bg-[#10B981] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                AI Consigliere
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setBioSubTab('phenoage');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  bioSubTab === 'phenoage' ? 'bg-[#10B981] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                PhenoAge Clock
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setBioSubTab('ocr');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  bioSubTab === 'ocr' ? 'bg-[#10B981] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                Bloodwork OCR
              </button>
            </div>
          </div>

          {bioSubTab === 'consigliere' && <AIConsigliere />}
          {bioSubTab === 'phenoage' && <PhenoAgeCalculator />}
          {bioSubTab === 'ocr' && <BloodworkScanner />}
          {bioSubTab === 'overview' && (
            <div className="space-y-6">
              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3">
                {BIOMARKER_DATA.map((bio, idx) => (
                  <div key={idx} className="liquid-glass rounded-[18px] p-4 border border-white/10">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-[10px] font-mono text-[#8A8A8A] uppercase truncate max-w-[120px]">
                        {bio.marker}
                      </span>
                      <span className="text-[9px] font-mono font-black px-1.5 py-0.5 rounded bg-[#10B981]/20 text-[#10B981]">
                        {bio.status}
                      </span>
                    </div>
                    <span className="text-xl font-mono font-black text-white block my-1">{bio.value}</span>
                    <div className="flex items-center justify-between text-[10px] font-mono text-[#A1A1AA] pt-1 border-t border-white/5">
                      <span>Target: {bio.target}</span>
                      <span className="text-[#10B981] font-bold">{bio.delta}</span>
                    </div>
                  </div>
                ))}
              </div>

              {/* MASTER PROTOCOLS */}
              <div className="space-y-3">
                <h3 className="text-sm font-mono font-black text-white uppercase tracking-wider">
                  MASTER BLUEPRINTS (BRYAN JOHNSON / HUBERMAN / NAVAL)
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  {MASTER_BLUEPRINTS.map((bp) => (
                    <div key={bp.id} className="liquid-glass rounded-[18px] p-4 border border-white/10 hover:border-white/30 transition">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase">
                          {bp.tag}
                        </span>
                        <span className="text-[10px] font-mono text-[#8A8A8A]">{bp.duration}</span>
                      </div>
                      <h4 className="text-sm font-bold text-white mb-1">{bp.name}</h4>
                      <p className="text-xs text-[#A1A1AA] leading-relaxed">{bp.desc}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ============================================================== */}
      {/* TAB 5: BRAINMAXXING (FLOW SPRINT, SOUND ENGINE, DOPAMINE DETOX) */}
      {/* ============================================================== */}
      {activeTab === 'brain' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <span className="text-[10px] font-mono text-[#8B5CF6] font-black uppercase tracking-widest">
                NEURAL VELOCITY & FLOW STATE
              </span>
              <h2 className="text-xl font-bold text-white tracking-tight">Brainmaxxing Engine</h2>
            </div>
            {/* Sub-nav */}
            <div className="flex items-center space-x-1.5 bg-black/40 p-1 rounded-[12px] border border-white/10 overflow-x-auto max-w-full no-scrollbar">
              <button
                onClick={() => {
                  playPlunk();
                  setBrainSubTab('sprint');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  brainSubTab === 'sprint' ? 'bg-[#8B5CF6] text-white font-black' : 'text-[#8A8A8A]'
                }`}
              >
                Sprint & N-Back
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setBrainSubTab('soundengine');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  brainSubTab === 'soundengine' ? 'bg-[#8B5CF6] text-white font-black' : 'text-[#8A8A8A]'
                }`}
              >
                Neural Sounds
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setBrainSubTab('dopamine');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  brainSubTab === 'dopamine' ? 'bg-[#8B5CF6] text-white font-black' : 'text-[#8A8A8A]'
                }`}
              >
                Dopamine Detox
              </button>
            </div>
          </div>

          {brainSubTab === 'soundengine' && <NeuralSoundEngine />}
          {brainSubTab === 'dopamine' && <DopamineDetoxMeter />}
          {brainSubTab === 'sprint' && (
            <div className="space-y-6">
              {/* 40HZ FLOW TIMER */}
              <div className="liquid-glass-elevated rounded-[24px] p-6 border border-white/15 text-center">
                <span className="text-[10px] font-mono font-black uppercase text-[#8B5CF6] tracking-widest">
                  DEEP WORK SPRINT · 40HZ BINAURAL SYNTHESIZER
                </span>
                <div className="text-5xl md:text-6xl font-mono font-black text-white my-4 tracking-tighter">
                  {flowMinutes.toString().padStart(2, '0')}:{flowSeconds.toString().padStart(2, '0')}
                </div>

                <div className="flex items-center justify-center space-x-3 max-w-sm mx-auto">
                  <button
                    onClick={() => {
                      playPlunk();
                      if (!isFlowActive && !isGammaPlaying) {
                        handleToggleGamma();
                      }
                      setIsFlowActive(!isFlowActive);
                    }}
                    className="flex-1 py-3.5 rounded-[14px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center justify-center space-x-2"
                  >
                    {isFlowActive ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                    <span>{isFlowActive ? 'PAUSE SPRINT' : 'START 25m FLOW SPRINT'}</span>
                  </button>
                  <button
                    onClick={() => {
                      playPlunk();
                      setFlowMinutes(25);
                      setFlowSeconds(0);
                      setIsFlowActive(false);
                    }}
                    className="px-4 py-3.5 rounded-[14px] cred-plunk-dark text-xs font-mono font-bold"
                  >
                    <RotateCcw className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* DUAL N-BACK AGILITY TRAINER */}
              <div className="liquid-glass rounded-[24px] p-6 border border-white/10">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <span className="text-[10px] font-mono text-[#8B5CF6] font-black uppercase tracking-wider">
                      FLUID INTELLIGENCE EXPANDER
                    </span>
                    <h3 className="text-sm font-bold text-white">Dual N-Back Working Memory Trainer</h3>
                  </div>
                  <span className="text-xs font-mono text-[#E5FE40] font-black">
                    SCORE: {nBackScore} PTS
                  </span>
                </div>

                <div className="flex flex-col md:flex-row items-center gap-6 justify-center my-4">
                  <div className="grid grid-cols-3 gap-2 w-48 h-48 bg-black/60 p-2 rounded-[16px] border border-white/15">
                    {[0, 1, 2, 3, 4, 5, 6, 7, 8].map((idx) => {
                      const isActive = nBackPosition === idx;
                      return (
                        <div
                          key={idx}
                          className={`rounded-[10px] flex items-center justify-center font-mono font-black text-lg transition-all ${
                            isActive
                              ? 'bg-[#8B5CF6] text-white shadow-[0_0_15px_#8B5CF6] scale-105'
                              : 'bg-white/5 border border-white/5'
                          }`}
                        >
                          {isActive && nBackLetter}
                        </div>
                      );
                    })}
                  </div>

                  <div className="space-y-3 text-center md:text-left">
                    <p className="text-xs text-[#A1A1AA] max-w-xs">
                      Train working memory capacity and $g$-factor fluid intelligence. Remember both spatial location and audio/letter cues.
                    </p>
                    <button
                      onClick={() => {
                        stepNBack();
                        setNBackScore((s) => s + 10);
                      }}
                      className="px-6 py-2.5 rounded-[12px] cred-plunk-primary text-xs font-mono font-black uppercase"
                    >
                      NEXT TRIAL STEP (+10 XP)
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ============================================================== */}
      {/* TAB 6: NUTRITION & MACROFACTOR AI VISION SCANNER               */}
      {/* ============================================================== */}
      {activeTab === 'nutrition' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <span className="text-[10px] font-mono text-[#00D6E6] font-black uppercase tracking-widest">
                METABOLIC NUTRITION & DISPENSARY
              </span>
              <h2 className="text-xl font-bold text-white tracking-tight">Precision Fuel & AI Scanner</h2>
            </div>
            {/* Sub-nav */}
            <div className="flex items-center space-x-1.5 bg-black/40 p-1 rounded-[12px] border border-white/10 overflow-x-auto max-w-full no-scrollbar">
              <button
                onClick={() => {
                  playPlunk();
                  setNutritionSubTab('macros');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  nutritionSubTab === 'macros' ? 'bg-[#00D6E6] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                Macros & Stacks
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setNutritionSubTab('scanner');
                }}
                className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                  nutritionSubTab === 'scanner' ? 'bg-[#00D6E6] text-black font-black' : 'text-[#8A8A8A]'
                }`}
              >
                AI Camera Scanner
              </button>
            </div>
          </div>

          {nutritionSubTab === 'macros' ? <NutritionView /> : <MealScanner />}
        </div>
      )}

      {/* ============================================================== */}
      {/* TAB 7: VAULT (HARDWARE GARAGE, BURN VAULT, IOS 18 WIDGETS)     */}
      {/* ============================================================== */}
      {activeTab === 'garage' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-widest">
                APEX HARDWARE & STAKING VAULT
              </span>
              <h2 className="text-xl font-bold text-white tracking-tight">Vault & Clan Ecosystem</h2>
            </div>
            {/* Sub-nav */}
            <div className="flex items-center space-x-1.5 bg-black/40 p-1 rounded-[12px] border border-white/10 overflow-x-auto max-w-full no-scrollbar">
              {[
                { id: 'hardware', label: 'Garage & Drops' },
                { id: 'models', label: 'Offline Models (139MB)' },
                { id: 'burnvault', label: 'The Burn Vault' },
                { id: 'ios18', label: 'iOS 18 Widgets' },
              ].map((sub) => (
                <button
                  key={sub.id}
                  onClick={() => {
                    playPlunk();
                    setGarageSubTab(sub.id);
                  }}
                  className={`px-3 py-1 rounded-[8px] text-xs font-mono font-bold transition shrink-0 ${
                    garageSubTab === sub.id ? 'bg-[#E5FE40] text-black font-black' : 'text-[#8A8A8A]'
                  }`}
                >
                  {sub.label}
                </button>
              ))}
            </div>
          </div>

          {garageSubTab === 'hardware' && (
            <div className="space-y-6">
              <HardwareGarage
                onDeviceSelect={(device) => showToast(`Calibrated: ${device.name}`)}
              />
              <WheelOfMaxxing
                coins={coins}
                setCoins={setCoins}
                onRewardWon={(item) => showToast(`Claimed: ${item.title}`)}
              />
            </div>
          )}

          {garageSubTab === 'models' && (
            <OfflineModelsMonitor />
          )}

          {garageSubTab === 'burnvault' && (
            <BurnVaultStaking coins={coins} setCoins={setCoins} />
          )}

          {garageSubTab === 'ios18' && (
            <IOS18WidgetsShowcase />
          )}
        </div>
      )}
    </div>
  );

  return (
    <div className="min-h-screen w-screen bg-[#030406] text-[#F3F4F6] font-sans antialiased flex flex-col items-center selection:bg-[#E5FE40] selection:text-black relative overflow-x-hidden cyber-grid">
      {/* TOAST NOTIFICATION */}
      {toastMessage && (
        <div className="fixed top-18 z-50 px-4 py-2 rounded-full bg-[#E5FE40] text-black font-mono font-black text-xs shadow-[0_10px_30px_rgba(229,254,64,0.5)] border border-black animate-bounce flex items-center space-x-2">
          <Sparkles className="w-3.5 h-3.5" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* APPLE HEALTHKIT MODAL */}
      <AppleHealthModal
        isOpen={isHealthModalOpen}
        onClose={() => setIsHealthModalOpen(false)}
        onSyncComplete={() => {
          showToast('Apple HealthKit data synchronized');
        }}
        healthData={appleHealthState}
        onAddHealthData={handleAddHealthData}
      />

      {/* TESTING ACCOUNT SWITCHER MODAL */}
      <AccountTesterModal
        isOpen={isAccountTesterOpen}
        onClose={() => setIsAccountTesterOpen(false)}
        userProfile={userProfile}
        setUserProfile={setUserProfile}
        coins={coins}
        setCoins={setCoins}
        streakDays={streakDays}
        setStreakDays={setStreakDays}
        onCompleteAllProtocols={completeAllProtocols}
      />

      {/* TOP DESKTOP UTILITY BAR */}
      <div className="w-full max-w-6xl px-4 py-2 flex items-center justify-between text-xs font-mono border-b border-white/5 bg-black/40 backdrop-blur-md">
        <div className="flex items-center space-x-3">
          <div className="w-7 h-7 rounded-[8px] bg-[#E5FE40] text-black font-black flex items-center justify-center text-sm border border-black shadow-[2px_2px_0px_#000]">
            ▲
          </div>
          <div>
            <span className="font-black text-white tracking-wider">APEX // OS</span>
            <span className="text-[9px] text-[#A1A1AA] ml-2">CRED-GRADE LIFEMAXXING</span>
          </div>
        </div>

        {/* Viewport switch: Mobile Phone Frame vs Desktop Ultra + Account Switcher */}
        <div className="flex items-center space-x-2">
          {/* Tester Account Chip */}
          <div
            onClick={() => {
              playPlunk();
              setIsAccountTesterOpen(true);
            }}
            className="flex items-center space-x-1.5 px-3 py-1 rounded-[10px] bg-black/70 hover:bg-black/90 border border-white/15 cursor-pointer text-white"
            title="Open Tester Account Hub"
          >
            <Crown className="w-3.5 h-3.5 text-[#E5FE40]" />
            <span className="font-bold">{userProfile.name}</span>
            <span className="text-[9px] px-1 rounded bg-[#E5FE40] text-black font-black">
              VIP FOUNDER
            </span>
          </div>

          <div className="px-3 py-1 rounded-[10px] bg-[#10B981]/15 text-[#10B981] flex items-center space-x-1.5 border border-[#10B981]/40 font-bold">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>ALL UNLOCKED</span>
          </div>

          <button
            onClick={() => {
              playPlunk();
              setIsMobileFrame(!isMobileFrame);
            }}
            className="px-3 py-1 rounded-[10px] bg-white/10 hover:bg-white/15 text-white flex items-center space-x-1.5 transition border border-white/10"
          >
            {isMobileFrame ? <Monitor className="w-3.5 h-3.5" /> : <Smartphone className="w-3.5 h-3.5" />}
            <span>{isMobileFrame ? 'DESKTOP FULL' : 'IPHONE 16 PRO'}</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setIsHealthModalOpen(true);
            }}
            className="px-3 py-1 rounded-[10px] bg-[#FA114F]/20 text-[#FA114F] hover:bg-[#FA114F]/30 flex items-center space-x-1.5 transition border border-[#FA114F]/40"
          >
            <Heart className="w-3.5 h-3.5 fill-[#FA114F]" />
            <span>APPLE HEALTH</span>
          </button>
        </div>
      </div>

      {/* MAIN CONTAINER (MOBILE PHONE FRAME OR RESPONSIVE DESKTOP) */}
      <div
        className={`w-full transition-all duration-300 flex flex-col ${
          isMobileFrame
            ? 'max-w-[420px] my-6 h-[880px] rounded-[52px] iphone-frame bg-[#07090D] border-[6px] border-[#2C303B] overflow-hidden relative'
            : 'max-w-6xl min-h-[90vh] my-4 rounded-[32px] liquid-glass-elevated border border-white/15 relative overflow-hidden'
        }`}
      >
        {/* IPHONE STATUS BAR & DYNAMIC ISLAND */}
        <div className="w-full bg-[#07090D]/90 backdrop-blur-md px-6 pt-2 pb-1 border-b border-white/5 shrink-0 z-30">
          <div className="flex items-center justify-between text-xs font-mono text-white/80 select-none">
            <span className="font-bold text-[11px]">9:41</span>
            <DynamicIsland
              isGammaPlaying={isGammaPlaying}
              isMewingActive={isMewingActive}
              mewingSeconds={mewingSeconds}
              isSyncing={false}
              onClick={() => {
                playPlunk();
                if (isGammaPlaying) setActiveTab('brain');
                else if (isMewingActive) setActiveTab('looks');
                else setIsHealthModalOpen(true);
              }}
            />
            <div className="flex items-center space-x-1.5 text-[10px]">
              <span>5G</span>
              <span>100%</span>
            </div>
          </div>

          {/* CRED APEX APP HEADER */}
          <div className="flex items-center justify-between mt-2 pt-1 pb-1">
            <div
              onClick={() => {
                playPlunk();
                setIsAccountTesterOpen(true);
              }}
              className="flex items-center space-x-2 cursor-pointer"
            >
              <span className="font-mono font-black text-sm tracking-wider text-white">APEX</span>
              <span className="text-[9px] font-mono px-1.5 py-0.2 rounded bg-[#E5FE40]/20 text-[#E5FE40] border border-[#E5FE40]/30 font-black">
                {userProfile.badge}
              </span>
            </div>

            <div className="flex items-center space-x-2">
              <div
                onClick={() => {
                  playPlunk();
                  setActiveTab('garage');
                  setGarageSubTab('burnvault');
                }}
                className="flex items-center space-x-1.5 px-2.5 py-1 rounded-full bg-black/60 border border-[#E5FE40]/40 cursor-pointer"
              >
                <Sparkles className="w-3 h-3 text-[#E5FE40]" />
                <span className="font-mono text-xs font-black text-[#E5FE40]">{coins}</span>
              </div>

              <div className="flex items-center space-x-1 px-2 py-1 rounded-full bg-black/60 border border-white/10 text-[10px] font-mono text-[#F59E0B] font-bold">
                <Flame className="w-3 h-3 text-[#F59E0B]" />
                <span>{streakDays}d</span>
              </div>
            </div>
          </div>
        </div>

        {/* SCROLLABLE MAIN CONTENT */}
        {mainContent}

        {/* ============================================================== */}
        {/* LIQUID GLASS BOTTOM NAVIGATION DOCK (CRED STYLE)               */}
        {/* ============================================================== */}
        <div className="absolute bottom-4 left-1/2 transform -translate-x-1/2 w-[92%] max-w-lg z-40 select-none">
          <div className="liquid-glass-dock rounded-[26px] p-2 flex items-center justify-between border border-white/20 shadow-[0_20px_50px_rgba(0,0,0,0.9)]">
            {[
              { id: 'hub', label: 'Hub', icon: Compass, color: '#E5FE40' },
              { id: 'fitness', label: 'Fitness', icon: Activity, color: '#FA114F' },
              { id: 'looks', label: 'Looks', icon: Sparkles, color: '#00F0FF' },
              { id: 'bio', label: 'Longevity', icon: Heart, color: '#10B981' },
              { id: 'brain', label: 'Flow', icon: Brain, color: '#8B5CF6' },
              { id: 'nutrition', label: 'Fuel', icon: Droplets, color: '#00D6E6' },
              { id: 'garage', label: 'Vault', icon: Watch, color: '#E5FE40' },
            ].map((tab) => {
              const isSelected = activeTab === tab.id;
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => {
                    playPlunk();
                    setActiveTab(tab.id);
                  }}
                  className={`flex flex-col items-center justify-center py-1.5 px-2 rounded-[16px] transition-all relative ${
                    isSelected
                      ? 'bg-white/15 text-white scale-105 shadow-[0_0_15px_rgba(255,255,255,0.15)] font-black'
                      : 'text-[#8A8A8A] hover:text-white'
                  }`}
                >
                  <Icon
                    className="w-4 h-4 mb-0.5"
                    style={{ color: isSelected ? tab.color : 'currentColor' }}
                  />
                  <span className="text-[9px] font-mono tracking-tight">{tab.label}</span>
                  {isSelected && (
                    <span
                      className="absolute -bottom-1 w-1 h-1 rounded-full"
                      style={{ backgroundColor: tab.color }}
                    />
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* IPHONE HOME INDICATOR BAR */}
        {isMobileFrame && (
          <div className="w-full flex justify-center pb-2 pt-1 bg-[#07090D] shrink-0">
            <div className="w-32 h-1 bg-white/30 rounded-full" />
          </div>
        )}
      </div>
    </div>
  );
}
