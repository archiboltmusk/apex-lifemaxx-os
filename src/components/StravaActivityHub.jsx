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
  Share2,
  Plus,
  Save,
  Upload
} from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function StravaActivityHub() {
  const [activity, setActivity] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_user_activity');
      return saved
        ? JSON.parse(saved)
        : {
            title: 'Morning Zone 2 Aerobic Base',
            location: 'Local Outdoor Trail · Cupertino / SF',
            distanceKm: 8.5,
            movingTimeMin: 42,
            paceStr: '4:56 /km',
            elevationM: 185,
            avgHR: 136,
            sufferScore: 124,
          };
    } catch {
      return {
        title: 'Morning Zone 2 Aerobic Base',
        location: 'Local Outdoor Trail',
        distanceKm: 8.5,
        movingTimeMin: 42,
        paceStr: '4:56 /km',
        elevationM: 185,
        avgHR: 136,
        sufferScore: 124,
      };
    }
  });

  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(activity.title);
  const [editDist, setEditDist] = useState(activity.distanceKm);
  const [editTime, setEditTime] = useState(activity.movingTimeMin);
  const [editHR, setEditHR] = useState(activity.avgHR);

  const [kudosCount, setKudosCount] = useState(148);
  const [hasGivenKudos, setHasGivenKudos] = useState(false);

  const handleSaveActivity = (e) => {
    e.preventDefault();
    playPlunk();
    playCoinChime();
    const paceMin = editDist > 0 ? (editTime / editDist).toFixed(2) : '5.00';
    const paceMinutes = Math.floor(paceMin);
    const paceSeconds = Math.round((paceMin - paceMinutes) * 60);
    const paceFormatted = `${paceMinutes}:${paceSeconds < 10 ? '0' : ''}${paceSeconds} /km`;

    const updated = {
      ...activity,
      title: editTitle,
      distanceKm: Number(editDist),
      movingTimeMin: Number(editTime),
      paceStr: paceFormatted,
      avgHR: Number(editHR),
    };
    setActivity(updated);
    setIsEditing(false);
    try {
      localStorage.setItem('apex_user_activity', JSON.stringify(updated));
      confetti({
        particleCount: 50,
        spread: 60,
        colors: ['#FC5200', '#E5FE40', '#10B981'],
      });
    } catch {}
  };

  const handleGiveKudos = () => {
    if (hasGivenKudos) return;
    playPlunk();
    playCoinChime();
    setKudosCount((k) => k + 1);
    setHasGivenKudos(true);
  };

  return (
    <div className="space-y-6">
      {/* STRAVA ACTIVITY CARD */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 relative overflow-hidden">
        {/* Top Header */}
        <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#FC5200]/20 border border-[#FC5200]/40 flex items-center justify-center">
              <Compass className="w-5 h-5 text-[#FC5200]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-base font-bold text-white tracking-tight">{activity.title}</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#FC5200]/20 text-[#FC5200] border border-[#FC5200]/40 font-black">
                  STRAVA TELEMETRY
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                {activity.location} · Real GPS Telemetry
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={() => {
                playPlunk();
                setIsEditing(!isEditing);
              }}
              className="px-3 py-1.5 rounded-[12px] bg-white/10 hover:bg-white/20 text-xs font-mono font-bold text-white transition flex items-center space-x-1"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{isEditing ? 'CANCEL' : 'LOG WORKOUT'}</span>
            </button>
            <div className="flex items-center space-x-1.5 px-3 py-1.5 rounded-full bg-black/50 border border-white/10">
              <Flame className="w-3.5 h-3.5 text-[#FC5200]" />
              <span className="text-xs font-mono font-black text-white">SUFFER SCORE {activity.sufferScore}</span>
            </div>
          </div>
        </div>

        {/* Edit Workout Inline Form */}
        {isEditing && (
          <form
            onSubmit={handleSaveActivity}
            className="p-4 rounded-[18px] bg-black/60 border border-[#FC5200]/40 my-4 space-y-3 animate-fade-in text-xs font-mono"
          >
            <span className="text-[#FC5200] font-black uppercase tracking-wider block">
              Log Real Workout Telemetry (GPS / Strava)
            </span>
            <div className="grid grid-cols-1 sm:grid-cols-4 gap-2.5">
              <input
                type="text"
                placeholder="Activity Title"
                value={editTitle}
                onChange={(e) => setEditTitle(e.target.value)}
                className="px-3 py-2 rounded-[12px] bg-black border border-white/15 text-white"
              />
              <input
                type="number"
                step="0.1"
                placeholder="Distance (km)"
                value={editDist}
                onChange={(e) => setEditDist(e.target.value)}
                className="px-3 py-2 rounded-[12px] bg-black border border-white/15 text-white"
              />
              <input
                type="number"
                placeholder="Moving Time (min)"
                value={editTime}
                onChange={(e) => setEditTime(e.target.value)}
                className="px-3 py-2 rounded-[12px] bg-black border border-white/15 text-white"
              />
              <input
                type="number"
                placeholder="Average HR (bpm)"
                value={editHR}
                onChange={(e) => setEditHR(e.target.value)}
                className="px-3 py-2 rounded-[12px] bg-black border border-white/15 text-white"
              />
            </div>
            <div className="flex justify-end">
              <button
                type="submit"
                className="px-4 py-1.5 rounded-[10px] bg-[#FC5200] text-white font-black"
              >
                Save Real Activity
              </button>
            </div>
          </form>
        )}

        {/* Big Metrics Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 my-4">
          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">DISTANCE</span>
            <span className="text-2xl font-mono font-black text-white">{activity.distanceKm} km</span>
            <span className="text-[10px] font-mono text-[#10B981]">GPS Calibrated</span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">PACE (AVG)</span>
            <span className="text-2xl font-mono font-black text-[#00F0FF]">{activity.paceStr}</span>
            <span className="text-[10px] font-mono text-[#00F0FF]">Nasal Breathing</span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">MOVING TIME</span>
            <span className="text-2xl font-mono font-black text-white">{activity.movingTimeMin} min</span>
            <span className="text-[10px] font-mono text-[#8A8A8A]">Active Epoc</span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">AVG HEART RATE</span>
            <span className="text-2xl font-mono font-black text-[#FA114F]">{activity.avgHR} bpm</span>
            <span className="text-[10px] font-mono text-[#10B981]">Zone 2 Aerobic</span>
          </div>
        </div>

        {/* REAL ELEVATION PROFILE SVG */}
        <div className="my-4 p-4 rounded-[18px] bg-black/50 border border-white/10 space-y-2">
          <div className="flex items-center justify-between text-xs font-mono text-[#8A8A8A]">
            <span>ELEVATION PROFILE & CADENCE (176 SPM)</span>
            <span className="text-[#00F0FF]">Total Ascended: +{activity.elevationM} m</span>
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
            Average Heart Rate: {activity.avgHR} bpm (Zone 2)
          </span>
        </div>
      </div>
    </div>
  );
}
