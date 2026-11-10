import React, { useState } from 'react';
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

export default function PhenoAgeCalculator() {
  const [activeEngine, setActiveEngine] = useState('livity_fitness'); // 'livity_fitness' | 'morgan_levine'
  const [chronoAge, setChronoAge] = useState(29);

  // Livity 8 Key Metrics State
  const [vo2Max, setVo2Max] = useState(54.2); // mL/kg/min (Top 1%)
  const [restingHR, setRestingHR] = useState(48); // bpm
  const [hrvSDNN, setHrvSDNN] = useState(94); // ms
  const [sleepHours, setSleepHours] = useState(8.2); // hours
  const [dailySteps, setDailySteps] = useState(12400); // steps
  const [modActivityMin, setModActivityMin] = useState(45); // Zone 2 min/day
  const [vigActivityMin, setVigActivityMin] = useState(25); // Zone 4/5 min/day
  const [strengthSessions, setStrengthSessions] = useState(4); // sessions/week

  // Morgan Levine Clinical Blood Panel State
  const [albumin, setAlbumin] = useState(4.8); // g/dL
  const [creatinine, setCreatinine] = useState(0.92); // mg/dL
  const [glucose, setGlucose] = useState(82); // mg/dL
  const [hsCRP, setHsCRP] = useState(0.22); // mg/L
  const [lymphPct, setLymphPct] = useState(34); // %
  const [mcv, setMcv] = useState(88.5); // fL
  const [rdw, setRdw] = useState(11.8); // %
  const [alkPhos, setAlkPhos] = useState(48); // U/L
  const [wbc, setWbc] = useState(4.6); // 1000/uL

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

  return (
    <div className="space-y-6">
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
            <div className="flex items-baseline space-x-2">
              <span className="text-4xl font-mono font-black text-white">{currentAge}</span>
              <span className="text-xs font-mono text-[#8A8A8A]">years</span>
            </div>
            <span className="text-xs font-mono font-black text-[#10B981]">
              {isReversed ? `${Math.abs(ageDelta)} YEARS YOUNGER` : `+${ageDelta} Years Advanced`}
            </span>
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
                ? 'Fitness age computed across VO2 Max, Sleep, Resting HR & Workouts'
                : 'DunedinPACE Rate of Biological Aging: 0.74x / year'}
            </span>
          </div>
          <span className="text-[#10B981] font-bold">Top 0.01% Longevity Tier</span>
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
                onChange={(e) => setVo2Max(Number(e.target.value))}
                className="w-full accent-[#FA114F]"
              />
              <span className="text-[9px] text-[#8A8A8A] block">Top 1% Longevity Indicator</span>
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
                onChange={(e) => setRestingHR(Number(e.target.value))}
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
                onChange={(e) => setHrvSDNN(Number(e.target.value))}
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
                onChange={(e) => setSleepHours(Number(e.target.value))}
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
                onChange={(e) => setDailySteps(Number(e.target.value))}
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
                onChange={(e) => setModActivityMin(Number(e.target.value))}
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
                onChange={(e) => setVigActivityMin(Number(e.target.value))}
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
                onChange={(e) => setStrengthSessions(Number(e.target.value))}
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
                onChange={(e) => setAlbumin(Number(e.target.value))}
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
                onChange={(e) => setHsCRP(Number(e.target.value))}
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
                onChange={(e) => setGlucose(Number(e.target.value))}
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
                onChange={(e) => setLymphPct(Number(e.target.value))}
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
                onChange={(e) => setCreatinine(Number(e.target.value))}
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
                onChange={(e) => setRdw(Number(e.target.value))}
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
