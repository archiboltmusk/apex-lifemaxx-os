import React, { useState, useEffect } from 'react';
import {
  ShieldCheck,
  Trophy,
  CheckCircle,
  Clock,
  Heart,
  Award,
  ArrowUpRight,
  Check,
  AlertCircle,
  Play,
  Pause,
  RotateCcw,
  Sparkles
} from 'lucide-react';
import { playPlunk, playCoinChime, playHealthSyncChime } from '../utils/audioSynth';
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
    target: '2x 40kg dumbbells for 2 mins',
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
    target: 'Distance > your height (180 cm)',
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
  const [events, setEvents] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_decathlon_events');
      return saved ? JSON.parse(saved) : DECATHLON_EVENTS;
    } catch {
      return DECATHLON_EVENTS;
    }
  });

  // Live Dead Hang Stopwatch State
  const [hangSeconds, setHangSeconds] = useState(0);
  const [isHangRunning, setIsHangRunning] = useState(false);

  // Stopwatch Interval
  useEffect(() => {
    let interval = null;
    if (isHangRunning) {
      interval = setInterval(() => {
        setHangSeconds((s) => s + 1);
      }, 1000);
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [isHangRunning]);

  const toggleEvent = (id) => {
    playPlunk();
    setEvents((prev) => {
      const updated = prev.map((e) => (e.id === id ? { ...e, completed: !e.completed } : e));
      try {
        localStorage.setItem('apex_decathlon_events', JSON.stringify(updated));
      } catch {}
      return updated;
    });
  };

  const completedCount = events.filter((e) => e.completed).length;
  const overallDecathlonScore = Math.round(
    events.reduce((acc, curr) => acc + (curr.completed ? 100 : curr.score), 0) / events.length
  );

  return (
    <div className="space-y-6">
      {/* CENTENARIAN DECATHLON HERO */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center">
              <Trophy className="w-5 h-5 text-[#E5FE40]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">Peter Attia's Centenarian Decathlon</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  {completedCount}/10 COMPLETE
                </span>
              </div>
              <p className="text-[11px] font-mono text-[#8A8A8A]">
                The 10 critical physical capabilities required for complete biological independence at age 100
              </p>
            </div>
          </div>

          <div className="text-right font-mono">
            <span className="text-[10px] text-[#8A8A8A] block">LONGEVITY INDEX</span>
            <span className="text-xl font-black text-[#E5FE40]">{overallDecathlonScore}%</span>
          </div>
        </div>

        {/* Epigenetic Pace of Aging Highlight Bar */}
        <div className="p-4 rounded-[18px] bg-black/60 border border-white/10 grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs font-mono">
          <div className="p-3 rounded-[12px] bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#8A8A8A] block">DUNEDINPACE SCORE</span>
            <strong className="text-[#10B981] text-base">0.74x / year</strong>
            <span className="text-[9px] text-[#8A8A8A] block">Reversal Olympics Tier 1</span>
          </div>

          <div className="p-3 rounded-[12px] bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#8A8A8A] block">BIOLOGICAL AGE DELTA</span>
            <strong className="text-[#00F0FF] text-base">-6.2 Years Younger</strong>
            <span className="text-[9px] text-[#8A8A8A] block">PhenoAge verified</span>
          </div>

          <div className="p-3 rounded-[12px] bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#8A8A8A] block">CARDIO RECOVERY</span>
            <strong className="text-[#E5FE40] text-base">-38 bpm in 60s</strong>
            <span className="text-[9px] text-[#10B981] block">Optimal autonomic recovery</span>
          </div>
        </div>
      </div>

      {/* LIVE STOPWATCH FOR DEAD HANG */}
      <div className="liquid-glass rounded-[24px] p-5 border border-white/10 flex flex-wrap items-center justify-between gap-4 font-mono text-xs">
        <div>
          <span className="text-[10px] text-[#8A8A8A] uppercase block">EVENT #1 STOPWATCH TEST</span>
          <h4 className="text-sm font-bold text-white">Pull-Up Bar Dead Hang (Target: 120s)</h4>
          <span className="text-2xl font-black text-[#00F0FF] mt-1 block">
            {Math.floor(hangSeconds / 60)}:{(hangSeconds % 60).toString().padStart(2, '0')}
          </span>
        </div>

        <div className="flex items-center space-x-2">
          <button
            onClick={() => {
              playPlunk();
              setIsHangRunning(!isHangRunning);
            }}
            className={`px-4 py-2 rounded-[10px] font-bold text-xs uppercase flex items-center space-x-1.5 transition ${
              isHangRunning
                ? 'bg-[#F59E0B] text-black'
                : 'bg-[#00F0FF] text-black shadow-[0_0_12px_rgba(0,240,255,0.4)]'
            }`}
          >
            {isHangRunning ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5 fill-black" />}
            <span>{isHangRunning ? 'PAUSE' : 'START HANG TEST'}</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setIsHangRunning(false);
              setHangSeconds(0);
            }}
            className="p-2 rounded-[10px] bg-white/10 hover:bg-white/20 text-white"
          >
            <RotateCcw className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* DECATHLON 10-EVENT MATRIX */}
      <div className="space-y-2.5">
        {events.map((e) => (
          <div
            key={e.id}
            onClick={() => toggleEvent(e.id)}
            className={`p-4 rounded-[18px] border cursor-pointer transition flex items-center justify-between ${
              e.completed
                ? 'bg-[#10B981]/10 border-[#10B981]/40'
                : 'bg-white/[0.03] border-white/5 hover:border-white/20'
            }`}
          >
            <div className="space-y-1">
              <div className="flex items-center space-x-2">
                <span className={`w-2 h-2 rounded-full ${e.completed ? 'bg-[#10B981]' : 'bg-[#FA114F]'}`} />
                <h4 className="text-xs font-mono font-bold text-white">{e.name}</h4>
                <span className="text-[10px] font-mono text-[#8A8A8A]">({e.target})</span>
              </div>
              <p className="text-[11px] font-mono text-[#A1A1AA] max-w-xl">{e.desc}</p>
            </div>

            <div className="flex items-center space-x-3 shrink-0">
              <span className="text-xs font-mono font-black" style={{ color: e.completed ? '#10B981' : '#E5FE40' }}>
                {e.completed ? '100%' : `${e.score}%`}
              </span>
              <div
                className={`w-6 h-6 rounded-full flex items-center justify-center border ${
                  e.completed ? 'bg-[#10B981] border-[#10B981]' : 'border-white/20'
                }`}
              >
                {e.completed && <Check className="w-3.5 h-3.5 text-black stroke-[3]" />}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
