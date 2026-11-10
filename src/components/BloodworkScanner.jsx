import React, { useState } from 'react';
import { FileText, Upload, CheckCircle, ShieldCheck, Sparkles, Scan, ArrowRight } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const PARSED_LAB_REPORT = [
  { test: 'Apolipoprotein B (ApoB)', val: '54 mg/dL', ref: '< 60 mg/dL', status: 'LONGEVITY OPTIMAL', flag: 'ideal' },
  { test: 'Free Testosterone (Equilibrium)', val: '26.4 pg/mL', ref: '16 - 28 pg/mL', status: 'ELITE ANDROGEN', flag: 'ideal' },
  { test: 'Total Testosterone (LC/MS)', val: '912 ng/dL', ref: '300 - 1000 ng/dL', status: 'TOP 1%', flag: 'ideal' },
  { test: 'High-Sensitivity CRP (hs-CRP)', val: '0.22 mg/L', ref: '< 0.50 mg/L', status: 'ZERO INFLAMMATION', flag: 'ideal' },
  { test: 'Fasting Serum Insulin', val: '2.8 uIU/mL', ref: '< 4.0 uIU/mL', status: 'DEEP SENSITIVITY', flag: 'ideal' },
  { test: 'Serum Homocysteine', val: '6.8 umol/L', ref: '< 8.0 umol/L', status: 'MTHFR OPTIMAL', flag: 'ideal' },
  { test: 'Hemoglobin A1c (HbA1c)', val: '4.8%', ref: '< 5.2%', status: 'NO GLYCATION', flag: 'ideal' },
  { test: 'Vitamin D, 25-Hydroxy', val: '78 ng/mL', ref: '60 - 80 ng/mL', status: 'PEAK CIRCADIAN', flag: 'ideal' },
];

export default function BloodworkScanner({ onPushToPhenoAge }) {
  const [isParsing, setIsParsing] = useState(false);
  const [isUploaded, setIsUploaded] = useState(true);

  const handleSimulateUpload = () => {
    playPlunk();
    setIsParsing(true);
    setTimeout(() => {
      setIsParsing(false);
      setIsUploaded(true);
      playCoinChime();
      try {
        confetti({
          particleCount: 50,
          spread: 60,
          colors: ['#10B981', '#00F0FF', '#E5FE40'],
        });
      } catch {}
    }, 1500);
  };

  return (
    <div className="space-y-6">
      {/* OCR SCANNER HEADER */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
              <FileText className="w-5 h-5 text-[#10B981]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">AI Bloodwork OCR & Lab Parser</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  QUEST & LABCORP
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Computer-vision extraction of 48 blood biomarkers against longevity percentiles
              </span>
            </div>
          </div>

          <button
            onClick={handleSimulateUpload}
            disabled={isParsing}
            className="px-3.5 py-1.5 rounded-[12px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center space-x-1.5"
          >
            <Scan className={`w-3.5 h-3.5 ${isParsing ? 'animate-spin' : ''}`} />
            <span>{isParsing ? 'PARSING PDF...' : 'SCAN LAB PDF'}</span>
          </button>
        </div>

        {/* Upload Status Card */}
        <div className="p-4 rounded-[18px] bg-black/60 border border-white/10 flex items-center justify-between text-xs font-mono">
          <div className="flex items-center space-x-2.5">
            <CheckCircle className="w-4 h-4 text-[#10B981]" />
            <div>
              <span className="text-white font-bold block">Quest_Comprehensive_Metabolic_Panel.pdf</span>
              <span className="text-[10px] text-[#8A8A8A]">Verified Specimen ID: Q-984218 · Drawn 3 days ago</span>
            </div>
          </div>
          <span className="text-[#10B981] font-black">100% PARSED</span>
        </div>
      </div>

      {/* PARSED BIOMARKER LIST */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
            AUTOMATICALLY PARSED LAB VALUES & LONGEVITY TARGETS
          </h4>
          <span className="text-xs font-mono text-[#10B981] font-bold">8 / 8 IN OPTIMAL TIER</span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
          {PARSED_LAB_REPORT.map((lab, idx) => (
            <div
              key={idx}
              className="p-3.5 rounded-[16px] bg-black/40 border border-white/5 flex items-center justify-between text-xs font-mono"
            >
              <div>
                <span className="text-white font-bold block">{lab.test}</span>
                <span className="text-[10px] text-[#8A8A8A]">Longevity Target: {lab.ref}</span>
              </div>
              <div className="text-right">
                <span className="text-sm font-black text-[#00F0FF] block">{lab.val}</span>
                <span className="text-[9px] font-bold text-[#10B981]">{lab.status}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
