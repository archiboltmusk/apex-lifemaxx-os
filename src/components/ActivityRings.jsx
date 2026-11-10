import React from 'react';

export default function ActivityRings({ move, exercise, stand, size = 160, strokeWidth = 14 }) {
  const center = size / 2;
  const gap = 3;

  // Radii for concentric circles
  const rMove = center - strokeWidth / 2 - 2;
  const rExercise = rMove - strokeWidth - gap;
  const rStand = rExercise - strokeWidth - gap;

  const circMove = 2 * Math.PI * rMove;
  const circExercise = 2 * Math.PI * rExercise;
  const circStand = 2 * Math.PI * rStand;

  // Clamped progress (can go > 100% like Apple Watch)
  const offsetMove = Math.max(0, circMove - (move.percentage / 100) * circMove);
  const offsetExercise = Math.max(0, circExercise - (exercise.percentage / 100) * circExercise);
  const offsetStand = Math.max(0, circStand - (stand.percentage / 100) * circStand);

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="transform -rotate-90">
        <defs>
          <linearGradient id="moveGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#FA114F" />
            <stop offset="100%" stopColor="#FF5E7E" />
          </linearGradient>
          <linearGradient id="exerciseGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#92E82A" />
            <stop offset="100%" stopColor="#C4FF61" />
          </linearGradient>
          <linearGradient id="standGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#00D6E6" />
            <stop offset="100%" stopColor="#67F5FF" />
          </linearGradient>
        </defs>

        {/* MOVE (RED) BACKGROUND & ACTIVE */}
        <circle
          cx={center}
          cy={center}
          r={rMove}
          stroke="#FA114F"
          strokeOpacity="0.2"
          strokeWidth={strokeWidth}
          fill="none"
        />
        <circle
          cx={center}
          cy={center}
          r={rMove}
          stroke="url(#moveGrad)"
          strokeWidth={strokeWidth}
          strokeDasharray={circMove}
          strokeDashoffset={offsetMove}
          strokeLinecap="round"
          fill="none"
          className="transition-all duration-1000 ease-out ring-glow-red"
        />

        {/* EXERCISE (GREEN) BACKGROUND & ACTIVE */}
        <circle
          cx={center}
          cy={center}
          r={rExercise}
          stroke="#92E82A"
          strokeOpacity="0.2"
          strokeWidth={strokeWidth}
          fill="none"
        />
        <circle
          cx={center}
          cy={center}
          r={rExercise}
          stroke="url(#exerciseGrad)"
          strokeWidth={strokeWidth}
          strokeDasharray={circExercise}
          strokeDashoffset={offsetExercise}
          strokeLinecap="round"
          fill="none"
          className="transition-all duration-1000 ease-out ring-glow-green"
        />

        {/* STAND (BLUE) BACKGROUND & ACTIVE */}
        <circle
          cx={center}
          cy={center}
          r={rStand}
          stroke="#00D6E6"
          strokeOpacity="0.2"
          strokeWidth={strokeWidth}
          fill="none"
        />
        <circle
          cx={center}
          cy={center}
          r={rStand}
          stroke="url(#standGrad)"
          strokeWidth={strokeWidth}
          strokeDasharray={circStand}
          strokeDashoffset={offsetStand}
          strokeLinecap="round"
          fill="none"
          className="transition-all duration-1000 ease-out ring-glow-blue"
        />
      </svg>

      {/* Central Apple Watch Activity Icon / Glyph */}
      <div className="absolute flex flex-col items-center justify-center pointer-events-none">
        <span className="text-[10px] font-mono font-bold text-white tracking-widest uppercase">
          ACTIVITY
        </span>
        <span className="text-[9px] font-mono text-[#E5FE40] font-black">
          {Math.round((move.percentage + exercise.percentage + stand.percentage) / 3)}%
        </span>
      </div>
    </div>
  );
}
