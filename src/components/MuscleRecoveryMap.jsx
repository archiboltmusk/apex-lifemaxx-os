import React, { useState } from 'react';
import { Dumbbell, Activity, ShieldCheck, Flame, Clock, Sliders } from 'lucide-react';
import { playPlunk } from '../utils/audioSynth';

const MUSCLE_DATA = {
  pecs: {
    name: 'Upper Pectorals (Clavicular Head)',
    recovery: 92,
    status: 'OPTIMAL SUPERCOMPENSATION',
    color: '#10B981',
    hoursRemaining: 0,
    setsWeek: 14,
    targetSets: 16,
    exercises: ['30° Incline Dumbbell Press', 'Low-to-High Cable Crossover', 'Weighted Dips'],
  },
  delts: {
    name: 'Lateral Deltoids (Cap Width)',
    recovery: 100,
    status: 'FULLY RESTORED & PRIMED',
    color: '#E5FE40',
    hoursRemaining: 0,
    setsWeek: 18,
    targetSets: 18,
    exercises: ['Behind-the-Back Cable Lateral Raise', 'DB Lu Raises', 'Overhead Press'],
  },
  lats: {
    name: 'Latissimus Dorsi (V-Taper Sweep)',
    recovery: 68,
    status: 'RECOVERING (ATP SYNTHESIS)',
    color: '#F59E0B',
    hoursRemaining: 14,
    setsWeek: 16,
    targetSets: 16,
    exercises: ['Weighted Neutral-Grip Pull-ups', 'Single-Arm Ilac Lat Pulldown', 'Chest-Supported Row'],
  },
  quads: {
    name: 'Quadriceps (Vastus Medialis & Lateralis)',
    recovery: 95,
    status: 'PRIMED FOR MAX LOAD',
    color: '#10B981',
    hoursRemaining: 0,
    setsWeek: 12,
    targetSets: 14,
    exercises: ['Hack Squats', 'Bulgarian Split Squats', 'Leg Extensions (Pin Pointed)'],
  },
  hamstrings: {
    name: 'Hamstrings & Posterior Chain',
    recovery: 42,
    status: 'FATIGUED (MICROTORN FIBERS)',
    color: '#FA114F',
    hoursRemaining: 26,
    setsWeek: 10,
    targetSets: 12,
    exercises: ['Romanian Deadlifts', 'Seated Leg Curls', 'Nordic Hamstring Drop'],
  },
  core: {
    name: 'Rectus Abdominis & Transverse Abdominis',
    recovery: 100,
    status: 'FULL RIGIDITY',
    color: '#E5FE40',
    hoursRemaining: 0,
    setsWeek: 8,
    targetSets: 10,
    exercises: ['Hanging Leg Raises', 'Ab Wheel Rollouts', 'Vacuum Stomach Holds'],
  },
};

export default function MuscleRecoveryMap() {
  const [selectedMuscle, setSelectedMuscle] = useState('pecs');
  const active = MUSCLE_DATA[selectedMuscle];

  return (
    <div className="space-y-6">
      {/* MUSCLE HEATMAP HERO */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-widest">
              HYPERTROPHY BIOMECHANICS
            </span>
            <h3 className="text-base font-bold text-white tracking-tight">
              Muscular Fatigue & Recovery Heatmap
            </h3>
          </div>
          <span className="text-xs font-mono px-3 py-1 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-bold">
            92% WHOLE-BODY RECOVERY
          </span>
        </div>

        {/* Anatomical Heatmap Muscle Pills */}
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-2">
          {Object.entries(MUSCLE_DATA).map(([key, m]) => {
            const isSelected = selectedMuscle === key;
            return (
              <div
                key={key}
                onClick={() => {
                  playPlunk();
                  setSelectedMuscle(key);
                }}
                className={`p-3 rounded-[16px] border transition cursor-pointer text-center ${
                  isSelected
                    ? 'bg-white/15 border-white/40 scale-102 shadow-[0_0_15px_rgba(255,255,255,0.2)]'
                    : 'bg-black/40 border-white/10 hover:border-white/20'
                }`}
              >
                <div
                  className="w-3 h-3 rounded-full mx-auto mb-1.5"
                  style={{ backgroundColor: m.color, boxShadow: `0 0 8px ${m.color}` }}
                />
                <span className="text-xs font-mono font-bold text-white block truncate">
                  {m.name.split(' ')[0]}
                </span>
                <span className="text-[10px] font-mono" style={{ color: m.color }}>
                  {m.recovery}%
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* SELECTED MUSCLE DETAIL PANEL */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <span className="text-[10px] font-mono text-[#00F0FF] font-black uppercase">
              SELECTED MUSCLE GROUP
            </span>
            <h4 className="text-base font-bold text-white tracking-tight">{active.name}</h4>
          </div>

          <div className="text-right">
            <span className="text-2xl font-mono font-black" style={{ color: active.color }}>
              {active.recovery}%
            </span>
            <span className="text-[10px] font-mono text-[#8A8A8A] block">{active.status}</span>
          </div>
        </div>

        {/* Recovery progress bar */}
        <div className="w-full h-2.5 bg-black/50 rounded-full overflow-hidden border border-white/10">
          <div
            className="h-full rounded-full transition-all duration-700"
            style={{ width: `${active.recovery}%`, backgroundColor: active.color }}
          />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2 text-xs font-mono">
          <div className="p-3 rounded-[14px] bg-black/40 border border-white/5 space-y-1">
            <span className="text-[#8A8A8A] text-[10px] block">WEEKLY VOLUME ACCUMULATED</span>
            <span className="text-sm font-bold text-white">
              {active.setsWeek} of {active.targetSets} Optimal Working Sets
            </span>
            <p className="text-[10px] text-[#A1A1AA]">
              {active.hoursRemaining > 0
                ? `${active.hoursRemaining} hours until full myofibrillar restoration`
                : 'Ready for maximal progressive overload load today'}
            </p>
          </div>

          <div className="p-3 rounded-[14px] bg-black/40 border border-white/5 space-y-1">
            <span className="text-[#8A8A8A] text-[10px] block">GOLDEN ERA HYPERTROPHY MOVEMENTS</span>
            <div className="space-y-0.5">
              {active.exercises.map((ex, i) => (
                <span key={i} className="text-xs text-[#00F0FF] block">
                  • {ex}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
