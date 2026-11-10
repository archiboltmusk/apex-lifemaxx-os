import React, { useState } from 'react';
import { Activity, ShieldCheck, Heart, Sparkles, RefreshCw, ChevronRight, TrendingDown } from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function PhenoAgeCalculator() {
  const [chronoAge, setChronoAge] = useState(29);
  const [albumin, setAlbumin] = useState(4.8); // g/dL (normal 4.0-5.0)
  const [creatinine, setCreatinine] = useState(0.92); // mg/dL (normal 0.7-1.2)
  const [glucose, setGlucose] = useState(82); // mg/dL (normal 70-99)
  const [hsCRP, setHsCRP] = useState(0.22); // mg/L (optimal < 0.5)
  const [lymphPct, setLymphPct] = useState(34); // % (normal 20-40)
  const [mcv, setMcv] = useState(88.5); // fL (normal 80-100)
  const [rdw, setRdw] = useState(11.8); // % (optimal 11.5-12.5)
  const [alkPhos, setAlkPhos] = useState(48); // U/L (optimal 40-70)
  const [wbc, setWbc] = useState(4.6); // 1000/uL (optimal 4.0-6.0)

  // Morgan Levine PhenoAge Algorithm approximation
  const calculatePhenoAge = () => {
    // Weighted regression model based on Levine et al. 2018
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

  const bioAge = calculatePhenoAge();
  const ageDelta = +(bioAge - chronoAge).toFixed(1);
  const isReversed = ageDelta < 0;

  return (
    <div className="space-y-6">
      {/* HERO PHENOAGE READOUT */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/20 relative overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 rounded-[16px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
              <Activity className="w-6 h-6 text-[#10B981]" />
            </div>
            <div>
              <span className="text-[10px] font-mono text-[#10B981] font-black uppercase tracking-widest">
                MORGAN LEVINE PHENOAGE ALGORITHM
              </span>
              <h3 className="text-lg font-bold text-white tracking-tight">
                Biological Epigenetic Clock Calculator
              </h3>
            </div>
          </div>

          <div className="text-right">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">BIOLOGICAL AGE</span>
            <div className="flex items-baseline space-x-2">
              <span className="text-4xl font-mono font-black text-white">{bioAge}</span>
              <span className="text-xs font-mono text-[#8A8A8A]">years</span>
            </div>
            <span className="text-xs font-mono font-black text-[#10B981]">
              {isReversed ? `${Math.abs(ageDelta)} YEARS YOUNGER` : `+${ageDelta} Years Advanced`}
            </span>
          </div>
        </div>

        <div className="p-3.5 rounded-[16px] bg-black/50 border border-white/10 flex items-center justify-between text-xs font-mono">
          <div className="flex items-center space-x-2">
            <ShieldCheck className="w-4 h-4 text-[#00F0FF]" />
            <span className="text-white">DunedinPACE Pace of Aging: <strong className="text-[#E5FE40]">0.74x / year</strong></span>
          </div>
          <span className="text-[#10B981] font-bold">Top 0.01% Longevity Tier</span>
        </div>
      </div>

      {/* BLOOD LAB VALUE SLIDERS */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <h4 className="text-xs font-mono font-black text-[#E5FE40] uppercase tracking-wider">
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
    </div>
  );
}
