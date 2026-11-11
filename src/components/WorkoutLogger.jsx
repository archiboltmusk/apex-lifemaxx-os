import React, { useState, useEffect } from 'react';
import {
  Dumbbell,
  Play,
  Pause,
  RotateCcw,
  Plus,
  Check,
  TrendingUp,
  Clock,
  Flame,
  Award,
  ChevronRight,
  Calculator,
  Sliders
} from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const INITIAL_EXERCISES = [
  {
    id: 'e1',
    name: 'Incline Barbell Bench Press',
    muscle: 'Upper Chest / Clavicular Head',
    sets: [
      { id: 1, setNum: 1, prev: '—', weight: 60, reps: 8, rpe: 8.0, completed: false },
      { id: 2, setNum: 2, prev: '—', weight: 60, reps: 8, rpe: 8.5, completed: false },
      { id: 3, setNum: 3, prev: '—', weight: 60, reps: 8, rpe: 9.0, completed: false },
    ],
  },
  {
    id: 'e2',
    name: 'Weighted V-Bar Pull-Ups',
    muscle: 'Lats / V-Taper Width',
    sets: [
      { id: 4, setNum: 1, prev: '—', weight: 0, reps: 8, rpe: 8.0, completed: false },
      { id: 5, setNum: 2, prev: '—', weight: 0, reps: 8, rpe: 8.5, completed: false },
      { id: 6, setNum: 3, prev: '—', weight: 0, reps: 8, rpe: 9.0, completed: false },
    ],
  },
  {
    id: 'e3',
    name: 'Cable Lateral Raises (Strict)',
    muscle: 'Lateral Delts / Shoulder Cap',
    sets: [
      { id: 7, setNum: 1, prev: '—', weight: 10, reps: 15, rpe: 8.5, completed: false },
      { id: 8, setNum: 2, prev: '—', weight: 10, reps: 15, rpe: 9.0, completed: false },
      { id: 9, setNum: 3, prev: '—', weight: 10, reps: 15, rpe: 9.5, completed: false },
    ],
  },
];

export default function WorkoutLogger() {
  const [exercises, setExercises] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_logged_workouts');
      return saved ? JSON.parse(saved) : INITIAL_EXERCISES;
    } catch {
      return INITIAL_EXERCISES;
    }
  });
  const [isRestActive, setIsRestActive] = useState(false);
  const [restSeconds, setRestSeconds] = useState(90);
  const [calcWeight, setCalcWeight] = useState(100);
  const [calcReps, setCalcReps] = useState(8);
  const [activeSubTab, setActiveSubTab] = useState('workout'); // 'workout' | '1rm' | 'muscles'

  // Rest Timer Interval
  useEffect(() => {
    let interval = null;
    if (isRestActive && restSeconds > 0) {
      interval = setInterval(() => {
        setRestSeconds((prev) => prev - 1);
      }, 1000);
    } else if (restSeconds === 0 && isRestActive) {
      setIsRestActive(false);
      playCoinChime();
      try {
        confetti({
          particleCount: 40,
          spread: 40,
          colors: ['#E5FE40', '#00F0FF'],
        });
      } catch {}
    }
    return () => clearInterval(interval);
  }, [isRestActive, restSeconds]);

  const toggleSet = (exerciseId, setId) => {
    playPlunk();
    setExercises((prev) => {
      const updated = prev.map((ex) => {
        if (ex.id === exerciseId) {
          return {
            ...ex,
            sets: ex.sets.map((s) => {
              if (s.id === setId) {
                const next = !s.completed;
                if (next) {
                  playCoinChime();
                  setRestSeconds(90);
                  setIsRestActive(true);
                }
                return { ...s, completed: next };
              }
              return s;
            }),
          };
        }
        return ex;
      });
      try {
        localStorage.setItem('apex_logged_workouts', JSON.stringify(updated));
      } catch {}
      return updated;
    });
  };

  // 1RM Brzycki Calculation
  const estimated1RM = Math.round(calcWeight * (36 / (37 - Math.min(calcReps, 36))));

  return (
    <div className="space-y-6">
      {/* SUB-NAVIGATION PILLS */}
      <div className="flex items-center space-x-2 border-b border-white/10 pb-3">
        {[
          { id: 'workout', label: 'Active Session (Hevy)', icon: Dumbbell },
          { id: '1rm', label: '1RM Strength Calculator', icon: Calculator },
          { id: 'muscles', label: 'Muscle Volume Radar', icon: TrendingUp },
        ].map((tab) => {
          const Icon = tab.icon;
          const isSelected = activeSubTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => {
                playPlunk();
                setActiveSubTab(tab.id);
              }}
              className={`px-3.5 py-1.5 rounded-[12px] text-xs font-mono font-bold flex items-center space-x-1.5 transition ${
                isSelected
                  ? 'bg-[#E5FE40] text-black shadow-[2px_2px_0px_#000]'
                  : 'bg-white/5 text-[#8A8A8A] hover:text-white'
              }`}
            >
              <Icon className="w-3.5 h-3.5" />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* VIEW 1: ACTIVE WORKOUT */}
      {activeSubTab === 'workout' && (
        <div className="space-y-4">
          {/* REST TIMER BAR */}
          <div className="liquid-glass rounded-[20px] p-4 border border-white/10 flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-[12px] bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center">
                <Clock className="w-5 h-5 text-[#E5FE40]" />
              </div>
              <div>
                <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase">
                  AUTO REST TIMER
                </span>
                <div className="flex items-baseline space-x-2">
                  <span className="text-xl font-mono font-black text-white">
                    {Math.floor(restSeconds / 60)}:
                    {(restSeconds % 60).toString().padStart(2, '0')}
                  </span>
                  <span className="text-[11px] font-mono text-[#8A8A8A]">
                    {isRestActive ? 'Resting for ATP resynthesis' : 'Idle'}
                  </span>
                </div>
              </div>
            </div>

            <div className="flex items-center space-x-2">
              <button
                onClick={() => {
                  playPlunk();
                  setIsRestActive(!isRestActive);
                }}
                className="px-3.5 py-1.5 rounded-[10px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center space-x-1"
              >
                {isRestActive ? <Pause className="w-3 h-3" /> : <Play className="w-3 h-3" />}
                <span>{isRestActive ? 'PAUSE' : 'START 90s'}</span>
              </button>
              <button
                onClick={() => {
                  playPlunk();
                  setRestSeconds(90);
                }}
                className="p-1.5 rounded-[10px] bg-white/10 text-white hover:bg-white/20"
              >
                <RotateCcw className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          {/* EXERCISE LIST */}
          <div className="space-y-4">
            {exercises.map((ex) => (
              <div key={ex.id} className="liquid-glass rounded-[22px] p-5 border border-white/10">
                <div className="flex items-center justify-between mb-3">
                  <div>
                    <h4 className="text-sm font-bold text-white tracking-tight">{ex.name}</h4>
                    <span className="text-[10px] font-mono text-[#00F0FF]">{ex.muscle}</span>
                  </div>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-black/50 text-[#10B981] border border-white/10 font-bold">
                    RPE 8.5 - 9.5
                  </span>
                </div>

                {/* Sets Header */}
                <div className="grid grid-cols-12 text-[10px] font-mono text-[#8A8A8A] uppercase pb-1.5 border-b border-white/10 px-1">
                  <span className="col-span-2">SET</span>
                  <span className="col-span-3">PREVIOUS</span>
                  <span className="col-span-3">KG</span>
                  <span className="col-span-2">REPS</span>
                  <span className="col-span-2 text-right">LOCK</span>
                </div>

                {/* Sets List */}
                <div className="space-y-2 mt-2">
                  {ex.sets.map((s) => (
                    <div
                      key={s.id}
                      onClick={() => toggleSet(ex.id, s.id)}
                      className={`grid grid-cols-12 items-center p-2 rounded-[12px] border transition cursor-pointer text-xs font-mono ${
                        s.completed
                          ? 'bg-[#E5FE40]/10 border-[#E5FE40]/40 text-white'
                          : 'bg-black/30 border-white/5 text-[#A1A1AA] hover:border-white/20'
                      }`}
                    >
                      <span className="col-span-2 font-bold text-white">#{s.setNum}</span>
                      <span className="col-span-3 text-[11px] text-[#8A8A8A]">{s.prev}</span>
                      <span className="col-span-3 font-bold text-white">{s.weight} kg</span>
                      <span className="col-span-2 font-bold text-white">{s.reps} reps</span>
                      <div className="col-span-2 flex justify-end">
                        <div
                          className={`w-6 h-6 rounded-[8px] flex items-center justify-center border transition ${
                            s.completed
                              ? 'bg-[#E5FE40] border-[#E5FE40] text-black font-bold shadow-[0_0_8px_rgba(229,254,64,0.5)]'
                              : 'border-white/20 bg-black/40'
                          }`}
                        >
                          {s.completed && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* VIEW 2: 1RM STRENGTH CALCULATOR */}
      {activeSubTab === '1rm' && (
        <div className="liquid-glass-elevated rounded-[24px] p-6 border border-white/15 space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-widest">
                BRZYCKI ALGORITHM
              </span>
              <h3 className="text-base font-bold text-white">One Rep Max (1RM) Estimator</h3>
            </div>
            <div className="px-4 py-2 rounded-[14px] bg-[#E5FE40] text-black font-mono font-black text-lg border border-black shadow-[2px_2px_0px_#000]">
              1RM: {estimated1RM} KG
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <label className="text-xs font-mono text-[#8A8A8A] block uppercase">
                LOAD WEIGHT: <strong className="text-white">{calcWeight} KG</strong>
              </label>
              <input
                type="range"
                min="20"
                max="260"
                step="2.5"
                value={calcWeight}
                onChange={(e) => {
                  playHaptic(500, 'sine', 0.02);
                  setCalcWeight(Number(e.target.value));
                }}
                className="w-full accent-[#E5FE40] cursor-pointer"
              />
            </div>

            <div className="space-y-2">
              <label className="text-xs font-mono text-[#8A8A8A] block uppercase">
                REPETITIONS PERFORMED: <strong className="text-white">{calcReps} REPS</strong>
              </label>
              <input
                type="range"
                min="1"
                max="15"
                step="1"
                value={calcReps}
                onChange={(e) => {
                  playHaptic(600, 'sine', 0.02);
                  setCalcReps(Number(e.target.value));
                }}
                className="w-full accent-[#E5FE40] cursor-pointer"
              />
            </div>
          </div>

          {/* Training Percentage Zones */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-2">
            {[
              { label: '100% 1RM (Max)', kg: estimated1RM, desc: 'Neurological Peak' },
              { label: '90% (3-4 Reps)', kg: Math.round(estimated1RM * 0.9), desc: 'Myofibrillar Heavy' },
              { label: '80% (7-8 Reps)', kg: Math.round(estimated1RM * 0.8), desc: 'Hypertrophy Golden' },
              { label: '70% (10-12 Reps)', kg: Math.round(estimated1RM * 0.7), desc: 'Metabolic Stress' },
            ].map((zone, idx) => (
              <div key={idx} className="p-3 rounded-[14px] bg-black/40 border border-white/10 text-center">
                <span className="text-[10px] font-mono text-[#8A8A8A] block uppercase">{zone.label}</span>
                <span className="text-xl font-mono font-black text-[#00F0FF] my-1 block">{zone.kg} kg</span>
                <span className="text-[9px] font-mono text-[#A1A1AA]">{zone.desc}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* VIEW 3: MUSCLE VOLUME RADAR */}
      {activeSubTab === 'muscles' && (
        <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <span className="text-[10px] font-mono text-[#00F0FF] font-black uppercase tracking-widest">
                WEEKLY SET ACCUMULATION
              </span>
              <h3 className="text-base font-bold text-white">Muscle Hypertrophy Volume Distribution</h3>
            </div>
            <span className="text-xs font-mono text-[#10B981] font-bold">54 TOTAL WORKING SETS</span>
          </div>

          <div className="space-y-3">
            {[
              { name: 'Upper Chest / Clavicular', sets: 14, target: 16, pct: 88, color: '#FA114F' },
              { name: 'Lateral Deltoids (Cap)', sets: 18, target: 18, pct: 100, color: '#E5FE40' },
              { name: 'Latissimus Dorsi (V-Taper)', sets: 16, target: 16, pct: 100, color: '#00F0FF' },
              { name: 'Posterior Chain / Hamstrings', sets: 12, target: 14, pct: 85, color: '#8B5CF6' },
              { name: 'Triceps Long Head', sets: 10, target: 12, pct: 83, color: '#10B981' },
            ].map((m, idx) => (
              <div key={idx} className="p-3 rounded-[14px] bg-white/[0.03] border border-white/5 space-y-1.5">
                <div className="flex items-center justify-between text-xs font-mono">
                  <span className="text-white font-bold">{m.name}</span>
                  <span className="text-[#A1A1AA]">
                    {m.sets} / {m.target} sets ({m.pct}%)
                  </span>
                </div>
                <div className="w-full h-2 bg-black/50 rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-700"
                    style={{ width: `${m.pct}%`, backgroundColor: m.color }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
