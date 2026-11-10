import React from 'react';
import { Volume2, Activity, Sparkles, RefreshCw, Heart } from 'lucide-react';

export default function DynamicIsland({
  isGammaPlaying,
  isMewingActive,
  mewingSeconds,
  isSyncing,
  onClick
}) {
  const isExpanded = isGammaPlaying || isMewingActive || isSyncing;

  return (
    <div className="flex justify-center w-full pt-2 pb-1 z-40 select-none">
      <div
        onClick={onClick}
        className={`bg-black text-white cursor-pointer transition-all duration-300 ease-out flex items-center justify-between px-3 border border-white/10 ${
          isExpanded
            ? 'w-[260px] h-[34px] rounded-[18px] shadow-[0_0_20px_rgba(0,0,0,0.9)]'
            : 'w-[120px] h-[26px] rounded-[14px] hover:w-[135px]'
        }`}
      >
        {/* Left Indicator */}
        <div className="flex items-center space-x-1.5">
          {isGammaPlaying ? (
            <div className="flex items-center space-x-1">
              <span className="w-1.5 h-3 bg-[#8B5CF6] rounded-full animate-pulse" />
              <span className="w-1.5 h-4 bg-[#8B5CF6] rounded-full animate-bounce" />
              <span className="w-1.5 h-2 bg-[#8B5CF6] rounded-full animate-pulse" />
            </div>
          ) : isMewingActive ? (
            <Sparkles className="w-3.5 h-3.5 text-[#00F0FF] animate-spin" />
          ) : isSyncing ? (
            <RefreshCw className="w-3.5 h-3.5 text-[#10B981] animate-spin" />
          ) : (
            <div className="w-2.5 h-2.5 rounded-full bg-[#1F2430] border border-white/10" />
          )}

          {isExpanded && (
            <span className="text-[10px] font-mono font-bold tracking-tight text-white/90">
              {isGammaPlaying
                ? '40Hz FLOW'
                : isMewingActive
                ? `MEWING ${Math.floor(mewingSeconds / 60)}:${(mewingSeconds % 60)
                    .toString()
                    .padStart(2, '0')}`
                : 'HEALTH SYNC'}
            </span>
          )}
        </div>

        {/* Right Camera / Sensor Dot or Status */}
        <div className="flex items-center space-x-1.5">
          {isExpanded ? (
            <span className="text-[9px] font-mono text-[#E5FE40] font-black uppercase">
              LIVE
            </span>
          ) : (
            <div className="w-2.5 h-2.5 rounded-full bg-[#0E1726] border border-white/20" />
          )}
        </div>
      </div>
    </div>
  );
}
