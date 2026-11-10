import React, { useState } from 'react';
import { ShieldCheck, Trophy, CheckCircle, Clock, Heart, Award, ArrowUpRight, Check, AlertCircle } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const DECATHLON_EVENTS = [
  {
    id: 'd1',
    name: '2-Minute Pull-Up Bar Dead Hang',
    target: '120 seconds',
    category: 'Grip & All-Cause Mortality',
    desc: 'Unbroken grip hang from bar. Grip strength is the single highest predictor of late-life all-cause survival.',
    completed: true,
    score: 100,
  },
  {
    id: 'd2',
    name: 'Farmer’s Walk (100% Bodyweight for 2m)',
    target: '2x 45kg dumbbells for 2 mins',
    category: 'Postural Spine & Core Stability',
    desc: 'Carry full body weight equivalent with zero spinal deviation.',
    completed: true,
    score: 100,
  },
  {
    id: 'd3',
    name: 'Zero-Hands Floor Get-Up',
    target: 'Sit down and rise without touching limbs',
    category: 'Proprioception & Joint Mobility',
    desc: 'The Brazilian Sitting-Rising Test. Each point lost indicates a 21% increase in 6-year mortality.',
    completed: true,
    score: 100,
  },
  {
    id: 'd4',
    name: 'Eyes-Closed Single-Leg Stand',
    target: '45 seconds each leg',
    category: 'Vestibular & Fall Prevention',
    desc: 'Inability to balance on one leg with eyes shut is correlated with rapid brain atrophy and stroke risk.',
    completed: true,
    score: 100,
  },
  {
    id: 'd5',
    name: 'Top 5% VO2 Max (Longevity Peak)',
    target: '> 55 mL/kg/min',
    category: 'Cardiorespiratory Reserve',
    desc: 'Having elite VO2 max delivers a 500% reduction in all-cause mortality vs low-cardio individuals.',
    completed: true,
    score: 100,
  },
  {
    id: 'd6',
    name: 'Goblet Squat (50% Bodyweight x 10)',
    target: '40kg kettlebell x 10 reps below parallel',
    category: 'Quad & Glute Power Output',
    desc: 'Maintains hip hinge integrity and stair-climbing independence into the 9th decade.',
    completed: true,
    score: 100,
  },
  {
    id: 'd7',
    name: 'Standing Broad Jump (> Height)',
    target: 'Distance > your height (182 cm)',
    category: 'Type-II Fast-Twitch Muscle Fibers',
    desc: 'Fast-twitch motor unit preservation prevents catastrophic deceleration falls.',
    completed: false,
    score: 75,
  },
  {
    id: 'd8',
    name: 'Nordic Hamstring Eccentric Control',
    target: '5 full bodyweight controlled reps',
    category: 'Knee & Posterior Chain Armor',
    desc: 'Eccentric hamstring deceleration protects against ACL tears and knee replacements.',
    completed: false,
    score: 60,
  },
  {
    id: 'd9',
    name: '500m Row Sprint (< 1m 30s)',
    target: '1:28 split pace',
    category: 'Anaerobic Lactate Clearance',
    desc: 'High-intensity glycolytic buffer capacity and peak heart-rate return.',
    completed: false,
    score: 70,
  },
  {
    id: 'd10',
    name: '2x Bodyweight Deadlift',
    target: '160 kg for 1 clean rep',
    category: 'Posterior Kinetic Chain Peak',
    desc: 'Hip hinge structural loading protecting lumbar disc space against compression.',
    completed: true,
    score: 100,
  },
];

export default function CentenarianDecathlon() {
  const [events, setEvents] = useState(DECATHLON_EVENTS);

  const toggleEvent = (id) => {
    playPlunk();
    setEvents((prev) =>
      prev.map((e) => {
        if (e.id === id) {
          const next = !e.completed;
          if (next) {
            playCoinChime();
            try {
              confetti({
                particleCount: 50,
                spread: 60,
                colors: ['#E5FE40', '#10B981', '#00F0FF'],
              });
            } catch {}
          }
          return { ...e, completed: next, score: next ? 100 : 50 };
        }
        return e;
      })
    );
  };

  const completedCount = events.filter((e) => e.completed).length;
  const readinessScore = Math.round((completedCount / events.length) * 100);

  return (
    <div className="space-y-6">
      {/* HERO CARD */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/20 relative overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 rounded-[16px] bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center">
              <Trophy className="w-6 h-6 text-[#E5FE40]" />
            </div>
            <div>
              <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-widest">
                DR. PETER ATTIA LONGEVITY FRAMEWORK
              </span>
              <h3 className="text-lg font-bold text-white tracking-tight">
                The Centenarian Decathlon Protocol
              </h3>
            </div>
          </div>

          <div className="text-right">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">READINESS INDEX</span>
            <div className="flex items-baseline space-x-2">
              <span className="text-4xl font-mono font-black text-white">{readinessScore}%</span>
              <span className="text-xs font-mono text-[#10B981] font-bold">AGE 80+ PRIMED</span>
            </div>
            <span className="text-[10px] font-mono text-[#E5FE40]">
              {completedCount} of 10 Physical Milestones Mastered
            </span>
          </div>
        </div>

        <p className="text-xs text-[#A1A1AA] leading-relaxed">
          The 10 physical benchmarks you must build in your 20s and 30s to retain independent kick-ass physical autonomy well into your 90s.
        </p>
      </div>

      {/* EVENT CHECKLIST */}
      <div className="space-y-2.5">
        {events.map((ev) => (
          <div
            key={ev.id}
            onClick={() => toggleEvent(ev.id)}
            className={`p-4 rounded-[18px] border transition cursor-pointer flex items-center justify-between ${
              ev.completed
                ? 'bg-white/[0.04] border-white/20'
                : 'bg-black/30 border-white/5 opacity-75'
            }`}
          >
            <div className="flex items-center space-x-3.5">
              <div
                className={`w-7 h-7 rounded-[10px] flex items-center justify-center border transition ${
                  ev.completed
                    ? 'bg-[#E5FE40] border-[#E5FE40] text-black font-bold shadow-[0_0_10px_rgba(229,254,64,0.5)]'
                    : 'border-white/20 bg-black/40'
                }`}
              >
                {ev.completed && <Check className="w-4 h-4 stroke-[3]" />}
              </div>
              <div>
                <div className="flex items-center space-x-2">
                  <h4 className="text-xs font-mono font-bold text-white">{ev.name}</h4>
                  <span className="text-[9px] font-mono font-bold px-1.5 py-0.2 rounded bg-black/50 text-[#00F0FF] border border-white/10">
                    {ev.target}
                  </span>
                </div>
                <span className="text-[11px] text-[#8A8A8A] block">{ev.desc}</span>
              </div>
            </div>

            <div className="text-right shrink-0 ml-3">
              <span className="text-xs font-mono font-black text-[#10B981] block">
                {ev.completed ? 'PASSED' : 'IN PROGRESS'}
              </span>
              <span className="text-[10px] font-mono text-[#8A8A8A]">{ev.category}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
