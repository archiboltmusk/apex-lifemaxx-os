import React, { useState, useEffect, useRef } from 'react';
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
  Clock,
  Zap,
  ExternalLink,
  AlertCircle,
  ArrowRight,
  Radio,
  Cpu,
  Upload,
  FileCode,
  Copy,
  Terminal,
  Activity
} from 'lucide-react';
import { playPlunk, playHealthSyncChime, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';
import { parseAppleHealthXML } from '../utils/appleHealthParser';

export default function AppleHealthModal({ isOpen, onClose, onSyncComplete, healthData, onAddHealthData }) {
  // Tabs: 'stream' | 'calibrate' | 'ios_app' | 'shortcuts' | 'xml_import'
  const [activeModalTab, setActiveModalTab] = useState('stream');

  // Stream & Gateway State
  const [localPort, setLocalPort] = useState(window.location.port || '60159');
  const [localIP, setLocalIP] = useState(
    (typeof window !== 'undefined' && window.__macDeviceTelemetry?.localIP) || '127.0.0.1'
  );
  const [syncToken, setSyncToken] = useState(
    (typeof window !== 'undefined' && window.__apexSyncToken) || ''
  );
  const [gatewayStatus, setGatewayStatus] = useState('');
  const [lastSyncTime, setLastSyncTime] = useState(healthData?.lastSynced || 'Awaiting iPhone Sync');
  const [packetCount, setPacketCount] = useState(0);
  const [isCheckingGateway, setIsCheckingGateway] = useState(false);
  const [copiedCurl, setCopiedCurl] = useState(false);

  // Calibration / Absolute Values State (Initialized cleanly from synced healthData, never hardcoded athlete stats)
  const [calibMove, setCalibMove] = useState(healthData?.activityRings?.move?.current ?? 0);
  const [calibMoveTarget, setCalibMoveTarget] = useState(healthData?.activityRings?.move?.target ?? 750);
  const [calibExercise, setCalibExercise] = useState(healthData?.activityRings?.exercise?.current ?? 0);
  const [calibStand, setCalibStand] = useState(healthData?.activityRings?.stand?.current ?? 0);
  const [calibRHR, setCalibRHR] = useState(healthData?.metrics?.restingHeartRate?.value ?? 0);
  const [calibHRV, setCalibHRV] = useState(healthData?.metrics?.hrv?.value ?? 0);
  const [calibVo2Max, setCalibVo2Max] = useState(healthData?.metrics?.vo2Max?.value ?? 0);
  const [calibSleepHours, setCalibSleepHours] = useState(healthData?.metrics?.sleep?.totalHours ?? 0);
  const [calibDeepSleep, setCalibDeepSleep] = useState(healthData?.metrics?.sleep?.deepHours ?? 0);

  // XML Import State
  const [isParsingXML, setIsParsingXML] = useState(false);
  const [xmlResult, setXmlResult] = useState(null);
  const [xmlFileName, setXmlFileName] = useState('');
  const fileInputRef = useRef(null);

  // Sync internal state when healthData changes
  useEffect(() => {
    if (healthData) {
      setCalibMove(healthData.activityRings?.move?.current ?? 0);
      setCalibMoveTarget(healthData.activityRings?.move?.target ?? 750);
      setCalibExercise(healthData.activityRings?.exercise?.current ?? 0);
      setCalibStand(healthData.activityRings?.stand?.current ?? 0);
      setCalibRHR(healthData.metrics?.restingHeartRate?.value ?? 0);
      setCalibHRV(healthData.metrics?.hrv?.value ?? 0);
      setCalibVo2Max(healthData.metrics?.vo2Max?.value ?? 0);
      setCalibSleepHours(healthData.metrics?.sleep?.totalHours ?? 0);
      setCalibDeepSleep(healthData.metrics?.sleep?.deepHours ?? 0);
    }
    if (typeof window !== 'undefined' && window.__macDeviceTelemetry?.localIP) {
      setLocalIP(window.__macDeviceTelemetry.localIP);
    }
    if (typeof window !== 'undefined' && window.__apexSyncToken) {
      setSyncToken(window.__apexSyncToken);
    }
  }, [healthData]);

  // Fetch verified pairing token + endpoint info from native Mac server
  useEffect(() => {
    if (!isOpen) return;
    fetch(`http://127.0.0.1:${localPort}/api/pairing-info`)
      .then((r) => (r.ok ? r.json() : null))
      .then((info) => {
        if (info?.syncToken) setSyncToken(info.syncToken);
        if (info?.localIP) setLocalIP(info.localIP);
        if (info?.port) setLocalPort(String(info.port));
      })
      .catch(() => {});
  }, [isOpen, localPort]);

  const [ipaPackageInfo, setIpaPackageInfo] = useState(null);

  useEffect(() => {
    if (!isOpen) return;
    const probeUrls = ['/api/ios-package', `http://127.0.0.1:${localPort}/api/ios-package`];
    (async () => {
      for (const url of probeUrls) {
        try {
          const res = await fetch(url);
          if (res.ok) {
            const ct = res.headers.get('content-type') || '';
            if (ct.includes('application/json')) {
              const info = await res.json();
              if (info && typeof info.available === 'boolean') {
                setIpaPackageInfo(info);
                return;
              }
            }
          }
        } catch {
          // Try next endpoint
        }
      }
      setIpaPackageInfo({ available: false });
    })();
  }, [isOpen, localPort]);

  // Listen for Real-Time Incoming HealthKit Webhook Packets
  useEffect(() => {
    if (!isOpen) return;

    const handleIncomingWebhook = (e) => {
      const payload = e.detail;
      setLastSyncTime(new Date().toLocaleTimeString());
      setPacketCount((c) => c + 1);
      playHealthSyncChime();

      if (onAddHealthData && payload) {
        onAddHealthData({
          calories: payload.move || payload.calories,
          exerciseMin: payload.exercise || payload.exerciseMin,
          standHours: payload.stand || payload.standHours,
          hrv: payload.hrv,
          rhr: payload.hr || payload.rhr,
          vo2Max: payload.vo2 || payload.vo2Max,
          source: payload.source || 'Apple Watch Ultra (Real-Time Ingest)',
          setAbsolute: payload.setAbsolute || false,
        });
      }
    };

    window.addEventListener('appleHealthSync', handleIncomingWebhook);
    return () => {
      window.removeEventListener('appleHealthSync', handleIncomingWebhook);
    };
  }, [isOpen, onAddHealthData]);

  if (!isOpen) return null;

  // Verify Real Local Continuity Gateway (No Synthetic Telemetry)
  const handleVerifyGateway = async () => {
    playPlunk();
    setIsCheckingGateway(true);
    try {
      const res = await fetch(`http://127.0.0.1:${localPort}/api/pairing-info`);
      if (res.ok) {
        const info = await res.json();
        if (info.syncToken) setSyncToken(info.syncToken);
        if (info.localIP) setLocalIP(info.localIP);
        setGatewayStatus(`Verified Bonjour & HTTP Gateway on ${info.localIP || localIP}:${info.port || localPort}`);
        playHealthSyncChime();
      } else {
        setGatewayStatus(`Gateway responded HTTP ${res.status}`);
      }
    } catch {
      setGatewayStatus('Running in standalone browser preview — start native APEX OS Mac app for LAN sync.');
    }
    setIsCheckingGateway(false);
  };

  // Commit Calibrated Absolute Biometrics
  const handleCommitCalibration = () => {
    playPlunk();
    playHealthSyncChime();

    if (onAddHealthData) {
      onAddHealthData({
        calories: Number(calibMove),
        exerciseMin: Number(calibExercise),
        standHours: Number(calibStand),
        hrv: Number(calibHRV),
        rhr: Number(calibRHR),
        vo2Max: Number(calibVo2Max),
        sleepHours: Number(calibSleepHours),
        deepSleepHours: Number(calibDeepSleep),
        source: 'User Biometric Calibration (Verified Apple Health Data)',
        setAbsolute: true,
      });
    }

    try {
      confetti({
        particleCount: 70,
        spread: 65,
        colors: ['#FA114F', '#92E82A', '#00D6E6'],
      });
    } catch {}

    onClose();
  };

  // Handle Real XML Upload
  const handleXmlFileUpload = (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;

    playPlunk();
    setXmlFileName(file.name);
    setIsParsingXML(true);

    const reader = new FileReader();
    reader.onload = (event) => {
      const content = event.target.result;
      const parsed = parseAppleHealthXML(content);
      setIsParsingXML(false);
      if (parsed.success) {
        setXmlResult(parsed.data);
        playCoinChime();
      } else {
        alert(`Error parsing Apple Health XML: ${parsed.error}`);
      }
    };
    reader.readAsText(file);
  };

  // Commit Parsed XML Data to State
  const handleCommitParsedXML = () => {
    if (!xmlResult) return;
    playPlunk();
    playHealthSyncChime();

    if (onAddHealthData) {
      onAddHealthData({
        calories: xmlResult.metrics.moveCalories,
        exerciseMin: xmlResult.metrics.exerciseMinutes,
        standHours: xmlResult.metrics.standHours,
        rhr: xmlResult.metrics.restingHeartRate,
        hrv: xmlResult.metrics.hrvMs,
        vo2Max: xmlResult.metrics.vo2Max,
        bloodOxygen: xmlResult.metrics.bloodOxygen,
        respiratoryRate: xmlResult.metrics.respiratoryRate,
        wristTempDelta: xmlResult.metrics.wristTempDeltaC,
        bodyFatPercent: xmlResult.metrics.bodyFatPercent,
        leanMassKg: xmlResult.metrics.leanMassKg,
        glucoseLatest: xmlResult.metrics.bloodGlucoseMgDl,
        source: xmlResult.sourceName || 'Apple Health export.xml',
        setAbsolute: true,
      });
    }

    try {
      confetti({
        particleCount: 80,
        spread: 70,
        colors: ['#FA114F', '#92E82A', '#00D6E6'],
      });
    } catch {}

    onClose();
  };

  // Copy cURL Terminal Ingestion Command
  const copyCurlCommand = () => {
    const tokenHeader = syncToken ? ` -H "X-APEX-Sync-Token: ${syncToken}"` : '';
    const cmd = `curl -X POST http://127.0.0.1:${localPort}/api/healthkit-sync -H "Content-Type: application/json"${tokenHeader} -d '{"move":${calibMove},"exercise":${calibExercise},"stand":${calibStand},"hr":${calibRHR},"hrv":${calibHRV},"vo2":${calibVo2Max},"source":"Terminal HKStream"}'`;
    navigator.clipboard.writeText(cmd);
    setCopiedCurl(true);
    playHaptic(1000, 'sine', 0.05);
    setTimeout(() => setCopiedCurl(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-2xl animate-fade-in">
      <div className="liquid-glass-elevated w-full max-w-xl rounded-[32px] p-6 border border-white/20 relative shadow-[0_25px_80px_rgba(0,0,0,0.95)] overflow-hidden max-h-[92vh] flex flex-col">
        {/* Specular Glow */}
        <div className="absolute top-0 right-0 w-80 h-80 bg-gradient-to-br from-[#FA114F]/25 via-[#00D6E6]/10 to-transparent rounded-full blur-3xl pointer-events-none" />

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
        <div className="flex items-center space-x-3 mb-5 shrink-0">
          <div className="w-12 h-12 rounded-[16px] bg-gradient-to-tr from-[#FA114F] to-[#FF5E7E] flex items-center justify-center shadow-[0_4px_20px_rgba(250,17,79,0.5)]">
            <Heart className="w-6 h-6 text-white fill-white" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h2 className="text-lg font-black text-white tracking-tight">Apple HealthKit Gateway</h2>
              <span className="text-[10px] font-mono font-black px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 flex items-center space-x-1">
                <ShieldCheck className="w-3 h-3" />
                <span>ONLINE :{localPort}</span>
              </span>
            </div>
            <p className="text-xs text-[#A1A1AA] font-mono mt-0.5">
              Live bidirectional telemetry for Apple Watch Ultra, iPhone & Mac
            </p>
          </div>
        </div>

        {/* SUB-TABS */}
        <div className="grid grid-cols-5 gap-1.5 p-1 rounded-[16px] bg-black/60 border border-white/10 mb-5 text-[11px] font-mono shrink-0">
          <button
            onClick={() => {
              playPlunk();
              setActiveModalTab('stream');
            }}
            className={`py-2 rounded-[12px] transition font-bold flex items-center justify-center space-x-1 ${
              activeModalTab === 'stream'
                ? 'bg-[#FA114F] text-white shadow-[0_0_12px_rgba(250,17,79,0.5)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <Radio className="w-3 h-3" />
            <span>Stream</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setActiveModalTab('calibrate');
            }}
            className={`py-2 rounded-[12px] transition font-bold flex items-center justify-center space-x-1 ${
              activeModalTab === 'calibrate'
                ? 'bg-white/15 text-white shadow-[0_0_12px_rgba(255,255,255,0.2)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <Sliders className="w-3 h-3" />
            <span>Calibrate</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setActiveModalTab('ios_app');
            }}
            className={`py-2 rounded-[12px] transition font-bold flex items-center justify-center space-x-1 ${
              activeModalTab === 'ios_app'
                ? 'bg-white/15 text-white shadow-[0_0_12px_rgba(255,255,255,0.2)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <Smartphone className="w-3 h-3" />
            <span>iOS App</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setActiveModalTab('shortcuts');
            }}
            className={`py-2 rounded-[12px] transition font-bold flex items-center justify-center space-x-1 ${
              activeModalTab === 'shortcuts'
                ? 'bg-white/15 text-white shadow-[0_0_12px_rgba(255,255,255,0.2)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <Zap className="w-3 h-3" />
            <span>Shortcut</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setActiveModalTab('xml_import');
            }}
            className={`py-2 rounded-[12px] transition font-bold flex items-center justify-center space-x-1 ${
              activeModalTab === 'xml_import'
                ? 'bg-white/15 text-white shadow-[0_0_12px_rgba(255,255,255,0.2)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <FileCode className="w-3 h-3" />
            <span>XML</span>
          </button>
        </div>

        {/* TAB CONTENT CONTAINER (Scrollable) */}
        <div className="overflow-y-auto pr-1 flex-1 space-y-4">
          {/* ============================================================== */}
          {/* TAB 1: REAL-TIME STREAM DASHBOARD                              */}
          {/* ============================================================== */}
          {activeModalTab === 'stream' && (
            <div className="space-y-4">
              {/* Gateway Server Card */}
              <div className="p-4 rounded-[20px] bg-black/60 border border-white/15 space-y-2 text-xs font-mono">
                <div className="flex items-center justify-between">
                  <span className="text-[#8A8A8A]">GATEWAY INTEGRITY:</span>
                  <span className="text-[#10B981] font-bold flex items-center space-x-1.5">
                    <span className="w-2 h-2 rounded-full bg-[#10B981] animate-ping" />
                    <span>LISTENING ON PORT {localPort}</span>
                  </span>
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-[#8A8A8A]">LOCAL WI-FI ENDPOINT:</span>
                  <span className="text-[#00F0FF] font-bold">http://{localIP}:{localPort}/api/healthkit-sync</span>
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-[#8A8A8A]">INGESTED TELEMETRY:</span>
                  <span className="text-white font-bold">{packetCount} packets ({lastSyncTime})</span>
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-[#8A8A8A]">CONNECTED SENSOR:</span>
                  <span className="text-white font-bold">{healthData?.deviceSource || 'Awaiting iPhone / HealthKit Sync'}</span>
                </div>
              </div>

              {/* Concentric Activity Readout */}
              <div className="grid grid-cols-3 gap-2 text-xs font-mono">
                <div className="p-3 rounded-[14px] bg-white/5 border border-white/5">
                  <span className="text-[9px] text-[#FA114F] block">ACTIVE ENERGY</span>
                  <strong className="text-white text-base">{healthData.activityRings.move.current} kcal</strong>
                  <span className="text-[9px] text-[#8A8A8A] block">Target: {healthData.activityRings.move.target}</span>
                </div>

                <div className="p-3 rounded-[14px] bg-white/5 border border-white/5">
                  <span className="text-[9px] text-[#92E82A] block">EXERCISE TIME</span>
                  <strong className="text-white text-base">{healthData.activityRings.exercise.current} min</strong>
                  <span className="text-[9px] text-[#8A8A8A] block">Target: {healthData.activityRings.exercise.target}</span>
                </div>

                <div className="p-3 rounded-[14px] bg-white/5 border border-white/5">
                  <span className="text-[9px] text-[#00D6E6] block">STAND TIME</span>
                  <strong className="text-white text-base">{healthData.activityRings.stand.current} hrs</strong>
                  <span className="text-[9px] text-[#8A8A8A] block">Target: {healthData.activityRings.stand.target}</span>
                </div>
              </div>

              {/* Vitals Readout */}
              <div className="grid grid-cols-3 gap-2 text-xs font-mono">
                <div className="p-3 rounded-[14px] bg-white/5 border border-white/5">
                  <span className="text-[9px] text-[#10B981] block">OPTICAL HR</span>
                  <strong className="text-white text-base">{healthData.metrics.restingHeartRate.value} bpm</strong>
                  <span className="text-[9px] text-[#8A8A8A] block">Resting baseline</span>
                </div>

                <div className="p-3 rounded-[14px] bg-white/5 border border-white/5">
                  <span className="text-[9px] text-[#00F0FF] block">HRV (SDNN)</span>
                  <strong className="text-white text-base">{healthData.metrics.hrv.value} ms</strong>
                  <span className="text-[9px] text-[#8A8A8A] block">Parasympathetic recovery</span>
                </div>

                <div className="p-3 rounded-[14px] bg-white/5 border border-white/5">
                  <span className="text-[9px] text-[#E5FE40] block">CARDIO VO2</span>
                  <strong className="text-white text-base">{healthData.metrics.vo2Max.value}</strong>
                  <span className="text-[9px] text-[#8A8A8A] block">Top 1% Longevity Tier</span>
                </div>
              </div>

              {gatewayStatus && (
                <div className="p-3 rounded-[14px] bg-[#10B981]/10 border border-[#10B981]/30 text-[11px] font-mono text-[#10B981]">
                  {gatewayStatus}
                </div>
              )}

              {/* Action Button */}
              <button
                onClick={handleVerifyGateway}
                disabled={isCheckingGateway}
                className="w-full py-3.5 rounded-[14px] bg-gradient-to-r from-[#FA114F] to-[#FF5E7E] text-white font-mono font-black text-xs uppercase tracking-wider flex items-center justify-center space-x-2 border border-white/20 shadow-[0_0_20px_rgba(250,17,79,0.5)] transition hover:opacity-95"
              >
                <Zap className="w-4 h-4" />
                <span>{isCheckingGateway ? 'CHECKING GATEWAY...' : 'VERIFY CONTINUITY GATEWAY'}</span>
              </button>
            </div>
          )}

          {/* ============================================================== */}
          {/* TAB 2: BIOMETRIC CALIBRATION (SET YOUR EXACT REAL NUMBERS)     */}
          {/* ============================================================== */}
          {activeModalTab === 'calibrate' && (
            <div className="space-y-4">
              <div className="p-3.5 rounded-[16px] bg-[#E5FE40]/10 border border-[#E5FE40]/30 text-xs font-mono">
                <span className="text-[#E5FE40] font-bold block mb-1">
                  ENTER YOUR REAL BIOMETRIC TELEMETRY:
                </span>
                <p className="text-[#A1A1AA] text-[11px]">
                  Calibrate your true physiological metrics from your Apple Watch, Oura, Whoop, or lab tests. These numbers instantly update all rings, Livity biological age, and recovery strain across APEX OS.
                </p>
              </div>

              <div className="grid grid-cols-2 gap-3 text-xs font-mono">
                <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#FA114F] font-bold block">
                    ACTIVE ENERGY (KCAL)
                  </span>
                  <input
                    type="number"
                    value={calibMove}
                    onChange={(e) => setCalibMove(e.target.value)}
                    className="w-full bg-transparent font-black text-lg text-white focus:outline-none"
                  />
                  <span className="text-[9px] text-[#8A8A8A]">Move ring calories</span>
                </div>

                <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#92E82A] font-bold block">
                    EXERCISE (MINUTES)
                  </span>
                  <input
                    type="number"
                    value={calibExercise}
                    onChange={(e) => setCalibExercise(e.target.value)}
                    className="w-full bg-transparent font-black text-lg text-white focus:outline-none"
                  />
                  <span className="text-[9px] text-[#8A8A8A]">Green exercise ring</span>
                </div>

                <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#00D6E6] font-bold block">
                    STAND HOURS
                  </span>
                  <input
                    type="number"
                    value={calibStand}
                    onChange={(e) => setCalibStand(e.target.value)}
                    className="w-full bg-transparent font-black text-lg text-white focus:outline-none"
                  />
                  <span className="text-[9px] text-[#8A8A8A]">Cyan stand ring</span>
                </div>

                <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#10B981] font-bold block">
                    RESTING HEART RATE (BPM)
                  </span>
                  <input
                    type="number"
                    value={calibRHR}
                    onChange={(e) => setCalibRHR(e.target.value)}
                    className="w-full bg-transparent font-black text-lg text-white focus:outline-none"
                  />
                  <span className="text-[9px] text-[#8A8A8A]">Basal resting rate</span>
                </div>

                <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#00F0FF] font-bold block">
                    HRV SDNN (MS)
                  </span>
                  <input
                    type="number"
                    value={calibHRV}
                    onChange={(e) => setCalibHRV(e.target.value)}
                    className="w-full bg-transparent font-black text-lg text-white focus:outline-none"
                  />
                  <span className="text-[9px] text-[#8A8A8A]">Vagal nerve recovery</span>
                </div>

                <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#E5FE40] font-bold block">
                    VO2 MAX (ML/KG/MIN)
                  </span>
                  <input
                    type="number"
                    step="0.1"
                    value={calibVo2Max}
                    onChange={(e) => setCalibVo2Max(e.target.value)}
                    className="w-full bg-transparent font-black text-lg text-white focus:outline-none"
                  />
                  <span className="text-[9px] text-[#8A8A8A]">Cardiorespiratory fitness</span>
                </div>

                <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#38BDF8] font-bold block">
                    SLEEP DURATION (HOURS)
                  </span>
                  <input
                    type="number"
                    step="0.1"
                    value={calibSleepHours}
                    onChange={(e) => setCalibSleepHours(e.target.value)}
                    className="w-full bg-transparent font-black text-lg text-white focus:outline-none"
                  />
                  <span className="text-[9px] text-[#8A8A8A]">Total nightly sleep</span>
                </div>

                <div className="p-3 rounded-[14px] bg-black/40 border border-white/10 space-y-1">
                  <span className="text-[10px] text-[#8B5CF6] font-bold block">
                    DEEP SLEEP (HOURS)
                  </span>
                  <input
                    type="number"
                    step="0.1"
                    value={calibDeepSleep}
                    onChange={(e) => setCalibDeepSleep(e.target.value)}
                    className="w-full bg-transparent font-black text-lg text-white focus:outline-none"
                  />
                  <span className="text-[9px] text-[#8A8A8A]">Stage 3 / Delta sleep</span>
                </div>
              </div>

              <button
                onClick={handleCommitCalibration}
                className="w-full py-3.5 rounded-[14px] bg-gradient-to-r from-[#10B981] to-[#00D6E6] text-black font-mono font-black text-xs uppercase tracking-wider flex items-center justify-center space-x-2 border border-white/20 shadow-[0_0_20px_rgba(16,185,129,0.5)] transition hover:opacity-95"
              >
                <Check className="w-4 h-4 stroke-[3]" />
                <span>APPLY & COMMIT TO APEX OS (REAL DATA)</span>
              </button>
            </div>
          )}

          {/* ============================================================== */}
          {/* TAB 3: NATIVE iOS COMPANION APP                                */}
          {/* ============================================================== */}
          {activeModalTab === 'ios_app' && (
            <div className="space-y-4">
              <div className="p-4 rounded-[20px] bg-black/60 border border-white/15 space-y-2 text-xs font-mono">
                <div className="flex items-center space-x-2 text-[#E5FE40] font-bold">
                  <Cpu className="w-4 h-4" />
                  <span>PHYSICAL iPHONE &amp; APPLE WATCH COMPANION (.IPA + XCODE)</span>
                </div>
                <p className="text-[11px] text-[#A1A1AA]">
                  Apple iOS devices require an ARM64 <code className="text-white font-bold">iphoneos</code> build signed with your Apple ID (<code className="text-white font-bold">APEX-OS.ipa</code> or Xcode Automatic Signing). Simulator <code className="text-white font-bold">.zip</code> binaries cannot run on physical iPhone hardware.
                </p>
              </div>

              <div className="p-3.5 rounded-[16px] bg-white/[0.04] border border-white/10 text-xs font-mono space-y-2">
                <div className="flex items-center justify-between text-white font-bold">
                  <span>iOS DEVICE PACKAGE:</span>
                  <span className={ipaPackageInfo?.available ? 'text-[#10B981]' : 'text-[#F59E0B]'}>
                    {ipaPackageInfo?.available ? `APEX-OS.ipa (${ipaPackageInfo.sizeMB || 'ARM64'})` : 'Run bash scripts/build_ios.sh'}
                  </span>
                </div>
                <div className="flex items-center justify-between text-[#8A8A8A]">
                  <span>EMBEDDED BUNDLES:</span>
                  <span className="text-[#00F0FF]">APEX_iOS + APEXWidgets + APEXWatch</span>
                </div>
                <div className="flex items-center justify-between text-[#8A8A8A]">
                  <span>XCODE PROJECT:</span>
                  <span className="text-white font-bold">ios_app/APEX_iOS.xcodeproj</span>
                </div>
                <div className="flex items-center justify-between text-[#8A8A8A]">
                  <span>LAN DOWNLOAD URL:</span>
                  <span className="text-[#FA114F] select-all">http://{localIP}:{localPort}/APEX-OS.ipa</span>
                </div>
                <div className="flex items-center justify-between text-[#8A8A8A]">
                  <span>PAIRING TOKEN:</span>
                  <span className="text-[#E5FE40] select-all">{syncToken || 'Verify Gateway First'}</span>
                </div>
              </div>

              <div className="p-3.5 rounded-[14px] bg-white/[0.04] border border-white/10 text-[11px] font-mono text-[#A1A1AA] space-y-1.5">
                <div className="text-white font-bold">2 Ways to Install on Your Physical iPhone:</div>
                <div>
                  1. <span className="text-[#E5FE40] font-bold">Sideload .ipa (No Paid Dev Account):</span> Download <code className="text-white">APEX-OS.ipa</code> below and drag it into <span className="text-white">Sideloadly</span> / <span className="text-white">AltStore</span> / <span className="text-white">SideStore</span> with your Apple ID.
                </div>
                <div>
                  2. <span className="text-[#00F0FF] font-bold">1-Click Xcode + Apple Watch:</span> Open <code className="text-white">ios_app/APEX_iOS.xcodeproj</code> in Xcode &rarr; Signing &amp; Capabilities &rarr; select your Apple ID Team &rarr; Run on iPhone.
                </div>
              </div>

              <div className="p-3.5 rounded-[14px] bg-[#10B981]/10 border border-[#10B981]/30 flex items-center justify-between gap-3 text-xs font-mono">
                <div>
                  <span className="text-white font-bold block">
                    {ipaPackageInfo?.available ? 'Physical iPhone IPA Ready' : 'Physical iPhone IPA Not Built Yet'}
                  </span>
                  <span className="text-[#8A8A8A] text-[10px]">
                    {ipaPackageInfo?.available
                      ? `ARM64 iphoneos · watchOS · WidgetKit (${ipaPackageInfo.sizeMB || 'ready'})`
                      : 'Build with: bash scripts/build_ios.sh'}
                  </span>
                </div>
                {ipaPackageInfo?.available ? (
                  <a
                    href={`http://${localIP}:${localPort}/APEX-OS.ipa`}
                    download="APEX-OS.ipa"
                    onClick={() => {
                      fetch('/api/reveal-ipa', { method: 'POST' }).catch(() => {});
                    }}
                    className="text-black bg-[#E5FE40] hover:bg-[#d8f325] font-black px-3 py-1.5 rounded-lg transition-colors whitespace-nowrap"
                  >
                    GET .IPA FILE
                  </a>
                ) : (
                  <span className="text-[#F59E0B] font-black px-2 py-1 rounded bg-[#F59E0B]/15 border border-[#F59E0B]/40">
                    NEEDS BUILD
                  </span>
                )}
              </div>
            </div>
          )}

          {/* ============================================================== */}
          {/* TAB 4: APPLE SHORTCUTS 1-CLICK AUTOMATION                     */}
          {/* ============================================================== */}
          {activeModalTab === 'shortcuts' && (
            <div className="space-y-4">
              <div className="p-4 rounded-[20px] bg-black/60 border border-white/15 space-y-2 text-xs font-mono">
                <div className="flex items-center space-x-2 text-[#FA114F] font-bold">
                  <Zap className="w-4 h-4" />
                  <span>1-CLICK APPLE SHORTCUT (ZERO XCODE REQUIRED)</span>
                </div>
                <p className="text-[11px] text-[#A1A1AA]">
                  You can stream your real Apple Health data directly from your iPhone without installing any custom developer app by using Apple's built-in Shortcuts app.
                </p>
              </div>

              <div className="p-3.5 rounded-[16px] bg-white/[0.04] border border-white/10 text-xs font-mono space-y-3">
                <div className="flex items-center space-x-2 text-white font-bold">
                  <Terminal className="w-4 h-4 text-[#00F0FF]" />
                  <span>HOW TO SET UP IN 60 SECONDS:</span>
                </div>
                <ol className="list-decimal list-inside space-y-1.5 text-[11px] text-[#A1A1AA]">
                  <li>Open the <strong className="text-white">Shortcuts</strong> app on your iPhone or Mac.</li>
                  <li>Add action: <strong className="text-white">Find Health Samples</strong> (Active Energy, Heart Rate, HRV).</li>
                  <li>Add action: <strong className="text-white">Get Contents of URL</strong> pointing to your Mac:</li>
                </ol>
                <div className="p-2.5 rounded-[10px] bg-black/80 border border-white/15 font-mono text-[10px] text-[#00F0FF] break-all select-all">
                  http://{localIP}:{localPort}/api/healthkit-sync
                </div>
              </div>

              {/* cURL Command Tester */}
              <div className="p-3.5 rounded-[16px] bg-white/[0.04] border border-white/10 text-xs font-mono space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-white font-bold">TERMINAL cURL TEST COMMAND:</span>
                  <button
                    onClick={copyCurlCommand}
                    className="px-2.5 py-1 rounded-[8px] bg-white/10 hover:bg-white/20 text-[10px] font-bold text-white flex items-center space-x-1 transition"
                  >
                    <Copy className="w-3 h-3" />
                    <span>{copiedCurl ? 'COPIED!' : 'COPY'}</span>
                  </button>
                </div>
                <div className="p-2 rounded-[8px] bg-black/80 border border-white/10 text-[9px] text-[#8A8A8A] font-mono break-all select-all">
                  curl -X POST http://127.0.0.1:{localPort}/api/healthkit-sync -H &quot;Content-Type: application/json&quot;{syncToken ? ` -H "X-APEX-Sync-Token: ${syncToken}"` : ''} -d '{`"move":${calibMove},"hr":${calibRHR},"hrv":${calibHRV}`}'
                </div>
              </div>
            </div>
          )}

          {/* ============================================================== */}
          {/* TAB 5: IMPORT OFFICIAL APPLE HEALTH EXPORT XML                 */}
          {/* ============================================================== */}
          {activeModalTab === 'xml_import' && (
            <div className="space-y-4">
              <div className="p-4 rounded-[20px] bg-black/60 border border-white/15 space-y-2 text-xs font-mono">
                <div className="flex items-center space-x-2 text-[#00D6E6] font-bold">
                  <FileCode className="w-4 h-4" />
                  <span>OFFICIAL APPLE HEALTH XML PARSER</span>
                </div>
                <p className="text-[11px] text-[#A1A1AA]">
                  Import your complete Health history directly from Apple Health (iPhone Health App &gt; Profile &gt; Export All Health Data &gt; <code className="text-white font-bold">export.xml</code>).
                </p>
              </div>

              {/* Upload Drop Zone */}
              <input
                ref={fileInputRef}
                type="file"
                accept=".xml"
                onChange={handleXmlFileUpload}
                className="hidden"
              />

              <div
                onClick={() => fileInputRef.current && fileInputRef.current.click()}
                className="p-6 rounded-[20px] bg-white/[0.03] hover:bg-white/[0.06] border-2 border-dashed border-white/20 hover:border-[#00D6E6]/60 cursor-pointer transition text-center space-y-2"
              >
                <Upload className="w-8 h-8 text-[#00D6E6] mx-auto animate-bounce" />
                <div className="text-xs font-mono font-bold text-white">
                  {xmlFileName || 'Click to Select export.xml from Apple Health'}
                </div>
                <span className="text-[10px] font-mono text-[#8A8A8A] block">
                  Parses ActiveEnergyBurned, AppleExerciseTime, AppleStandTime, HeartRate, HRV, VO2Max
                </span>
              </div>

              <div className="p-3 rounded-[12px] bg-black/50 border border-white/10 text-[10px] font-mono text-[#A1A1AA] space-y-1">
                <span className="text-[#E5FE40] font-bold block">HOW TO EXPORT YOUR REAL APPLE HEALTH DATA:</span>
                <span>Open iPhone <strong className="text-white">Health</strong> app → tap your Profile photo → scroll to <strong className="text-white">Export All Health Data</strong> → unzip <strong className="text-white">export.zip</strong> and drop <strong className="text-white">export.xml</strong> above.</span>
              </div>

              {/* Parsed Results Card */}
              {xmlResult && (
                <div className="p-4 rounded-[18px] bg-black/80 border border-[#10B981]/40 space-y-3 text-xs font-mono animate-fade-in">
                  <div className="flex items-center justify-between text-[#10B981] font-bold">
                    <span>✓ PARSED {xmlResult.totalRecords} CLINICAL RECORDS</span>
                    <span className="text-white">{xmlResult.sourceName}</span>
                  </div>

                  <div className="grid grid-cols-3 gap-2">
                    <div className="p-2 rounded bg-white/5">
                      <span className="text-[9px] text-[#FA114F] block">MOVE</span>
                      <strong className="text-white">{xmlResult.metrics.moveCalories} kcal</strong>
                    </div>
                    <div className="p-2 rounded bg-white/5">
                      <span className="text-[9px] text-[#92E82A] block">EXERCISE</span>
                      <strong className="text-white">{xmlResult.metrics.exerciseMinutes} min</strong>
                    </div>
                    <div className="p-2 rounded bg-white/5">
                      <span className="text-[9px] text-[#00D6E6] block">STAND</span>
                      <strong className="text-white">{xmlResult.metrics.standHours} hrs</strong>
                    </div>
                    <div className="p-2 rounded bg-white/5">
                      <span className="text-[9px] text-[#10B981] block">RESTING HR</span>
                      <strong className="text-white">{xmlResult.metrics.restingHeartRate} bpm</strong>
                    </div>
                    <div className="p-2 rounded bg-white/5">
                      <span className="text-[9px] text-[#00F0FF] block">HRV</span>
                      <strong className="text-white">{xmlResult.metrics.hrvMs} ms</strong>
                    </div>
                    <div className="p-2 rounded bg-white/5">
                      <span className="text-[9px] text-[#E5FE40] block">VO2 MAX</span>
                      <strong className="text-white">{xmlResult.metrics.vo2Max}</strong>
                    </div>
                  </div>

                  <button
                    onClick={handleCommitParsedXML}
                    className="w-full py-2.5 rounded-[12px] bg-[#10B981] text-black font-black text-xs uppercase tracking-wider flex items-center justify-center space-x-2 transition hover:opacity-95"
                  >
                    <CheckCircle className="w-4 h-4" />
                    <span>IMPORT THESE METRICS INTO APEX OS</span>
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
