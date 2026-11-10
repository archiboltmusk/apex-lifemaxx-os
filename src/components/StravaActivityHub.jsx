import React, { useState } from 'react';
import {
  Compass,
  MapPin,
  Trophy,
  Heart,
  TrendingUp,
  ThumbsUp,
  Flame,
  Clock,
  Zap,
  Award,
  ChevronRight,
  Share2
} from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function StravaActivityHub() {
  const [kudosCount, setKudosCount] = useState(142);
  const [hasGivenKudos, setHasGivenKudos] = useState(false);

  const handleGiveKudos = () => {
    if (hasGivenKudos) return;
    playPlunk();
    playCoinChime();
    setKudosCount((k) => k + 1);
    setHasGivenKudos(true);
    try {
      confetti({
        particleCount: 50,
        spread: 60,
        origin: { y: 0.7 },
        colors: ['#FC5200', '#FA114F', '#E5FE40'],
      });
    } catch {}
  };

  return (
    <div className="space-y-6">
      {/* STRAVA ACTIVITY CARD */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 relative overflow-hidden">
        {/* Top Header */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#FC5200]/20 border border-[#FC5200]/40 flex items-center justify-center">
              <Compass className="w-5 h-5 text-[#FC5200]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-base font-bold text-white tracking-tight">Morning Zone 2 Coastal Tempo</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#FC5200]/20 text-[#FC5200] border border-[#FC5200]/40 font-black">
                  STRAVA SYNC
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                GPS Route: Pacific Coast Ridge Trail · Today at 6:45 AM
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-1.5 px-3 py-1 rounded-full bg-black/50 border border-white/10">
            <Flame className="w-3.5 h-3.5 text-[#FC5200]" />
            <span className="text-xs font-mono font-black text-white">SUFFER SCORE 148</span>
          </div>
        </div>

        {/* Big Metrics Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 my-4">
          <div className="p-3 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">DISTANCE</span>
            <span className="text-2xl font-mono font-black text-white">10.42 km</span>
            <span className="text-[10px] font-mono text-[#10B981]">+1.2 km vs avg</span>
          </div>

          <div className="p-3 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">PACE (AVG)</span>
            <span className="text-2xl font-mono font-black text-[#00F0FF]">4:12 /km</span>
            <span className="text-[10px] font-mono text-[#00F0FF]">Nasal Breathing</span>
          </div>

          <div className="p-3 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">MOVING TIME</span>
            <span className="text-2xl font-mono font-black text-white">43m 48s</span>
            <span className="text-[10px] font-mono text-[#8A8A8A]">Elapsed: 44m 10s</span>
          </div>

          <div className="p-3 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">ELEVATION GAIN</span>
            <span className="text-2xl font-mono font-black text-[#E5FE40]">+284 m</span>
            <span className="text-[10px] font-mono text-[#E5FE40]">Mitochondrial Peak</span>
          </div>
        </div>

        {/* SIMULATED ELEVATION & PACE PROFILE SVG */}
        <div className="my-4 p-4 rounded-[18px] bg-black/50 border border-white/10 space-y-2">
          <div className="flex items-center justify-between text-xs font-mono text-[#8A8A8A]">
            <span>ELEVATION PROFILE & CADENCE (176 SPM)</span>
            <span className="text-[#00F0FF]">Max Grade: +11.2%</span>
          </div>
          <svg viewBox="0 0 400 70" className="w-full h-16">
            <defs>
              <linearGradient id="stravaGrad" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stopColor="#FC5200" stopOpacity="0.5" />
                <stop offset="100%" stopColor="#FC5200" stopOpacity="0.0" />
              </linearGradient>
            </defs>
            <path
              d="M 0 50 Q 50 40, 100 25 T 200 45 T 300 15 T 400 40 L 400 70 L 0 70 Z"
              fill="url(#stravaGrad)"
            />
            <path
              d="M 0 50 Q 50 40, 100 25 T 200 45 T 300 15 T 400 40"
              fill="none"
              stroke="#FC5200"
              strokeWidth="2.5"
            />
          </svg>
        </div>

        {/* KUDOS & SOCIAL ACTIONS */}
        <div className="flex items-center justify-between pt-3 border-t border-white/10">
          <div className="flex items-center space-x-2">
            <button
              onClick={handleGiveKudos}
              className={`px-4 py-2 rounded-[12px] flex items-center space-x-2 text-xs font-mono font-black transition ${
                hasGivenKudos
                  ? 'bg-[#FC5200] text-white shadow-[0_0_15px_rgba(252,82,0,0.6)]'
                  : 'bg-white/10 text-white hover:bg-white/20'
              }`}
            >
              <ThumbsUp className={`w-3.5 h-3.5 ${hasGivenKudos ? 'fill-white' : ''}`} />
              <span>{hasGivenKudos ? 'KUDOS GIVEN!' : 'GIVE KUDOS'}</span>
            </button>
            <span className="text-xs font-mono text-[#A1A1AA]">{kudosCount} Athletes Kudos</span>
          </div>

          <span className="text-xs font-mono text-[#10B981] font-bold">
            Average Heart Rate: 138 bpm (Zone 2)
          </span>
        </div>
      </div>

      {/* STRAVA SEGMENTS & KOM CROWNS */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Trophy className="w-5 h-5 text-[#E5FE40]" />
            <h4 className="text-sm font-mono font-black text-white uppercase tracking-wider">
              MATCHED STRAVA SEGMENTS & KOM CROWNS
            </h4>
          </div>
          <span className="text-xs font-mono text-[#E5FE40] font-black">2 PRs TODAY</span>
        </div>

        <div className="space-y-2.5">
          {[
            {
              title: 'Skyline Ridge Power Climb (1.2km · 7%)',
              time: '3m 42s',
              rank: '👑 KOM #1 of 4,820 runners',
              speed: '19.4 km/h',
              isKOM: true,
            },
            {
              title: 'Ocean Boulevard 400m Flat Out Sprint',
              time: '58s',
              rank: '🥈 Top 0.5% (PR -3s)',
              speed: '24.8 km/h',
              isKOM: false,
            },
            {
              title: 'Canyon Descent Switchbacks (800m)',
              time: '2m 14s',
              rank: '🔥 Personal Best (PR -8s)',
              speed: '21.5 km/h',
              isKOM: false,
            },
          ].map((seg, idx) => (
            <div
              key={idx}
              className="p-3.5 rounded-[16px] bg-white/[0.03] border border-white/10 flex items-center justify-between"
            >
              <div>
                <span className="text-xs font-mono font-bold text-white block">{seg.title}</span>
                <span className="text-[11px] font-mono text-[#E5FE40] font-bold">{seg.rank}</span>
              </div>
              <div className="text-right">
                <span className="text-sm font-mono font-black text-white">{seg.time}</span>
                <span className="text-[10px] font-mono text-[#8A8A8A] block">{seg.speed}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
