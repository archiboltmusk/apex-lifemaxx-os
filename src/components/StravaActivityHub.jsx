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

const EMPTY_ACTIVITY = {
  title: 'No Activity Synced Yet',
  location: 'Connect Apple Health / Strava or log a session below',
  distanceKm: 0,
  movingTimeMin: 0,
  paceStr: '-- /km',
  elevationM: 0,
  avgHR: 0,
  sufferScore: 0,
  isRecorded: false,
};

export default function StravaActivityHub({ onConnectHealth }) {
  const [activity, setActivity] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_user_activity');
      return saved ? JSON.parse(saved) : EMPTY_ACTIVITY;
    } catch {
      return EMPTY_ACTIVITY;
    }
  });

  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(activity.isRecorded ? activity.title : '');
  const [editDist, setEditDist] = useState(activity.distanceKm || '');
  const [editTime, setEditTime] = useState(activity.movingTimeMin || '');
  const [editHR, setEditHR] = useState(activity.avgHR || '');

  const [kudosCount, setKudosCount] = useState(() => {
    try {
      return Number(localStorage.getItem('apex_activity_kudos') || '0');
    } catch {
      return 0;
    }
  });
  const [hasGivenKudos, setHasGivenKudos] = useState(false);

  const handleSaveActivity = (e) => {
    e.preventDefault();
    const dist = Number(editDist) || 0;
    const time = Number(editTime) || 0;
    const hr = Number(editHR) || 0;
    if (dist <= 0 || time <= 0) return;

    playPlunk();
    playCoinChime();
    const paceDecimal = time / dist;
    const paceMinutes = Math.floor(paceDecimal);
    const paceSeconds = Math.round((paceDecimal - paceMinutes) * 60);
    const paceFormatted = `${paceMinutes}:${paceSeconds < 10 ? '0' : ''}${paceSeconds} /km`;
    const computedSuffer = hr > 0 ? Math.round(time * Math.max(0.5, (hr - 95) / 35)) : Math.round(time * 1.2);

    const updated = {
      ...activity,
      title: editTitle.trim() || 'Outdoor Cardio Session',
      location: 'Logged Telemetry · GPS / Workout Record',
      distanceKm: dist,
      movingTimeMin: time,
      paceStr: paceFormatted,
      avgHR: hr,
      sufferScore: computedSuffer,
      isRecorded: true,
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
    if (hasGivenKudos || !activity.isRecorded) return;
    playPlunk();
    playCoinChime();
    setKudosCount((k) => {
      const next = k + 1;
      try {
        localStorage.setItem('apex_activity_kudos', String(next));
      } catch {}
      return next;
    });
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
            {onConnectHealth && !activity.isRecorded && (
              <button
                onClick={() => {
                  playPlunk();
                  onConnectHealth();
                }}
                className="px-3 py-1.5 rounded-[12px] bg-[#FC5200] hover:bg-[#e14900] text-xs font-mono font-black text-white transition"
              >
                CONNECT HEALTH
              </button>
            )}
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
              <span className="text-xs font-mono font-black text-white">
                {activity.isRecorded ? `EFFORT ${activity.sufferScore}` : 'AWAITING DATA'}
              </span>
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
            <span className="text-2xl font-mono font-black text-white">{activity.isRecorded ? `${activity.distanceKm} km` : '—'}</span>
            <span className="text-[10px] font-mono text-[#10B981]">{activity.isRecorded ? 'Workout Recorded' : 'Log or Connect Health'}</span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">PACE (AVG)</span>
            <span className="text-2xl font-mono font-black text-[#00F0FF]">{activity.isRecorded ? activity.paceStr : '—'}</span>
            <span className="text-[10px] font-mono text-[#00F0FF]">{activity.isRecorded ? 'Calculated Split' : 'Awaiting distance'}</span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">MOVING TIME</span>
            <span className="text-2xl font-mono font-black text-white">{activity.isRecorded ? `${activity.movingTimeMin} min` : '—'}</span>
            <span className="text-[10px] font-mono text-[#8A8A8A]">{activity.isRecorded ? 'Session Duration' : 'No workout synced'}</span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">AVG HEART RATE</span>
            <span className="text-2xl font-mono font-black text-[#FA114F]">{activity.avgHR > 0 ? `${activity.avgHR} bpm` : '—'}</span>
            <span className="text-[10px] font-mono text-[#10B981]">{activity.avgHR > 0 ? (activity.avgHR <= 145 ? 'Zone 2 Aerobic' : 'High Output') : 'Pair Watch / Strap'}</span>
          </div>
        </div>

        {/* WORKOUT STATUS / ELEVATION CONTAINER */}
        {activity.isRecorded ? (
          <div className="my-4 p-4 rounded-[18px] bg-black/50 border border-white/10 space-y-2 text-xs font-mono text-[#8A8A8A]">
            <div className="flex items-center justify-between">
              <span>SESSION SUMMARY · {activity.title}</span>
              <span className="text-[#00F0FF]">Total Elevation Logged: +{activity.elevationM} m</span>
            </div>
            <p className="text-[11px] text-[#A1A1AA]">
              GPS telemetry and heart-rate stream reflect your logged session or synced Apple Watch workout.
            </p>
          </div>
        ) : (
          <div className="my-4 p-5 rounded-[18px] bg-black/50 border border-dashed border-white/15 text-center space-y-2 text-xs font-mono">
            <p className="text-white font-bold">Connect Apple Health or log your run/ride to view real pace, heart rate, and elevation.</p>
            <p className="text-[11px] text-[#8A8A8A]">Zero placeholder GPS routes are synthesized before you sync or record a real session.</p>
          </div>
        )}

        {/* LOGBOOK ACTIONS */}
        <div className="flex items-center justify-between pt-3 border-t border-white/10">
          <div className="flex items-center space-x-2">
            <button
              onClick={handleGiveKudos}
              disabled={!activity.isRecorded}
              className={`px-4 py-2 rounded-[12px] flex items-center space-x-2 text-xs font-mono font-black transition ${
                !activity.isRecorded
                  ? 'bg-white/5 text-white/30 cursor-not-allowed'
                  : hasGivenKudos
                  ? 'bg-[#FC5200] text-white shadow-[0_0_15px_rgba(252,82,0,0.6)]'
                  : 'bg-white/10 text-white hover:bg-white/20'
              }`}
            >
              <ThumbsUp className={`w-3.5 h-3.5 ${hasGivenKudos ? 'fill-white' : ''}`} />
              <span>{hasGivenKudos ? 'SESSION CELEBRATED' : 'CELEBRATE SESSION'}</span>
            </button>
            <span className="text-xs font-mono text-[#A1A1AA]">
              {activity.isRecorded ? `${kudosCount} Session Milestones` : 'No session active'}
            </span>
          </div>

          <span className="text-xs font-mono text-[#10B981] font-bold">
            {activity.avgHR > 0 ? `Average Heart Rate: ${activity.avgHR} bpm` : 'Awaiting Heart Rate Sensor'}
          </span>
        </div>
      </div>
    </div>
  );
}
