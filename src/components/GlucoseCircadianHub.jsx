import React, { useState } from 'react';
import { Zap, Sun, Moon, ArrowRight, ShieldCheck, TrendingDown, Clock, Plane } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';

export default function GlucoseCircadianHub() {
  const [selectedRoute, setSelectedRoute] = useState('sfo-tyo');

  const routes = {
    'sfo-tyo': {
      from: 'San Francisco (PST)',
      to: 'Tokyo (JST)',
      shift: '+16 Hours',
      steps: [
        { time: '07:30 AM', action: 'Direct Lux Sunlight (10,000 Lux)', desc: 'Phase advances SCN master circadian pacemaker' },
        { time: '01:00 PM', action: 'Final Caffeine Ingestion (Strict Cutoff)', desc: 'Prevents adenosine receptor binding delay' },
        { time: '08:00 PM', action: 'Dim Room to < 10 Lux & Wear 99% Blue Blockers', desc: 'Permits pineal melatonin synthesis' },
        { time: '09:30 PM', action: 'Take 300mcg Micro-Melatonin + Mag-Threonate', desc: 'Induces rapid circadian phase advance' },
      ],
    },
    'nyc-lon': {
      from: 'New York (EST)',
      to: 'London (GMT)',
      shift: '+5 Hours',
      steps: [
        { time: '08:00 AM', action: '15m High Intensity Outdoor Light', desc: 'Resets central circadian clock' },
        { time: '02:00 PM', action: 'Hydration with Sodium & Potassium Ions', desc: 'Maintains fluid balance during cabin pressurization' },
        { time: '09:00 PM', action: 'Cold Shower & Room Temperature to 64°F', desc: 'Facilitates core body temperature drop for deep sleep' },
      ],
    },
  };

  const activeRoute = routes[selectedRoute];

  return (
    <div className="space-y-6">
      {/* CGM GLUCOSE SPIKE PREDICTOR */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
              <Zap className="w-5 h-5 text-[#10B981]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">Dexcom G7 CGM Continuous Telemetry</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  88 mg/dL FLAT
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Predictive glycemic modeling & postprandial blunting hacks
              </span>
            </div>
          </div>
          <span className="text-xs font-mono text-[#10B981] font-black">ZERO GLYCEMIC VARIABILITY</span>
        </div>

        {/* Glucose Curve Visualization */}
        <div className="p-4 rounded-[18px] bg-black/60 border border-white/10 space-y-2">
          <div className="flex items-center justify-between text-xs font-mono text-[#8A8A8A]">
            <span>LAST 6 HOURS CONTINUOUS GLUCOSE CURVE</span>
            <span className="text-[#10B981]">Mean Glucose: 86 mg/dL</span>
          </div>
          <svg viewBox="0 0 400 60" className="w-full h-14">
            <path
              d="M 0 35 Q 50 34, 100 36 T 200 32 T 300 35 T 400 34"
              fill="none"
              stroke="#10B981"
              strokeWidth="2.5"
            />
            {/* Target Normal Zone Band */}
            <rect x="0" y="20" width="400" height="25" fill="rgba(16,185,129,0.08)" />
          </svg>
        </div>

        {/* Glucose Blunting Hacks */}
        <div className="p-3.5 rounded-[16px] bg-white/[0.03] border border-white/5 space-y-2 text-xs font-mono">
          <span className="text-[#E5FE40] font-black uppercase">
            💡 PROACTIVE MEAL PAIRING BIOHACK:
          </span>
          <p className="text-white/90">
            Incoming high-carb meal detected. Consuming <strong>1 tbsp Apple Cider Vinegar</strong> in water or doing a <strong>10-minute post-meal walk</strong> will suppress the glycemic spike by up to <strong>34%</strong> via GLUT4 translocation.
          </p>
        </div>
      </div>

      {/* CIRCADIAN JETLAG & LIGHT PROTOCOL ENGINE */}
      <div className="liquid-glass rounded-[26px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 flex items-center justify-center">
              <Plane className="w-5 h-5 text-[#00F0FF]" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-white tracking-tight">
                Circadian Jetlag & Light Protocol Engine
              </h3>
              <p className="text-[11px] font-mono text-[#8A8A8A]">
                Shift your suprachiasmatic nucleus master clock before landing
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {['sfo-tyo', 'nyc-lon'].map((r) => (
              <button
                key={r}
                onClick={() => {
                  playPlunk();
                  setSelectedRoute(r);
                }}
                className={`px-3 py-1 rounded-[10px] text-xs font-mono font-bold uppercase transition ${
                  selectedRoute === r
                    ? 'bg-[#00F0FF] text-black font-black'
                    : 'bg-black/40 text-[#8A8A8A] border border-white/10'
                }`}
              >
                {r.toUpperCase()}
              </button>
            ))}
          </div>
        </div>

        <div className="flex items-center space-x-2 text-xs font-mono text-white mb-2">
          <span>{activeRoute.from}</span>
          <ArrowRight className="w-4 h-4 text-[#00F0FF]" />
          <span className="text-[#00F0FF] font-bold">{activeRoute.to}</span>
          <span className="text-[#E5FE40] ml-2 font-bold">({activeRoute.shift})</span>
        </div>

        {/* Steps */}
        <div className="space-y-2">
          {activeRoute.steps.map((step, idx) => (
            <div
              key={idx}
              className="p-3 rounded-[14px] bg-black/40 border border-white/5 flex items-center justify-between text-xs font-mono"
            >
              <div className="flex items-center space-x-3">
                <span className="text-[#00F0FF] font-bold">{step.time}</span>
                <div>
                  <span className="text-white font-bold block">{step.action}</span>
                  <span className="text-[10px] text-[#8A8A8A]">{step.desc}</span>
                </div>
              </div>
              <span className="w-2 h-2 rounded-full bg-[#00F0FF]" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
