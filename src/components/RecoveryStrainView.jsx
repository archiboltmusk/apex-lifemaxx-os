import React from 'react';
import { Activity, Flame, Moon, Heart, TrendingUp, Zap, Clock, ShieldAlert } from 'lucide-react';
import { RECOVERY_STRAIN_DATA, APPLE_HEALTH_DATA } from '../utils/lifemaxxData';
import { playPlunk } from '../utils/audioSynth';

export default function RecoveryStrainView() {
  const { recoveryScore, recoveryStatus, recoveryMessage, strainCurrent, strainTarget, zones } =
    RECOVERY_STRAIN_DATA;
  const { sleepStages } = APPLE_HEALTH_DATA;

  return (
    <div className="space-y-6">
      {/* WHOOP / BEVEL STYLE RECOVERY & STRAIN HERO */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* RECOVERY CARD */}
        <div className="liquid-glass-elevated rounded-[24px] p-6 border border-white/15 relative overflow-hidden">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 rounded-[10px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
                <Heart className="w-4 h-4 text-[#10B981]" />
              </div>
              <div>
                <span className="text-[10px] font-mono text-[#10B981] font-black uppercase tracking-wider">
                  RECOVERY STATUS
                </span>
                <h4 className="text-sm font-bold text-white">Autonomic Nervous System</h4>
              </div>
            </div>
            <span className="text-xs font-mono font-black px-2.5 py-1 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40">
              {recoveryStatus}
            </span>
          </div>

          <div className="flex items-center space-x-6 my-2">
            {/* Circular Gauge */}
            <div className="relative w-28 h-28 flex items-center justify-center shrink-0">
              <svg className="w-28 h-28 transform -rotate-90">
                <circle
                  cx="56"
                  cy="56"
                  r="48"
                  stroke="#1F2937"
                  strokeWidth="10"
                  fill="none"
                />
                <circle
                  cx="56"
                  cy="56"
                  r="48"
                  stroke="#10B981"
                  strokeWidth="10"
                  strokeDasharray={2 * Math.PI * 48}
                  strokeDashoffset={2 * Math.PI * 48 * (1 - recoveryScore / 100)}
                  strokeLinecap="round"
                  fill="none"
                  className="transition-all duration-1000 ease-out"
                />
              </svg>
              <div className="absolute flex flex-col items-center">
                <span className="text-2xl font-mono font-black text-white">{recoveryScore}%</span>
                <span className="text-[9px] font-mono text-[#10B981] font-bold">OPTIMAL</span>
              </div>
            </div>

            <div className="space-y-1.5 text-xs">
              <p className="text-[#C4C4C4] leading-relaxed">{recoveryMessage}</p>
              <div className="flex items-center space-x-3 pt-1 font-mono text-[11px]">
                <span className="text-white">HRV: <strong className="text-[#00F0FF]">94 ms</strong></span>
                <span className="text-white">RHR: <strong className="text-[#10B981]">48 bpm</strong></span>
              </div>
            </div>
          </div>
        </div>

        {/* STRAIN CARD */}
        <div className="liquid-glass-elevated rounded-[24px] p-6 border border-white/15 relative overflow-hidden">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 rounded-[10px] bg-[#FA114F]/20 border border-[#FA114F]/40 flex items-center justify-center">
                <Flame className="w-4 h-4 text-[#FA114F]" />
              </div>
              <div>
                <span className="text-[10px] font-mono text-[#FA114F] font-black uppercase tracking-wider">
                  DAY STRAIN TARGET
                </span>
                <h4 className="text-sm font-bold text-white">Cardiovascular Load</h4>
              </div>
            </div>
            <span className="text-xs font-mono font-black px-2.5 py-1 rounded-full bg-[#FA114F]/20 text-[#FA114F] border border-[#FA114F]/40">
              TARGET 18.0
            </span>
          </div>

          <div className="flex items-baseline space-x-2 my-2">
            <span className="text-4xl font-mono font-black text-white">{strainCurrent}</span>
            <span className="text-sm font-mono text-[#8A8A8A]">/ {strainTarget} Max Strain</span>
          </div>

          {/* Progress Bar */}
          <div className="w-full h-3 bg-black/40 rounded-full overflow-hidden border border-white/10 my-3">
            <div
              className="h-full bg-gradient-to-r from-[#FA114F] via-[#F59E0B] to-[#92E82A] rounded-full transition-all duration-700"
              style={{ width: `${(strainCurrent / strainTarget) * 100}%` }}
            />
          </div>

          <div className="flex items-center justify-between text-[11px] font-mono text-[#A1A1AA]">
            <span>2,940 Total Calories Burned</span>
            <span className="text-[#FA114F] font-bold">88% of Optimal Strain</span>
          </div>
        </div>
      </div>

      {/* HEART RATE INTENSITY ZONES */}
      <div className="liquid-glass rounded-[22px] p-5 border border-white/10">
        <h4 className="text-xs font-mono font-black text-[#E5FE40] uppercase tracking-wider mb-3">
          HEART RATE ZONE BREAKDOWN (APPLE HEALTHKIT LIVE)
        </h4>
        <div className="space-y-2">
          {zones.map((z, idx) => (
            <div key={idx} className="flex items-center justify-between text-xs font-mono py-1 border-b border-white/5 last:border-0">
              <div className="flex items-center space-x-2 w-48">
                <span className="text-white font-medium">{z.zone}</span>
                <span className="text-[10px] text-[#8A8A8A]">{z.range}</span>
              </div>
              <div className="flex-1 max-w-xs mx-4 h-2 bg-black/50 rounded-full overflow-hidden">
                <div
                  className="h-full bg-[#00F0FF] rounded-full"
                  style={{ width: `${z.pct * 2}%` }}
                />
              </div>
              <span className="text-white font-bold">{z.time}</span>
            </div>
          ))}
        </div>
      </div>

      {/* SLEEP STAGING ARCHITECTURE */}
      <div className="liquid-glass rounded-[22px] p-5 border border-white/10">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-2">
            <Moon className="w-4 h-4 text-[#38BDF8]" />
            <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
              SLEEP ARCHITECTURE & STAGES ({sleepStages.totalHours} · {sleepStages.efficiency} EFFICIENCY)
            </h4>
          </div>
          <span className="text-[11px] font-mono text-[#38BDF8] font-black">
            SCORE: {sleepStages.score}/100
          </span>
        </div>

        {/* Stacked bar */}
        <div className="w-full h-4 rounded-full overflow-hidden flex bg-black/50 border border-white/10 mb-4">
          <div style={{ width: `${sleepStages.deep.percentage}%`, backgroundColor: sleepStages.deep.color }} title="Deep Sleep" />
          <div style={{ width: `${sleepStages.rem.percentage}%`, backgroundColor: sleepStages.rem.color }} title="REM Sleep" />
          <div style={{ width: `${sleepStages.core.percentage}%`, backgroundColor: sleepStages.core.color }} title="Core Sleep" />
          <div style={{ width: `${sleepStages.awake.percentage}%`, backgroundColor: sleepStages.awake.color }} title="Awake" />
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs font-mono">
          <div className="p-2.5 rounded-lg bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#8A8A8A] block">DEEP SLEEP</span>
            <span className="text-sm font-bold text-[#3B82F6]">{sleepStages.deep.time}</span>
            <span className="text-[10px] text-white/60 block">Cellular Repair (27%)</span>
          </div>
          <div className="p-2.5 rounded-lg bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#8A8A8A] block">REM SLEEP</span>
            <span className="text-sm font-bold text-[#8B5CF6]">{sleepStages.rem.time}</span>
            <span className="text-[10px] text-white/60 block">Memory Synthesis (23%)</span>
          </div>
          <div className="p-2.5 rounded-lg bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#8A8A8A] block">CORE SLEEP</span>
            <span className="text-sm font-bold text-[#06B6D4]">{sleepStages.core.time}</span>
            <span className="text-[10px] text-white/60 block">Restorative (47%)</span>
          </div>
          <div className="p-2.5 rounded-lg bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#8A8A8A] block">AWAKE DURATION</span>
            <span className="text-sm font-bold text-[#64748B]">{sleepStages.awake.time}</span>
            <span className="text-[10px] text-white/60 block">Minimal Arousals (3%)</span>
          </div>
        </div>
      </div>
    </div>
  );
}
