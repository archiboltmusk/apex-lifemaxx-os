import React, { useState, useEffect } from 'react';
import { ShieldCheck, Check, TrendingUp, FlaskConical } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';

const DEFAULT_HABITS = [
  { id: 'h1', title: 'Cryo Plunge (4°C for 3m)', impact: 'Autonomic', desc: 'Tracks catecholamine response & next-morning vagal tone', checked: false },
  { id: 'h2', title: '15m Direct Morning Lux', impact: 'Circadian', desc: 'Anchors suprachiasmatic clock & evening melatonin onset', checked: false },
  { id: 'h3', title: 'Evening Nasal Breathing', impact: 'Sleep Quality', desc: 'Reduces mouth dryness & overnight heart rate drift', checked: false },
  { id: 'h4', title: 'Magnesium L-Threonate (144mg)', impact: 'REM / Deep', desc: 'Supports slow-wave neural down-regulation', checked: false },
  { id: 'h5', title: 'Finish Dinner 3h Before Bed', impact: 'Resting HR', desc: 'Minimizes thermic digestive elevation of sleeping RHR', checked: false },
  { id: 'h6', title: 'No Caffeine After 12 PM', impact: 'Sleep Architecture', desc: 'Preserves deep N3 sleep pressure via adenosine receptor clearance', checked: false },
  { id: 'h7', title: 'Alcohol-Free Protocol (0g)', impact: 'HRV Guard', desc: 'Prevents acute parasympathetic suppression & REM fragmentation', checked: false },
];

export default function HabitCorrelations() {
  const [habits, setHabits] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_habit_journal_v1');
      if (saved) return JSON.parse(saved);
    } catch {}
    return DEFAULT_HABITS;
  });

  const [syncedExperiment, setSyncedExperiment] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_active_experiment');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  const [syncedHrv, setSyncedHrv] = useState(() => {
    try {
      const h = JSON.parse(localStorage.getItem('apex_health_data') || 'null');
      return h?.metrics?.hrv?.value || null;
    } catch {
      return null;
    }
  });

  useEffect(() => {
    const onSync = () => {
      try {
        const exp = localStorage.getItem('apex_active_experiment');
        if (exp) setSyncedExperiment(JSON.parse(exp));
        const h = JSON.parse(localStorage.getItem('apex_health_data') || 'null');
        if (h?.metrics?.hrv?.value) setSyncedHrv(h.metrics.hrv.value);
      } catch {}
    };
    window.addEventListener('appleHealthSync', onSync);
    return () => window.removeEventListener('appleHealthSync', onSync);
  }, []);

  const toggleHabit = (id) => {
    playPlunk();
    setHabits((prev) => {
      const nextList = prev.map((h) => {
        if (h.id === id) {
          const next = !h.checked;
          if (next) playCoinChime();
          return { ...h, checked: next };
        }
        return h;
      });
      try {
        localStorage.setItem('apex_habit_journal_v1', JSON.stringify(nextList));
      } catch {}
      return nextList;
    });
  };

  return (
    <div className="space-y-6">
      <div className="liquid-glass-elevated rounded-[24px] p-6 border border-white/15">
        <div className="flex items-center justify-between mb-4">
          <div>
            <span className="text-[10px] font-mono text-[#10B981] font-black uppercase tracking-widest">
              N-OF-1 JOURNAL CORRELATION MATRIX
            </span>
            <h3 className="text-base font-bold text-white tracking-tight">
              Behavioral Protocol Adherence &amp; HealthKit Pairing
            </h3>
          </div>
          <span className="text-xs font-mono px-3 py-1 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-bold">
            {syncedHrv ? `${syncedHrv}ms HRV BASELINE` : 'SYNC HEALTHKIT FOR HRV'}
          </span>
        </div>

        {syncedExperiment && (
          <div className="mb-4 p-4 rounded-[18px] bg-[#00F0FF]/10 border border-[#00F0FF]/30 flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center space-x-3">
              <FlaskConical className="w-5 h-5 text-[#00F0FF]" />
              <div>
                <div className="text-xs font-mono font-bold text-white">
                  iPhone Trial: {syncedExperiment.protocol}
                </div>
                <div className="text-[11px] font-mono text-[#A1A1AA]">
                  {syncedExperiment.onDays || 0} On days ·{' '}
                  {syncedExperiment.adheredToday ? 'Adhered today' : 'Control / Off today'}
                </div>
              </div>
            </div>
            <div className="flex items-center space-x-3 text-xs font-mono font-bold">
              <span className="text-[#10B981]">
                HRV {syncedExperiment.hrvDeltaPct >= 0 ? '+' : ''}
                {Number(syncedExperiment.hrvDeltaPct || 0).toFixed(0)}%
              </span>
              <span className="text-[#00F0FF]">
                RHR {syncedExperiment.rhrDeltaBpm >= 0 ? '+' : ''}
                {Number(syncedExperiment.rhrDeltaBpm || 0).toFixed(1)} bpm
              </span>
            </div>
          </div>
        )}

        <p className="text-xs text-[#A1A1AA] mb-4">
          Check off completed daily interventions below or log paired On/Control days in the iPhone Experiment Lab to compute real next-morning HRV &amp; resting heart rate deltas.
        </p>

        {/* Habit list */}
        <div className="space-y-2.5">
          {habits.map((habit) => (
            <div
              key={habit.id}
              onClick={() => toggleHabit(habit.id)}
              className={`p-3.5 rounded-[16px] border transition cursor-pointer flex items-center justify-between ${
                habit.checked
                  ? 'bg-white/[0.04] border-white/15'
                  : 'bg-black/30 border-white/5 opacity-75'
              }`}
            >
              <div className="flex items-center space-x-3.5">
                <div
                  className={`w-6 h-6 rounded-[8px] flex items-center justify-center border transition ${
                    habit.checked
                      ? 'bg-[#10B981] border-[#10B981] text-black font-bold shadow-[0_0_8px_rgba(16,185,129,0.5)]'
                      : 'border-white/20 bg-black/40'
                  }`}
                >
                  {habit.checked && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                </div>
                <div>
                  <h4 className="text-xs font-mono font-bold text-white">{habit.title}</h4>
                  <span className="text-[11px] text-[#8A8A8A]">{habit.desc}</span>
                </div>
              </div>

              <div className="flex items-center space-x-1.5 px-2.5 py-1 rounded-full bg-[#10B981]/15 border border-[#10B981]/30 text-xs font-mono font-bold text-[#10B981]">
                <TrendingUp className="w-3.5 h-3.5" />
                <span>{habit.impact}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
