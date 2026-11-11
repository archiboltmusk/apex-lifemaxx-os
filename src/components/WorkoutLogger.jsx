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

const EXERCISE_LIBRARY = [
  { id: 'barbell_squat', name: 'Barbell Back Squat', muscle: 'Quads', category: 'Legs' },
  { id: 'front_squat', name: 'Barbell Front Squat', muscle: 'Quads', category: 'Legs' },
  { id: 'bulgarian_split', name: 'Bulgarian Split Squat', muscle: 'Quads', category: 'Legs' },
  { id: 'leg_press', name: 'Leg Press', muscle: 'Quads', category: 'Legs' },
  { id: 'rdl', name: 'Romanian Deadlift', muscle: 'Hamstrings', category: 'Legs' },
  { id: 'leg_curl', name: 'Seated Leg Curl', muscle: 'Hamstrings', category: 'Legs' },
  { id: 'hip_thrust', name: 'Barbell Hip Thrust', muscle: 'Glutes', category: 'Legs' },
  { id: 'calf_raise', name: 'Standing Calf Raise', muscle: 'Calves', category: 'Legs' },
  { id: 'bench_press', name: 'Barbell Bench Press', muscle: 'Chest', category: 'Push' },
  { id: 'incline_db', name: 'Incline Dumbbell Press', muscle: 'Upper Chest', category: 'Push' },
  { id: 'weighted_dips', name: 'Parallel Bar Dips', muscle: 'Lower Chest', category: 'Push' },
  { id: 'cable_fly', name: 'Cable Chest Fly', muscle: 'Chest', category: 'Push' },
  { id: 'ohp', name: 'Overhead Barbell Press', muscle: 'Shoulders', category: 'Push' },
  { id: 'db_lateral', name: 'Dumbbell Lateral Raise', muscle: 'Lateral Delts', category: 'Push' },
  { id: 'tricep_pushdown', name: 'Rope Tricep Pushdown', muscle: 'Triceps', category: 'Push' },
  { id: 'overhead_ext', name: 'Overhead Tricep Extension', muscle: 'Triceps', category: 'Push' },
  { id: 'pushups', name: 'Push-Ups', muscle: 'Chest', category: 'Push' },
  { id: 'deadlift', name: 'Conventional Deadlift', muscle: 'Hamstrings', category: 'Pull' },
  { id: 'pullups', name: 'Pull-Ups', muscle: 'Lats', category: 'Pull' },
  { id: 'lat_pulldown', name: 'Wide-Grip Lat Pulldown', muscle: 'Lats', category: 'Pull' },
  { id: 'barbell_row', name: 'Bent-Over Barbell Row', muscle: 'Upper Back', category: 'Pull' },
  { id: 'chest_supported_row', name: 'Chest-Supported Row', muscle: 'Upper Back', category: 'Pull' },
  { id: 'face_pull', name: 'Rope Face Pulls', muscle: 'Rear Delts', category: 'Pull' },
  { id: 'incline_curl', name: 'Incline Dumbbell Curl', muscle: 'Biceps', category: 'Pull' },
  { id: 'hammer_curl', name: 'Dumbbell Hammer Curl', muscle: 'Biceps', category: 'Pull' },
  { id: 'preacher_curl', name: 'Preacher EZ-Bar Curl', muscle: 'Biceps', category: 'Pull' },
  { id: 'hanging_leg_raise', name: 'Hanging Leg Raises', muscle: 'Core', category: 'Core' },
  { id: 'cable_crunch', name: 'Kneeling Cable Crunch', muscle: 'Core', category: 'Core' },
  { id: 'farmers_carry', name: "Heavy Farmer's Carry", muscle: 'Forearms', category: 'Core' },
  { id: 'zone2_erg', name: 'Zone 2 Row / Bike', muscle: 'Quads', category: 'Conditioning' },
];

const SPLIT_TEMPLATES = {
  Push: ['incline_db', 'ohp', 'db_lateral', 'tricep_pushdown'],
  Pull: ['pullups', 'barbell_row', 'face_pull', 'incline_curl'],
  Legs: ['barbell_squat', 'rdl', 'bulgarian_split', 'calf_raise'],
  Full: ['bench_press', 'pullups', 'barbell_squat', 'db_lateral'],
};

const brzycki1RM = (weight, reps) => {
  const w = Number(weight) || 0;
  const r = Math.max(1, Math.min(36, Number(reps) || 1));
  if (w <= 0) return 0;
  return Math.round(w * (36 / (37 - r)));
};

const INITIAL_EXERCISES = SPLIT_TEMPLATES.Push.map((id, idx) => {
  const tpl = EXERCISE_LIBRARY.find((e) => e.id === id) || EXERCISE_LIBRARY[0];
  return {
    id: tpl.id,
    name: tpl.name,
    muscle: tpl.muscle,
    sets: [1, 2, 3].map((n) => ({
      id: idx * 10 + n,
      setNum: n,
      prev: '—',
      weight: id === 'db_lateral' ? 10 : 50,
      reps: 8,
      rpe: 8.0 + n * 0.5,
      completed: false,
    })),
  };
});

export default function WorkoutLogger() {
  const [exercises, setExercises] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_logged_workouts');
      return saved ? JSON.parse(saved) : INITIAL_EXERCISES;
    } catch {
      return INITIAL_EXERCISES;
    }
  });
  const [bestPrByEx, setBestPrByEx] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('apex_strength_prs_v1') || '{}');
    } catch {
      return {};
    }
  });
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [showLibrary, setShowLibrary] = useState(false);
  const [isRestActive, setIsRestActive] = useState(false);
  const [restSeconds, setRestSeconds] = useState(90);
  const [calcWeight, setCalcWeight] = useState(100);
  const [calcReps, setCalcReps] = useState(8);
  const [activeSubTab, setActiveSubTab] = useState('workout'); // 'workout' | 'plan' | '1rm' | 'muscles'
  const [iosMuscles, setIosMuscles] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('apex_ios_muscle_volumes_7d') || '{}')?.volumes || {};
    } catch {
      return {};
    }
  });

  useEffect(() => {
    const syncMuscles = () => {
      try {
        setIosMuscles(JSON.parse(localStorage.getItem('apex_ios_muscle_volumes_7d') || '{}')?.volumes || {});
      } catch {}
    };
    window.addEventListener('apex:muscles-updated', syncMuscles);
    return () => window.removeEventListener('apex:muscles-updated', syncMuscles);
  }, []);

  const persistWorkoutState = (nextExercises, nextPrs = bestPrByEx) => {
    try {
      localStorage.setItem('apex_logged_workouts', JSON.stringify(nextExercises));
      localStorage.setItem('apex_strength_prs_v1', JSON.stringify(nextPrs));
      window.dispatchEvent(new CustomEvent('apex:muscles-updated'));
    } catch {}
  };

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
    let updatedPrs = { ...bestPrByEx };
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
                  const e1rm = brzycki1RM(s.weight, s.reps);
                  if (e1rm > (updatedPrs[ex.name] || 0)) {
                    updatedPrs[ex.name] = e1rm;
                  }
                }
                return { ...s, completed: next };
              }
              return s;
            }),
          };
        }
        return ex;
      });
      setBestPrByEx(updatedPrs);
      persistWorkoutState(updated, updatedPrs);
      return updated;
    });
  };

  const updateSetField = (exerciseId, setId, field, value) => {
    const updated = exercises.map((ex) =>
      ex.id === exerciseId
        ? {
            ...ex,
            sets: ex.sets.map((s) => (s.id === setId ? { ...s, [field]: Math.max(0, Number(value) || 0) } : s)),
          }
        : ex
    );
    setExercises(updated);
    persistWorkoutState(updated);
  };

  const addSetToExercise = (exerciseId) => {
    playPlunk();
    const updated = exercises.map((ex) => {
      if (ex.id !== exerciseId) return ex;
      const last = ex.sets[ex.sets.length - 1] || { weight: 40, reps: 8, rpe: 8.0 };
      const nextNum = ex.sets.length + 1;
      return {
        ...ex,
        sets: [
          ...ex.sets,
          { id: Date.now() + nextNum, setNum: nextNum, prev: `${last.weight}x${last.reps}`, weight: last.weight, reps: last.reps, rpe: last.rpe || 8.0, completed: false },
        ],
      };
    });
    setExercises(updated);
    persistWorkoutState(updated);
  };

  const applySplitTemplate = (splitName) => {
    playPlunk();
    const ids = SPLIT_TEMPLATES[splitName] || [];
    const nextExercises = ids.map((id, idx) => {
      const tpl = EXERCISE_LIBRARY.find((e) => e.id === id) || EXERCISE_LIBRARY[0];
      return {
        id: `${tpl.id}-${Date.now()}-${idx}`,
        name: tpl.name,
        muscle: tpl.muscle,
        sets: [1, 2, 3].map((n) => ({
          id: Date.now() + idx * 10 + n,
          setNum: n,
          prev: '—',
          weight: tpl.category === 'Legs' ? 60 : 40,
          reps: 8,
          rpe: 8.0,
          completed: false,
        })),
      };
    });
    setExercises(nextExercises);
    persistWorkoutState(nextExercises);
  };

  const addExerciseFromLibrary = (item) => {
    playPlunk();
    const entry = {
      id: `${item.id}-${Date.now()}`,
      name: item.name,
      muscle: item.muscle,
      sets: [1, 2, 3].map((n) => ({
        id: Date.now() + n,
        setNum: n,
        prev: '—',
        weight: item.category === 'Legs' ? 60 : 30,
        reps: 8,
        rpe: 8.0,
        completed: false,
      })),
    };
    const next = [...exercises, entry];
    setExercises(next);
    persistWorkoutState(next);
    setShowLibrary(false);
  };

  // Live readiness read for Adaptive 4-Week Plan
  const readLiveReadiness = () => {
    try {
      const h = JSON.parse(localStorage.getItem('apex_health_data') || '{}');
      const rdy = h?.bevel?.readiness;
      if (rdy > 0) return rdy;
      const hrv = h?.metrics?.hrv?.value || 0;
      const rhr = h?.metrics?.restingHeartRate?.value || 0;
      if (hrv > 0 && rhr > 0) return Math.min(99, Math.max(35, Math.round(50 + (hrv - 50) * 0.5 - (rhr - 55) * 0.6)));
    } catch {}
    return null;
  };
  const liveReadiness = readLiveReadiness();

  // Real muscle volume computed strictly from completed sets + iPhone HealthKit sync
  const localMuscleTotals = exercises.reduce((acc, ex) => {
    const done = ex.sets.filter((s) => s.completed).length;
    if (done > 0) acc[ex.muscle] = (acc[ex.muscle] || 0) + done;
    return acc;
  }, {});
  const combinedMuscleMap = { ...localMuscleTotals };
  Object.entries(iosMuscles || {}).forEach(([k, v]) => {
    combinedMuscleMap[k] = (combinedMuscleMap[k] || 0) + Number(v || 0);
  });
  const totalRealSets = Object.values(combinedMuscleMap).reduce((s, n) => s + n, 0);

  // 1RM Brzycki Calculation
  const estimated1RM = brzycki1RM(calcWeight, calcReps);

  return (
    <div className="space-y-6">
      {/* SUB-NAVIGATION PILLS */}
      <div className="flex flex-wrap items-center gap-2 border-b border-white/10 pb-3">
        {[
          { id: 'workout', label: 'Strength Builder Pro', icon: Dumbbell },
          { id: 'plan', label: 'Adaptive 4-Week Plan', icon: Flame },
          { id: '1rm', label: '1RM PR Calculator', icon: Calculator },
          { id: 'muscles', label: 'Muscular Load', icon: TrendingUp },
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

          {/* SPLIT TEMPLATES & 30-EXERCISE LIBRARY */}
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex flex-wrap items-center gap-1.5">
              {Object.keys(SPLIT_TEMPLATES).map((split) => (
                <button
                  key={split}
                  onClick={() => applySplitTemplate(split)}
                  className="px-3 py-1.5 rounded-[10px] bg-white/5 hover:bg-white/15 border border-white/10 text-xs font-mono font-bold text-white transition"
                >
                  {split} Split
                </button>
              ))}
            </div>
            <button
              onClick={() => setShowLibrary((v) => !v)}
              className="px-3.5 py-1.5 rounded-[10px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 text-xs font-mono font-black text-[#00F0FF] flex items-center space-x-1"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{showLibrary ? 'Close Library' : 'Add from 30 Exercises'}</span>
            </button>
          </div>

          {showLibrary && (
            <div className="liquid-glass rounded-[20px] p-4 border border-[#00F0FF]/30 space-y-3">
              <div className="flex flex-wrap items-center gap-2">
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search 30 exercises by name or muscle..."
                  className="flex-1 min-w-[200px] px-3 py-2 rounded-[10px] bg-black/50 border border-white/15 text-xs font-mono text-white"
                />
                {['All', 'Push', 'Pull', 'Legs', 'Core', 'Conditioning'].map((cat) => (
                  <button
                    key={cat}
                    onClick={() => setSelectedCategory(cat)}
                    className={`px-2.5 py-1 rounded-[8px] text-[11px] font-mono font-bold ${
                      selectedCategory === cat ? 'bg-[#E5FE40] text-black' : 'bg-white/5 text-[#8A8A8A]'
                    }`}
                  >
                    {cat}
                  </button>
                ))}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2 max-h-56 overflow-y-auto">
                {EXERCISE_LIBRARY.filter(
                  (e) =>
                    (selectedCategory === 'All' || e.category === selectedCategory) &&
                    (e.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                      e.muscle.toLowerCase().includes(searchQuery.toLowerCase()))
                ).map((item) => (
                  <button
                    key={item.id}
                    onClick={() => addExerciseFromLibrary(item)}
                    className="p-2.5 rounded-[12px] bg-black/40 hover:bg-white/10 border border-white/10 text-left flex items-center justify-between"
                  >
                    <div>
                      <div className="text-xs font-bold text-white">{item.name}</div>
                      <div className="text-[10px] font-mono text-[#00F0FF]">{item.muscle} · {item.category}</div>
                    </div>
                    <Plus className="w-3.5 h-3.5 text-[#E5FE40]" />
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* EXERCISE LIST */}
          <div className="space-y-4">
            {exercises.map((ex) => {
              const prKg = bestPrByEx[ex.name] || 0;
              return (
                <div key={ex.id} className="liquid-glass rounded-[22px] p-5 border border-white/10">
                  <div className="flex items-center justify-between mb-3">
                    <div>
                      <h4 className="text-sm font-bold text-white tracking-tight">{ex.name}</h4>
                      <span className="text-[10px] font-mono text-[#00F0FF]">{ex.muscle}</span>
                    </div>
                    <div className="flex items-center space-x-2">
                      {prKg > 0 && (
                        <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-[#E5FE40]/20 text-[#E5FE40] border border-[#E5FE40]/40 font-black">
                          PR 1RM {prKg} kg
                        </span>
                      )}
                      <button
                        onClick={() => addSetToExercise(ex.id)}
                        className="text-[10px] font-mono px-2.5 py-1 rounded bg-white/10 hover:bg-white/20 text-white font-bold"
                      >
                        + Set
                      </button>
                    </div>
                  </div>

                  {/* Sets Header */}
                  <div className="grid grid-cols-12 text-[10px] font-mono text-[#8A8A8A] uppercase pb-1.5 border-b border-white/10 px-1">
                    <span className="col-span-2">SET</span>
                    <span className="col-span-3">KG</span>
                    <span className="col-span-2">REPS</span>
                    <span className="col-span-3">RPE / 1RM</span>
                    <span className="col-span-2 text-right">LOCK</span>
                  </div>

                  {/* Sets List */}
                  <div className="space-y-2 mt-2">
                    {ex.sets.map((s) => {
                      const set1RM = brzycki1RM(s.weight, s.reps);
                      return (
                        <div
                          key={s.id}
                          className={`grid grid-cols-12 items-center gap-1.5 p-2 rounded-[12px] border transition text-xs font-mono ${
                            s.completed
                              ? 'bg-[#E5FE40]/10 border-[#E5FE40]/40 text-white'
                              : 'bg-black/30 border-white/5 text-[#A1A1AA]'
                          }`}
                        >
                          <span className="col-span-2 font-bold text-white">#{s.setNum}</span>
                          <div className="col-span-3">
                            <input
                              type="number"
                              value={s.weight}
                              onChange={(e) => updateSetField(ex.id, s.id, 'weight', e.target.value)}
                              className="w-16 px-2 py-1 rounded bg-black/60 border border-white/15 text-white font-bold text-xs"
                            />
                          </div>
                          <div className="col-span-2">
                            <input
                              type="number"
                              value={s.reps}
                              onChange={(e) => updateSetField(ex.id, s.id, 'reps', e.target.value)}
                              className="w-12 px-2 py-1 rounded bg-black/60 border border-white/15 text-white font-bold text-xs"
                            />
                          </div>
                          <span className="col-span-3 text-[11px] text-[#00F0FF]">
                            RPE {s.rpe || 8} · {set1RM}kg
                          </span>
                          <div className="col-span-2 flex justify-end">
                            <button
                              onClick={() => toggleSet(ex.id, s.id)}
                              className={`w-7 h-7 rounded-[8px] flex items-center justify-center border transition ${
                                s.completed
                                  ? 'bg-[#E5FE40] border-[#E5FE40] text-black font-bold shadow-[0_0_8px_rgba(229,254,64,0.5)]'
                                  : 'border-white/20 bg-black/40'
                              }`}
                            >
                              {s.completed && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* VIEW: ADAPTIVE 4-WEEK PLAN */}
      {activeSubTab === 'plan' && (
        <div className="liquid-glass-elevated rounded-[24px] p-6 border border-white/15 space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-widest">
                HRV-GATED HYPERTROPHY &amp; STRENGTH PROGRESSION
              </span>
              <h3 className="text-base font-bold text-white">Adaptive 4-Week Training Mesocycle</h3>
            </div>
            <span className="text-xs font-mono px-3 py-1 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-bold">
              {liveReadiness != null ? `LIVE READINESS ${liveReadiness}%` : 'CONNECT HEALTH FOR AUTOREGULATION'}
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 font-mono">
            {[
              { week: 'Week 1', title: 'Technical Accumulate', rpe: 'RPE 7.5', vol: '12 sets/muscle' },
              { week: 'Week 2', title: 'Volume Escalation', rpe: 'RPE 8.5', vol: '15 sets/muscle' },
              { week: 'Week 3', title: 'Overreach Peak', rpe: 'RPE 9.5', vol: '18 sets/muscle' },
              { week: 'Week 4', title: 'Autonomic Deload', rpe: 'RPE 6.5', vol: '8 sets/muscle' },
            ].map((w) => {
              const deloadOverride = liveReadiness != null && liveReadiness < 50;
              return (
                <div key={w.week} className="p-4 rounded-[16px] bg-black/40 border border-white/10 space-y-1.5">
                  <span className="text-[10px] text-[#E5FE40] font-black uppercase">{w.week}</span>
                  <div className="text-sm font-bold text-white">{w.title}</div>
                  <div className="text-xs text-[#00F0FF]">
                    {deloadOverride && w.week !== 'Week 4' ? 'Scaled: RPE 7.0 (-20%)' : w.rpe}
                  </div>
                  <div className="text-[11px] text-[#8A8A8A]">{w.vol}</div>
                </div>
              );
            })}
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
                WEEKLY SET ACCUMULATION (MAC + IPHONE CONTINUITY)
              </span>
              <h3 className="text-base font-bold text-white">Real Muscular Load Distribution</h3>
            </div>
            <span className="text-xs font-mono text-[#10B981] font-bold">{totalRealSets} COMPLETED SETS</span>
          </div>

          {totalRealSets === 0 ? (
            <div className="p-4 rounded-[14px] bg-black/40 border border-dashed border-white/15 text-xs font-mono text-[#A1A1AA]">
              No working sets completed yet. Lock completed sets in Strength Builder Pro or sync a session from iPhone Train to plot real muscular load.
            </div>
          ) : (
            <div className="space-y-3">
              {Object.entries(combinedMuscleMap).map(([muscle, sets]) => {
                const target = 16;
                const pct = Math.min(100, Math.round((sets / target) * 100));
                return (
                  <div key={muscle} className="p-3 rounded-[14px] bg-white/[0.03] border border-white/5 space-y-1.5">
                    <div className="flex items-center justify-between text-xs font-mono">
                      <span className="text-white font-bold">{muscle}</span>
                      <span className="text-[#A1A1AA]">
                        {sets} / {target} sets ({pct}%)
                      </span>
                    </div>
                    <div className="w-full h-2 bg-black/50 rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all duration-700 bg-[#00F0FF]"
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
