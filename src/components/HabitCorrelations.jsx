import React, { useState, useEffect } from 'react';
import { ShieldCheck, Check, TrendingUp, FlaskConical, Tag } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';

const JOURNAL_TAG_PRESETS = [
  { id: 'hydration', label: 'Hydration' },
  { id: 'caffeine_cutoff', label: 'Caffeine Cutoff' },
  { id: 'late_meal', label: 'Late Meal' },
  { id: 'alcohol', label: 'Alcohol' },
  { id: 'cold_plunge', label: 'Cold Plunge' },
  { id: 'sauna', label: 'Sauna' },
  { id: 'sunlight', label: 'Sunlight' },
  { id: 'magnesium', label: 'Magnesium' },
  { id: 'creatine', label: 'Creatine' },
  { id: 'high_stress', label: 'High Stress' },
  { id: 'nasal_tape', label: 'Nasal Tape' },
];

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

  const todayIsoKey = new Date().toISOString().slice(0, 10);
  const [dailyTagsByDate, setDailyTagsByDate] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('apex_daily_journal_tags_v1') || '{}');
    } catch {
      return {};
    }
  });
  const [outcomesByDate, setOutcomesByDate] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('apex_journal_outcomes_v1') || '{}');
    } catch {
      return {};
    }
  });

  useEffect(() => {
    const captureTodayOutcome = () => {
      try {
        const exp = localStorage.getItem('apex_active_experiment');
        if (exp) setSyncedExperiment(JSON.parse(exp));
        const h = JSON.parse(localStorage.getItem('apex_health_data') || 'null');
        const hrv = h?.metrics?.hrv?.value || null;
        const rhr = h?.metrics?.restingHeartRate?.value || null;
        if (hrv) setSyncedHrv(hrv);
        if (hrv || rhr) {
          setOutcomesByDate((prev) => {
            const next = { ...prev, [todayIsoKey]: { hrv, rhr } };
            localStorage.setItem('apex_journal_outcomes_v1', JSON.stringify(next));
            return next;
          });
        }
        const savedTags = JSON.parse(localStorage.getItem('apex_daily_journal_tags_v1') || '{}');
        setDailyTagsByDate(savedTags);
      } catch {}
    };

    captureTodayOutcome();
    window.addEventListener('appleHealthSync', captureTodayOutcome);
    window.addEventListener('apex:journal-updated', captureTodayOutcome);
    return () => {
      window.removeEventListener('appleHealthSync', captureTodayOutcome);
      window.removeEventListener('apex:journal-updated', captureTodayOutcome);
    };
  }, [todayIsoKey]);

  const toggleJournalTag = (tagId) => {
    playPlunk();
    setDailyTagsByDate((prev) => {
      const curr = prev[todayIsoKey] || [];
      const nextToday = curr.includes(tagId) ? curr.filter((t) => t !== tagId) : [...curr, tagId];
      if (!curr.includes(tagId)) playCoinChime();
      const updated = { ...prev, [todayIsoKey]: nextToday };
      try {
        localStorage.setItem('apex_daily_journal_tags_v1', JSON.stringify(updated));
      } catch {}
      return updated;
    });
  };

  // True Lag-1 Paired Impact Calculation (tag on Day D -> HRV/RHR on Day D+1, needs >= 3 paired days)
  const computeTagLag1Impact = (tagId) => {
    const onHrv = [];
    const offHrv = [];
    const onRhr = [];
    const offRhr = [];
    Object.entries(dailyTagsByDate).forEach(([dateKey, tags]) => {
      const d = new Date(`${dateKey}T12:00:00Z`);
      if (isNaN(d.getTime())) return;
      d.setUTCDate(d.getUTCDate() + 1);
      const nextKey = d.toISOString().slice(0, 10);
      const out = outcomesByDate[nextKey];
      if (!out || (!out.hrv && !out.rhr)) return;
      const tagged = Array.isArray(tags) && tags.includes(tagId);
      if (out.hrv) (tagged ? onHrv : offHrv).push(out.hrv);
      if (out.rhr) (tagged ? onRhr : offRhr).push(out.rhr);
    });
    const enough = onHrv.length >= 3 && offHrv.length >= 1;
    let hrvDeltaPct = null;
    if (enough) {
      const meanOn = onHrv.reduce((a, b) => a + b, 0) / onHrv.length;
      const meanOff = offHrv.reduce((a, b) => a + b, 0) / offHrv.length;
      if (meanOff > 0) hrvDeltaPct = ((meanOn - meanOff) / meanOff) * 100;
    }
    let rhrDeltaBpm = null;
    if (onRhr.length >= 3 && offRhr.length >= 1) {
      rhrDeltaBpm = onRhr.reduce((a, b) => a + b, 0) / onRhr.length - offRhr.reduce((a, b) => a + b, 0) / offRhr.length;
    }
    return { pairedCount: onHrv.length, enough, hrvDeltaPct, rhrDeltaBpm };
  };

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
          Log daily Bevel habit tags below or via iPhone Biology -&gt; Experiment Lab &amp; Journal. Requires ≥3 paired next-day HRV samples to unlock Lag-1 coefficients.
        </p>

        {/* BEVEL DAILY JOURNAL TAGS + LAG-1 IMPACT */}
        <div className="mb-5 p-4 rounded-[18px] bg-black/40 border border-white/10 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2 text-xs font-mono font-black text-[#E5FE40]">
              <Tag className="w-3.5 h-3.5" />
              <span>TODAY&apos;S JOURNAL TAGS ({(dailyTagsByDate[todayIsoKey] || []).length} ACTIVE)</span>
            </div>
            <span className="text-[10px] font-mono text-[#8A8A8A]">Synced with iPhone Biology</span>
          </div>

          <div className="flex flex-wrap gap-2">
            {JOURNAL_TAG_PRESETS.map((tag) => {
              const active = (dailyTagsByDate[todayIsoKey] || []).includes(tag.id);
              const impact = computeTagLag1Impact(tag.id);
              return (
                <button
                  key={tag.id}
                  onClick={() => toggleJournalTag(tag.id)}
                  className={`px-3 py-1.5 rounded-full text-xs font-mono font-bold border transition flex items-center space-x-1.5 ${
                    active
                      ? 'bg-[#00F0FF]/20 border-[#00F0FF] text-white'
                      : 'bg-white/5 border-white/10 text-[#A1A1AA] hover:border-white/25'
                  }`}
                >
                  <span>{tag.label}</span>
                  {impact.enough && impact.hrvDeltaPct != null ? (
                    <span className={impact.hrvDeltaPct >= 0 ? 'text-[#10B981]' : 'text-[#FA114F]'}>
                      {impact.hrvDeltaPct >= 0 ? '+' : ''}
                      {Math.round(impact.hrvDeltaPct)}%
                    </span>
                  ) : impact.pairedCount > 0 ? (
                    <span className="text-[10px] text-[#8A8A8A]">({impact.pairedCount}/3d)</span>
                  ) : null}
                </button>
              );
            })}
          </div>
        </div>

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
