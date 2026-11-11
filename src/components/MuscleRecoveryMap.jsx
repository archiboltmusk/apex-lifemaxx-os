import React, { useState, useEffect } from 'react';
import { Dumbbell, Activity, ShieldCheck, Flame, Clock, Sliders, Plus, Minus, CheckCircle, AlertTriangle } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';

const DEFAULT_MUSCLE_DATA = {
  upper_pecs: {
    name: 'Upper Pectorals (Clavicular)',
    recovery: 92,
    status: 'OPTIMAL SUPERCOMPENSATION',
    color: '#10B981',
    mev: 8,
    mav: 16,
    mrv: 22,
    setsWeek: 14,
    exercises: ['30° Incline DB Press', 'Low-to-High Cable Crossover', 'Smith Incline Press'],
  },
  lower_pecs: {
    name: 'Sternal & Lower Pectorals',
    recovery: 88,
    status: 'READY FOR OVERLOAD',
    color: '#10B981',
    mev: 6,
    mav: 14,
    mrv: 20,
    setsWeek: 12,
    exercises: ['Weighted Chest Dips', 'Flat Barbell Bench', 'Deficit Push-Ups'],
  },
  lateral_delts: {
    name: 'Lateral Deltoids (Cap Width)',
    recovery: 100,
    status: 'FULLY RESTORED & PRIMED',
    color: '#E5FE40',
    mev: 10,
    mav: 18,
    mrv: 26,
    setsWeek: 18,
    exercises: ['Cable Lateral Raises', 'DB Lu Raises', 'Behind-the-Back Cable Raises'],
  },
  rear_delts: {
    name: 'Posterior Deltoids (3D Look)',
    recovery: 95,
    status: 'RECOVERY OPTIMAL',
    color: '#10B981',
    mev: 8,
    mav: 16,
    mrv: 24,
    setsWeek: 14,
    exercises: ['Face Pulls (External Rotation)', 'Reverse Pec Deck', 'Incline Y-Raises'],
  },
  lats: {
    name: 'Latissimus Dorsi (V-Taper Sweep)',
    recovery: 68,
    status: 'RECOVERING (ATP SYNTHESIS)',
    color: '#F59E0B',
    mev: 10,
    mav: 16,
    mrv: 22,
    setsWeek: 16,
    exercises: ['Weighted Neutral Pull-Ups', 'Single-Arm Iliac Lat Pulldown', 'Meadows Row'],
  },
  upper_back: {
    name: 'Trapezius & Rhomboids',
    recovery: 90,
    status: 'SUPERCOMPENSATION',
    color: '#10B981',
    mev: 8,
    mav: 14,
    mrv: 20,
    setsWeek: 12,
    exercises: ['Chest-Supported T-Bar Row', 'Kelso Shrugs', 'Snatch-Grip High Pulls'],
  },
  quads: {
    name: 'Quadriceps (Vastus Medialis & Lateralis)',
    recovery: 95,
    status: 'PRIMED FOR MAX 1RM',
    color: '#10B981',
    mev: 8,
    mav: 14,
    mrv: 20,
    setsWeek: 12,
    exercises: ['Hack Squats', 'Bulgarian Split Squats', 'Full-ROM Leg Extensions'],
  },
  hamstrings: {
    name: 'Hamstrings & Posterior Chain',
    recovery: 45,
    status: 'FATIGUED (REPAIR IN PROGRESS)',
    color: '#FA114F',
    mev: 6,
    mav: 12,
    mrv: 18,
    setsWeek: 10,
    exercises: ['Romanian Deadlifts (RDL)', 'Seated Leg Curls', 'Nordic Hamstring Drops'],
  },
  glutes: {
    name: 'Gluteus Maximus & Medius',
    recovery: 85,
    status: 'RESTORED & ACTIVE',
    color: '#10B981',
    mev: 6,
    mav: 12,
    mrv: 18,
    setsWeek: 10,
    exercises: ['Barbell Hip Thrusts', 'Cable Kickbacks', 'Walking DB Lunges'],
  },
  triceps: {
    name: 'Triceps Brachii (Long & Lateral Head)',
    recovery: 92,
    status: 'READY FOR STIMULUS',
    color: '#10B981',
    mev: 6,
    mav: 14,
    mrv: 20,
    setsWeek: 12,
    exercises: ['Overhead Cable Tricep Extension', 'Cross-Body Tricep Pressdown', 'JM Press'],
  },
  biceps: {
    name: 'Biceps Brachii & Brachialis',
    recovery: 90,
    status: 'SUPERCOMPENSATION',
    color: '#10B981',
    mev: 8,
    mav: 14,
    mrv: 20,
    setsWeek: 12,
    exercises: ['Incline DB Curls (Max Stretch)', 'Bayesian Cable Curls', 'Hammer Curls'],
  },
  calves: {
    name: 'Gastrocnemius & Soleus',
    recovery: 98,
    status: 'HIGHLY RECOVERED',
    color: '#E5FE40',
    mev: 8,
    mav: 16,
    mrv: 24,
    setsWeek: 14,
    exercises: ['Standing Calf Raises (3s Pause)', 'Seated Calf Raises', 'Donkey Calf Machine'],
  },
  core: {
    name: 'Rectus & Transverse Abdominis',
    recovery: 100,
    status: 'FULL RIGIDITY & STABILITY',
    color: '#E5FE40',
    mev: 4,
    mav: 10,
    mrv: 16,
    setsWeek: 8,
    exercises: ['Hanging Leg Raises', 'Ab Wheel Rollouts', 'Vacuum Stomach Holds'],
  },
  forearms: {
    name: 'Wrist Flexors, Extensors & Grip',
    recovery: 96,
    status: 'GRIP PRIMED',
    color: '#10B981',
    mev: 6,
    mav: 12,
    mrv: 18,
    setsWeek: 8,
    exercises: ['Barbell Wrist Curls', 'Dead Hangs', 'Fat Grip DB Holds'],
  },
};

export default function MuscleRecoveryMap() {
  const [muscleData, setMuscleData] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_muscle_volume_data');
      if (saved) return JSON.parse(saved);
    } catch {}
    const zeroed = {};
    Object.entries(DEFAULT_MUSCLE_DATA).forEach(([k, v]) => {
      zeroed[k] = { ...v, setsWeek: 0, recovery: null, status: 'AWAITING LOG' };
    });
    return zeroed;
  });

  const [selectedMuscle, setSelectedMuscle] = useState('upper_pecs');

  useEffect(() => {
    const syncExternalMuscles = () => {
      try {
        const iosVolumes = JSON.parse(localStorage.getItem('apex_ios_muscle_volumes_7d') || '{}')?.volumes || {};
        const localWorkouts = JSON.parse(localStorage.getItem('apex_logged_workouts') || '[]');
        const mapKey = (name = '') => {
          const l = name.toLowerCase();
          if (l.includes('upper chest') || l.includes('incline')) return 'upper_pecs';
          if (l.includes('chest') || l.includes('pec')) return 'lower_pecs';
          if (l.includes('lateral')) return 'lateral_delts';
          if (l.includes('rear') || l.includes('shoulder')) return 'rear_delts';
          if (l.includes('lat')) return 'lats';
          if (l.includes('back') || l.includes('trap')) return 'upper_back';
          if (l.includes('quad')) return 'quads';
          if (l.includes('hamstring')) return 'hamstrings';
          if (l.includes('glute')) return 'glutes';
          if (l.includes('tricep')) return 'triceps';
          if (l.includes('bicep')) return 'biceps';
          if (l.includes('calv')) return 'calves';
          if (l.includes('core')) return 'core';
          if (l.includes('forearm')) return 'forearms';
          return null;
        };

        const aggregated = {};
        Object.entries(iosVolumes).forEach(([muscleName, sets]) => {
          const key = mapKey(muscleName);
          if (key) aggregated[key] = (aggregated[key] || 0) + Number(sets || 0);
        });
        localWorkouts.forEach((ex) => {
          const done = Array.isArray(ex.sets) ? ex.sets.filter((s) => s.completed).length : 0;
          const key = mapKey(ex.muscle || ex.name);
          if (key && done > 0) aggregated[key] = (aggregated[key] || 0) + done;
        });

        if (Object.keys(aggregated).length > 0) {
          setMuscleData((prev) => {
            const next = { ...prev };
            Object.entries(aggregated).forEach(([k, setsCount]) => {
              if (!next[k]) return;
              const curr = next[k];
              const rec = Math.max(40, Math.round(100 - (setsCount / curr.mrv) * 55));
              next[k] = {
                ...curr,
                setsWeek: setsCount,
                recovery: rec,
                status: setsCount <= curr.mav ? 'OPTIMAL STIMULUS' : 'FATIGUED / OVERLOAD',
              };
            });
            localStorage.setItem('apex_muscle_volume_data', JSON.stringify(next));
            return next;
          });
        }
      } catch {}
    };

    syncExternalMuscles();
    window.addEventListener('apex:muscles-updated', syncExternalMuscles);
    return () => window.removeEventListener('apex:muscles-updated', syncExternalMuscles);
  }, []);

  const active = muscleData[selectedMuscle] || muscleData.upper_pecs;

  const handleAdjustSets = (delta) => {
    playPlunk();
    setMuscleData((prev) => {
      const curr = prev[selectedMuscle];
      const newSets = Math.max(0, curr.setsWeek + delta);
      const computedRec = newSets > 0 ? Math.max(40, Math.round(100 - (newSets / curr.mrv) * 55)) : null;
      const updated = {
        ...prev,
        [selectedMuscle]: {
          ...curr,
          setsWeek: newSets,
          recovery: computedRec,
          status: newSets === 0 ? 'AWAITING LOG' : newSets <= curr.mav ? 'OPTIMAL STIMULUS' : 'FATIGUED / OVERLOAD',
        },
      };
      try {
        localStorage.setItem('apex_muscle_volume_data', JSON.stringify(updated));
      } catch {}
      return updated;
    });
  };

  // Determine Volume Landmark Tier
  const getVolumeStatus = (sets, mev, mav, mrv) => {
    if (sets < mev) {
      return { label: 'UNDER-TRAINED (< MEV)', color: '#8A8A8A', desc: 'Volume below maintenance threshold. Increase sets to grow.' };
    }
    if (sets >= mev && sets <= mav) {
      return { label: 'PEAK HYPERTROPHY ZONE (MAV)', color: '#10B981', desc: 'Optimal sweet spot for muscle protein synthesis.' };
    }
    if (sets > mav && sets <= mrv) {
      return { label: 'HIGH VOLUME OVERLOAD', color: '#E5FE40', desc: 'Productive but taxing. Monitor recovery closely.' };
    }
    return { label: 'OVERTRAINING RISK (> MRV)', color: '#FA114F', desc: 'Systemic exhaustion. Exceeds muscle recovery capacity.' };
  };

  const volumeStatus = getVolumeStatus(active.setsWeek, active.mev, active.mav, active.mrv);

  const totalSetsLogged = Object.values(muscleData).reduce((sum, m) => sum + (m.setsWeek || 0), 0);
  const systemicRecoveryText =
    totalSetsLogged > 0
      ? `${totalSetsLogged} WEEKLY SETS LOGGED · ACTIVE HYPERTROPHY`
      : '0 SETS LOGGED · TAP MUSCLE TO RECORD VOLUME';

  return (
    <div className="space-y-6">
      {/* MUSCLE HEATMAP HERO */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-widest">
              RENAISSANCE PERIODIZATION // HYPERTROPHY VOLUME LANDMARKS
            </span>
            <h3 className="text-base font-bold text-white tracking-tight">
              14-Muscle Fatigue Heatmap & Volume Matrix (MEV / MAV / MRV)
            </h3>
          </div>
          <span className="text-xs font-mono px-3 py-1 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-bold">
            {systemicRecoveryText}
          </span>
        </div>

        {/* 14 Muscle Selectors */}
        <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-7 gap-2">
          {Object.entries(muscleData).map(([key, m]) => {
            const isSelected = selectedMuscle === key;
            return (
              <button
                key={key}
                onClick={() => {
                  playPlunk();
                  setSelectedMuscle(key);
                }}
                className={`p-2.5 rounded-[14px] text-left transition font-mono border ${
                  isSelected
                    ? 'bg-white/15 border-white/40 shadow-[0_0_15px_rgba(255,255,255,0.15)]'
                    : 'bg-white/[0.03] border-white/5 hover:border-white/20'
                }`}
              >
                <div className="flex items-center justify-between mb-1">
                  <span className="text-[9px] font-bold text-white truncate max-w-[85px]">
                    {m.name.split(' ')[0]}
                  </span>
                  <span
                    className="text-[9px] font-black px-1.5 py-0.5 rounded"
                    style={{ backgroundColor: `${m.color}20`, color: m.color }}
                  >
                    {m.recovery != null ? `${m.recovery}%` : '—'}
                  </span>
                </div>
                <div className="text-[10px] text-[#8A8A8A]">
                  <strong className="text-white">{m.setsWeek}</strong> / {m.mav} sets
                </div>
              </button>
            );
          })}
        </div>

        {/* Selected Muscle Deep-Dive Inspector */}
        <div className="p-5 rounded-[20px] bg-black/60 border border-white/10 space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <span className="text-[10px] font-mono text-[#8A8A8A] uppercase">ACTIVE MUSCLE GROUP</span>
              <h4 className="text-lg font-black text-white">{active.name}</h4>
              <span
                className="inline-block mt-1 text-[10px] font-mono font-black px-2.5 py-0.5 rounded-full border"
                style={{
                  backgroundColor: `${volumeStatus.color}20`,
                  color: volumeStatus.color,
                  borderColor: `${volumeStatus.color}40`,
                }}
              >
                {volumeStatus.label}
              </span>
            </div>

            {/* Set Counter Controls */}
            <div className="flex items-center space-x-3 bg-white/5 p-2 rounded-[14px] border border-white/10 font-mono">
              <span className="text-xs text-[#8A8A8A] font-bold">SETS THIS WEEK:</span>
              <div className="flex items-center space-x-2">
                <button
                  onClick={() => handleAdjustSets(-1)}
                  className="w-7 h-7 rounded-[8px] bg-white/10 hover:bg-white/20 flex items-center justify-center text-white"
                >
                  <Minus className="w-3.5 h-3.5" />
                </button>
                <span className="text-lg font-black text-white w-8 text-center">{active.setsWeek}</span>
                <button
                  onClick={() => handleAdjustSets(1)}
                  className="w-7 h-7 rounded-[8px] bg-[#E5FE40] hover:bg-[#E5FE40]/80 text-black flex items-center justify-center font-bold"
                >
                  <Plus className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          </div>

          {/* RP Volume Landmarks Bar */}
          <div className="space-y-1.5 font-mono text-xs">
            <div className="flex items-center justify-between text-[11px] text-[#8A8A8A]">
              <span>MEV (Maintenance): {active.mev} sets</span>
              <span className="text-[#10B981] font-bold">MAV (Hypertrophy Peak): {active.mav} sets</span>
              <span className="text-[#FA114F]">MRV (Overload Ceiling): {active.mrv} sets</span>
            </div>

            <div className="w-full h-3 rounded-full bg-white/10 overflow-hidden relative">
              <div
                className="h-full transition-all duration-500 rounded-full"
                style={{
                  width: `${Math.min(100, (active.setsWeek / active.mrv) * 100)}%`,
                  backgroundColor: volumeStatus.color,
                }}
              />
            </div>
            <p className="text-[11px] text-[#A1A1AA] mt-1">{volumeStatus.desc}</p>
          </div>

          {/* Golden Era Hypertrophy Exercises for this muscle */}
          <div className="pt-2 border-t border-white/10">
            <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-wider block mb-2">
              ⭐ GOLDEN RATIO EXERCISES (MAX TENSION & STRETCH):
            </span>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              {active.exercises.map((ex, idx) => (
                <div key={idx} className="p-2.5 rounded-[12px] bg-white/[0.04] border border-white/5 font-mono text-xs text-white">
                  {ex}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
