import React, { useState, useEffect } from 'react';
import {
  Activity,
  ShieldCheck,
  Heart,
  Sparkles,
  RefreshCw,
  ChevronRight,
  TrendingDown,
  Dumbbell,
  Flame,
  Moon,
  Footprints,
  Zap,
  Sliders,
  CheckCircle2
} from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const readSavedLabs = () => {
  try {
    return JSON.parse(localStorage.getItem('apex_user_bloodwork') || '[]');
  } catch {
    return [];
  }
};

export default function PhenoAgeCalculator({ healthData, onConnectHealth, onOpenBloodwork }) {
  const [activeEngine, setActiveEngine] = useState('livity_fitness'); // 'livity_fitness' | 'morgan_levine'
  const [hasUserSimulated, setHasUserSimulated] = useState(false);
  const [hasRealLabs, setHasRealLabs] = useState(() => readSavedLabs().length > 0);
  const [chronoAge, setChronoAge] = useState(() => {
    if (healthData?.chronologicalAge > 0) return healthData.chronologicalAge;
    try {
      const savedUser = JSON.parse(localStorage.getItem('apex_user_profile') || '{}');
      return savedUser.age || 28;
    } catch {
      return 28;
    }
  });

  // Livity 8 Key Metrics State (seeded ONLY from synced Apple Health telemetry, or honest baselines until synced)
  const [vo2Max, setVo2Max] = useState(healthData?.metrics?.vo2Max?.value || 42);
  const [restingHR, setRestingHR] = useState(healthData?.metrics?.restingHeartRate?.value || 62);
  const [hrvSDNN, setHrvSDNN] = useState(healthData?.metrics?.hrv?.value || 55);
  const [sleepHours, setSleepHours] = useState(healthData?.metrics?.sleep?.totalHours || 7.2);
  const [dailySteps, setDailySteps] = useState(Number(String(healthData?.metrics?.steps?.value || '0').replace(/,/g, '')) || 6500);
  const [modActivityMin, setModActivityMin] = useState(healthData?.activityRings?.exercise?.current || 20);
  const [vigActivityMin, setVigActivityMin] = useState(10);
  const [strengthSessions, setStrengthSessions] = useState(2);

  // Morgan Levine Clinical Blood Panel State (populated from apex_user_bloodwork or iPhone Bloodwork OCR)
  const [albumin, setAlbumin] = useState(4.5);
  const [creatinine, setCreatinine] = useState(0.92);
  const [glucose, setGlucose] = useState(85);
  const [hsCRP, setHsCRP] = useState(0.5);
  const [lymphPct, setLymphPct] = useState(30);
  const [mcv, setMcv] = useState(89.0);
  const [rdw, setRdw] = useState(12.3);
  const [alkPhos, setAlkPhos] = useState(64);
  const [wbc, setWbc] = useState(5.4);

  useEffect(() => {
    if (healthData?.chronologicalAge > 0) setChronoAge(healthData.chronologicalAge);
    if (healthData?.metrics?.vo2Max?.value > 0) setVo2Max(healthData.metrics.vo2Max.value);
    if (healthData?.metrics?.restingHeartRate?.value > 0) setRestingHR(healthData.metrics.restingHeartRate.value);
    if (healthData?.metrics?.hrv?.value > 0) setHrvSDNN(healthData.metrics.hrv.value);
    if (healthData?.metrics?.sleep?.totalHours > 0) setSleepHours(healthData.metrics.sleep.totalHours);
    const parsedSteps = Number(String(healthData?.metrics?.steps?.value || '0').replace(/,/g, ''));
    if (parsedSteps > 0) setDailySteps(parsedSteps);
    if (healthData?.activityRings?.exercise?.current > 0) setModActivityMin(healthData.activityRings.exercise.current);
  }, [healthData]);

  useEffect(() => {
    const syncLabs = () => {
      const labs = readSavedLabs();
      setHasRealLabs(labs.length > 0);
      labs.forEach((lab) => {
        const name = (lab.test || '').toLowerCase();
        const val = Number(lab.val);
        if (isNaN(val)) return;
        if (name.includes('albumin')) setAlbumin(val);
        else if (name.includes('creatinine')) setCreatinine(val);
        else if (name.includes('glucose')) setGlucose(val);
        else if (name.includes('crp')) setHsCRP(val);
        else if (name.includes('lymph')) setLymphPct(val);
        else if (name.includes('mcv')) setMcv(val);
        else if (name.includes('rdw')) setRdw(val);
        else if (name.includes('alk')) setAlkPhos(val);
        else if (name.includes('wbc')) setWbc(val);
      });
    };
    syncLabs();
    window.addEventListener('apex:bloodwork-updated', syncLabs);
    window.addEventListener('appleHealthSync', syncLabs);
    return () => {
      window.removeEventListener('apex:bloodwork-updated', syncLabs);
      window.removeEventListener('appleHealthSync', syncLabs);
    };
  }, []);

  // Livity Fitness Age Calculation (Based on 8 Key Health Metrics)
  const calculateLivityFitnessAge = () => {
    let delta = 0;

    // 1. VO2 Max (Base: 42 mL/kg/min for 29yo)
    delta -= (vo2Max - 42) * 0.45;

    // 2. Resting Heart Rate (Base: 65 bpm)
    delta += (restingHR - 60) * 0.25;

    // 3. HRV SDNN (Base: 50 ms)
    delta -= (hrvSDNN - 50) * 0.12;

    // 4. Sleep Hours (Optimal: 7.5 - 8.5)
    if (sleepHours >= 7.5 && sleepHours <= 8.5) delta -= 1.8;
    else if (sleepHours < 6) delta += 2.5;

    // 5. Daily Steps (Base: 8000)
    delta -= ((dailySteps - 8000) / 2000) * 0.6;

    // 6. Moderate Zone 2 Activity (min/day)
    delta -= (modActivityMin / 15) * 0.5;

    // 7. Vigorous Zone 4/5 Activity (min/day)
    delta -= (vigActivityMin / 10) * 0.6;

    // 8. Strength Training (sessions/week)
    delta -= (strengthSessions - 2) * 0.8;

    const fitnessAge = chronoAge + delta;
    return Math.max(18.0, Number(fitnessAge.toFixed(1)));
  };

  // Morgan Levine PhenoAge Algorithm approximation
  const calculatePhenoAge = () => {
    const b0 = -19.907;
    const bAlb = -0.0336 * albumin * 10;
    const bCreat = 0.0095 * creatinine * 88.4;
    const bGlu = 0.1953 * (glucose / 18.0);
    const bCRP = 0.0804 * Math.log(hsCRP + 0.1);
    const bLymph = -0.0125 * lymphPct;
    const bMCV = 0.0268 * mcv;
    const bRDW = 0.3306 * rdw;
    const bAlk = 0.0019 * alkPhos;
    const bWBC = 0.0554 * wbc;
    const bAge = 0.0804 * chronoAge;

    const xb = b0 + bAlb + bCreat + bGlu + bCRP + bLymph + bMCV + bRDW + bAlk + bWBC + bAge;
    const gamma = 0.0077;
    const mortScore = 1 - Math.exp(-Math.exp(xb) * (Math.exp(gamma * 120) - 1) / gamma);
    const phenoAge = 141.50 + Math.log(-0.00553 * Math.log(1 - mortScore)) / 0.090165;

    return Math.max(18, Math.min(chronoAge + 15, Number(phenoAge.toFixed(1))));
  };

  const livityAge = calculateLivityFitnessAge();
  const phenoAge = calculatePhenoAge();

  const currentAge = activeEngine === 'livity_fitness' ? livityAge : phenoAge;
  const ageDelta = +(currentAge - chronoAge).toFixed(1);
  const isReversed = ageDelta < 0;
  const hasRealHealthVitals = (healthData?.metrics?.hrv?.value || 0) > 0 || (healthData?.metrics?.restingHeartRate?.value || 0) > 0 || (healthData?.metrics?.vo2Max?.value || 0) > 0;
  const showActiveMetrics = activeEngine === 'livity_fitness' ? (hasRealHealthVitals || hasUserSimulated) : (hasRealLabs || hasUserSimulated);

  return (
    <div className="space-y-6">
      {!showActiveMetrics && (
        <div className="liquid-glass rounded-[20px] p-4 border border-[#10B981]/30 flex flex-wrap items-center justify-between gap-3 text-xs font-mono">
          <div>
            <span className="text-[#10B981] font-black block">
              {activeEngine === 'livity_fitness' ? 'CONNECT APPLE HEALTH FOR REAL FITNESS AGE' : 'UPLOAD BLOODWORK OR SCAN LAB SHEET ON IPHONE'}
            </span>
            <span className="text-[#A1A1AA]">
              {activeEngine === 'livity_fitness'
                ? 'Waiting for your real VO2 Max, RHR, HRV & Sleep from Apple Health — or drag sliders below to test scenarios.'
                : 'No lab PDF/CSV or blood chemistry entered yet. Upload labs or adjust sliders below to compute Levine PhenoAge.'}
            </span>
          </div>
          <div className="flex items-center space-x-2">
            {activeEngine === 'livity_fitness' && onConnectHealth && (
              <button
                onClick={() => {
                  playPlunk();
                  onConnectHealth();
                }}
                className="px-3.5 py-2 rounded-[10px] bg-[#10B981] text-black font-black"
              >
                CONNECT APPLE HEALTH
              </button>
            )}
            {activeEngine === 'morgan_levine' && onOpenBloodwork && (
              <button
                onClick={() => {
                  playPlunk();
                  onOpenBloodwork();
                }}
                className="px-3.5 py-2 rounded-[10px] bg-[#00F0FF] text-black font-black"
              >
                UPLOAD LABS
              </button>
            )}
          </div>
        </div>
      )}

      {/* HERO BIOLOGICAL / FITNESS AGE READOUT */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/20 relative overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 rounded-[16px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
              <Activity className="w-6 h-6 text-[#10B981]" />
            </div>
            <div>
              <span className="text-[10px] font-mono text-[#10B981] font-black uppercase tracking-widest">
                {activeEngine === 'livity_fitness' ? 'LIVITY 8-METRIC BIOLOGICAL ENGINE' : 'MORGAN LEVINE PHENOAGE ALGORITHM'}
              </span>
              <h3 className="text-lg font-bold text-white tracking-tight">
                {activeEngine === 'livity_fitness' ? 'Cardiorespiratory & Biological Fitness Age' : 'Clinical Epigenetic Clock Calculator'}
              </h3>
            </div>
          </div>

          <div className="text-right">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">
              {activeEngine === 'livity_fitness' ? 'FITNESS AGE' : 'BIOLOGICAL AGE'}
            </span>
            <div className="flex items-baseline justify-end space-x-2">
              <span className="text-4xl font-mono font-black text-white">{showActiveMetrics ? currentAge : '—'}</span>
              <span className="text-xs font-mono text-[#8A8A8A]">{showActiveMetrics ? 'years' : ''}</span>
            </div>
            <span className="text-xs font-mono font-black text-[#10B981] block">
              {!showActiveMetrics
                ? 'Awaiting real telemetry'
                : isReversed
                ? `${Math.abs(ageDelta)} YEARS YOUNGER`
                : `+${ageDelta} Years Advanced`}
            </span>
            <button
              onClick={() => {
                playPlunk();
                window.print();
              }}
              className="mt-2 px-3 py-1 rounded-[8px] bg-white/10 hover:bg-white/20 text-[10px] font-mono font-bold text-white border border-white/15 transition"
            >
              PRINT CLINICAL DOSSIER
            </button>
          </div>
        </div>

        {/* Engine Switcher Tabs */}
        <div className="grid grid-cols-2 gap-2 p-1 rounded-[16px] bg-black/60 border border-white/10 mb-4 text-xs font-mono">
          <button
            onClick={() => {
              playPlunk();
              setActiveEngine('livity_fitness');
            }}
            className={`py-2 rounded-[12px] font-bold transition flex items-center justify-center space-x-2 ${
              activeEngine === 'livity_fitness'
                ? 'bg-[#10B981] text-black font-black shadow-[0_0_12px_rgba(16,185,129,0.4)]'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <Flame className="w-3.5 h-3.5" />
            <span>LIVITY 8-METRIC FITNESS AGE</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setActiveEngine('morgan_levine');
            }}
            className={`py-2 rounded-[12px] font-bold transition flex items-center justify-center space-x-2 ${
              activeEngine === 'morgan_levine'
                ? 'bg-[#00F0FF] text-black font-black shadow-[0_0_12px_rgba(0,240,255,0.4)]'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>MORGAN LEVINE PHENOAGE (BLOOD LABS)</span>
          </button>
        </div>

        <div className="p-3.5 rounded-[16px] bg-black/50 border border-white/10 flex items-center justify-between text-xs font-mono">
          <div className="flex items-center space-x-2">
            <ShieldCheck className="w-4 h-4 text-[#00F0FF]" />
            <span className="text-white">
              {activeEngine === 'livity_fitness'
                ? 'Fitness age computed from VO2 Max, Sleep, Resting HR & Workouts'
                : 'Morgan Levine (2018) 9-biomarker clinical epigenetic age equation'}
            </span>
          </div>
          <span className="text-[#10B981] font-bold">
            {showActiveMetrics ? (hasUserSimulated && !hasRealHealthVitals && !hasRealLabs ? 'WHAT-IF SIMULATION' : 'MEASURED DATA') : 'AWAITING SYNC'}
          </span>
        </div>
      </div>

      {/* ============================================================== */}
      {/* ENGINE 1: LIVITY 8-METRIC FITNESS AGE CONTROLS                 */}
      {/* ============================================================== */}
      {activeEngine === 'livity_fitness' && (
        <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
          <div className="flex items-center justify-between">
            <h4 className="text-xs font-mono font-black text-[#E5FE40] uppercase tracking-wider">
              8 LIVITY LONGEVITY BIOMARKERS (REAL-TIME APPLE WATCH SYNCED)
            </h4>
            <span className="text-[11px] font-mono text-[#8A8A8A]">Adjust sliders to simulate progress</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3.5">
            {/* 1. VO2 Max */}
            <div className="space-y-1.5 p-3.5 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold flex items-center space-x-1">
                  <Zap className="w-3 h-3 text-[#FA114F]" />
                  <span>VO₂ Max</span>
                </span>
                <span className="text-[#FA114F] font-black">{vo2Max} mL/kg</span>
              </div>
              <input
                type="range"
                min="30"
                max="75"
                step="0.5"
                value={vo2Max}
                onChange={(e) => { setHasUserSimulated(true); setVo2Max(Number(e.target.value)); }}
                className="w-full accent-[#FA114F]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Cardiorespiratory capacity indicator</span>
            </div>

            {/* 2. Resting HR */}
            <div className="space-y-1.5 p-3.5 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold flex items-center space-x-1">
                  <Heart className="w-3 h-3 text-[#10B981]" />
                  <span>Resting HR</span>
                </span>
                <span className="text-[#10B981] font-black">{restingHR} bpm</span>
              </div>
              <input
                type="range"
                min="38"
                max="85"
                step="1"
                value={restingHR}
                onChange={(e) => { setHasUserSimulated(true); setRestingHR(Number(e.target.value)); }}
                className="w-full accent-[#10B981]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Athletic Bradycardia Baseline</span>
            </div>

            {/* 3. HRV SDNN */}
            <div className="space-y-1.5 p-3.5 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold flex items-center space-x-1">
                  <Activity className="w-3 h-3 text-[#00F0FF]" />
                  <span>HRV (SDNN)</span>
                </span>
                <span className="text-[#00F0FF] font-black">{hrvSDNN} ms</span>
              </div>
              <input
                type="range"
                min="20"
                max="160"
                step="1"
                value={hrvSDNN}
                onChange={(e) => { setHasUserSimulated(true); setHrvSDNN(Number(e.target.value)); }}
                className="w-full accent-[#00F0FF]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Autonomic Vagal Resilience</span>
            </div>

            {/* 4. Sleep Duration */}
            <div className="space-y-1.5 p-3.5 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold flex items-center space-x-1">
                  <Moon className="w-3 h-3 text-[#38BDF8]" />
                  <span>Sleep Time</span>
                </span>
                <span className="text-[#38BDF8] font-black">{sleepHours} hrs</span>
              </div>
              <input
                type="range"
                min="4"
                max="10"
                step="0.1"
                value={sleepHours}
                onChange={(e) => { setHasUserSimulated(true); setSleepHours(Number(e.target.value)); }}
                className="w-full accent-[#38BDF8]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Deep & REM restorative phase</span>
            </div>

            {/* 5. Daily Steps */}
            <div className="space-y-1.5 p-3.5 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold flex items-center space-x-1">
                  <Footprints className="w-3 h-3 text-[#E5FE40]" />
                  <span>Daily Steps</span>
                </span>
                <span className="text-[#E5FE40] font-black">{dailySteps.toLocaleString()}</span>
              </div>
              <input
                type="range"
                min="3000"
                max="25000"
                step="500"
                value={dailySteps}
                onChange={(e) => { setHasUserSimulated(true); setDailySteps(Number(e.target.value)); }}
                className="w-full accent-[#E5FE40]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Non-exercise activity thermogenesis</span>
            </div>

            {/* 6. Moderate Zone 2 */}
            <div className="space-y-1.5 p-3.5 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold flex items-center space-x-1">
                  <Flame className="w-3 h-3 text-[#F59E0B]" />
                  <span>Zone 2 Cardio</span>
                </span>
                <span className="text-[#F59E0B] font-black">{modActivityMin} min/day</span>
              </div>
              <input
                type="range"
                min="0"
                max="90"
                step="5"
                value={modActivityMin}
                onChange={(e) => { setHasUserSimulated(true); setModActivityMin(Number(e.target.value)); }}
                className="w-full accent-[#F59E0B]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Mitochondrial lipid oxidation</span>
            </div>

            {/* 7. Vigorous Zone 4/5 */}
            <div className="space-y-1.5 p-3.5 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold flex items-center space-x-1">
                  <Zap className="w-3 h-3 text-[#EC4899]" />
                  <span>Zone 4/5 HIIT</span>
                </span>
                <span className="text-[#EC4899] font-black">{vigActivityMin} min/day</span>
              </div>
              <input
                type="range"
                min="0"
                max="60"
                step="5"
                value={vigActivityMin}
                onChange={(e) => { setHasUserSimulated(true); setVigActivityMin(Number(e.target.value)); }}
                className="w-full accent-[#EC4899]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Myocardial contractile output</span>
            </div>

            {/* 8. Strength Sessions */}
            <div className="space-y-1.5 p-3.5 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold flex items-center space-x-1">
                  <Dumbbell className="w-3 h-3 text-[#A855F7]" />
                  <span>Strength</span>
                </span>
                <span className="text-[#A855F7] font-black">{strengthSessions} days/wk</span>
              </div>
              <input
                type="range"
                min="0"
                max="7"
                step="1"
                value={strengthSessions}
                onChange={(e) => { setHasUserSimulated(true); setStrengthSessions(Number(e.target.value)); }}
                className="w-full accent-[#A855F7]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Bone mineral density & myokines</span>
            </div>
          </div>
        </div>
      )}

      {/* ============================================================== */}
      {/* ENGINE 2: MORGAN LEVINE PHENOAGE BLOOD LAB PANEL               */}
      {/* ============================================================== */}
      {activeEngine === 'morgan_levine' && (
        <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
          <div className="flex items-center justify-between">
            <h4 className="text-xs font-mono font-black text-[#00F0FF] uppercase tracking-wider">
              CLINICAL BLOOD CHEMISTRY PANEL (9 BIOMARKERS)
            </h4>
            <span className="text-[11px] font-mono text-[#8A8A8A]">Slide to simulate interventions</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
            <div className="space-y-1.5 p-3 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold">Albumin</span>
                <span className="text-[#00F0FF]">{albumin} g/dL</span>
              </div>
              <input
                type="range"
                min="3.5"
                max="5.5"
                step="0.1"
                value={albumin}
                onChange={(e) => { setHasUserSimulated(true); setAlbumin(Number(e.target.value)); }}
                className="w-full accent-[#00F0FF]"
              />
              <span className="text-[10px] text-[#8A8A8A] block">Liver synthesis & osmotic pressure</span>
            </div>

            <div className="space-y-1.5 p-3 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold">hs-CRP (Inflammation)</span>
                <span className="text-[#FA114F]">{hsCRP} mg/L</span>
              </div>
              <input
                type="range"
                min="0.1"
                max="3.0"
                step="0.05"
                value={hsCRP}
                onChange={(e) => { setHasUserSimulated(true); setHsCRP(Number(e.target.value)); }}
                className="w-full accent-[#FA114F]"
              />
              <span className="text-[10px] text-[#8A8A8A] block">Systemic vascular inflammatory load</span>
            </div>

            <div className="space-y-1.5 p-3 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold">Fasting Glucose</span>
                <span className="text-[#E5FE40]">{glucose} mg/dL</span>
              </div>
              <input
                type="range"
                min="65"
                max="130"
                step="1"
                value={glucose}
                onChange={(e) => { setHasUserSimulated(true); setGlucose(Number(e.target.value)); }}
                className="w-full accent-[#E5FE40]"
              />
              <span className="text-[10px] text-[#8A8A8A] block">Insulin sensitivity & glycation</span>
            </div>

            <div className="space-y-1.5 p-3 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold">Lymphocyte %</span>
                <span className="text-[#10B981]">{lymphPct}%</span>
              </div>
              <input
                type="range"
                min="15"
                max="45"
                step="1"
                value={lymphPct}
                onChange={(e) => { setHasUserSimulated(true); setLymphPct(Number(e.target.value)); }}
                className="w-full accent-[#10B981]"
              />
              <span className="text-[10px] text-[#8A8A8A] block">Adaptive immune competence</span>
            </div>

            <div className="space-y-1.5 p-3 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold">Creatinine</span>
                <span className="text-[#8B5CF6]">{creatinine} mg/dL</span>
              </div>
              <input
                type="range"
                min="0.5"
                max="1.6"
                step="0.05"
                value={creatinine}
                onChange={(e) => { setHasUserSimulated(true); setCreatinine(Number(e.target.value)); }}
                className="w-full accent-[#8B5CF6]"
              />
              <span className="text-[10px] text-[#8A8A8A] block">Glomerular filtration rate</span>
            </div>

            <div className="space-y-1.5 p-3 rounded-[14px] bg-black/40 border border-white/5">
              <div className="flex justify-between text-xs font-mono">
                <span className="text-white font-bold">RDW (Red Cell Width)</span>
                <span className="text-[#00D6E6]">{rdw}%</span>
              </div>
              <input
                type="range"
                min="11.0"
                max="16.0"
                step="0.1"
                value={rdw}
                onChange={(e) => { setHasUserSimulated(true); setRdw(Number(e.target.value)); }}
                className="w-full accent-[#00D6E6]"
              />
              <span className="text-[10px] text-[#8A8A8A] block">Bone marrow cell uniformity</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
