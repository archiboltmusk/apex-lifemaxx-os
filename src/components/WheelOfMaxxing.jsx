import React, { useState } from 'react';
import { Sparkles, Gift, Award, Zap, Trophy, Flame } from 'lucide-react';
import confetti from 'canvas-confetti';
import { playPlunk, playCoinChime, playWheelTick } from '../utils/audioSynth';
import { CRED_REWARDS_POOL } from '../utils/lifemaxxData';

export default function WheelOfMaxxing({ coins, setCoins, onRewardWon }) {
  const [isSpinning, setIsSpinning] = useState(false);
  const [selectedReward, setSelectedReward] = useState(null);
  const [spinIndex, setSpinIndex] = useState(0);

  const handleSpin = () => {
    if (coins < 100) {
      alert('Insufficient APEX Coins! Complete more protocols or fitness goals to earn coins.');
      return;
    }
    if (isSpinning) return;

    playPlunk();
    setCoins((prev) => Math.max(0, prev - 100));
    setIsSpinning(true);
    setSelectedReward(null);

    let current = spinIndex;
    let ticks = 0;
    const totalTicks = 24 + Math.floor(Math.random() * 8);

    const spinInterval = setInterval(() => {
      ticks++;
      current = (current + 1) % CRED_REWARDS_POOL.length;
      setSpinIndex(current);
      playWheelTick();

      if (ticks >= totalTicks) {
        clearInterval(spinInterval);
        setIsSpinning(false);
        const won = CRED_REWARDS_POOL[current];
        setSelectedReward(won);
        playCoinChime();
        try {
          confetti({
            particleCount: 80,
            spread: 70,
            origin: { y: 0.6 },
            colors: ['#E5FE40', '#FA114F', '#00F0FF', '#8B5CF6'],
          });
        } catch {}
        if (onRewardWon) onRewardWon(won);
      }
    }, 90);
  };

  return (
    <div className="cred-metallic-card rounded-[22px] p-6 border border-white/10 relative overflow-hidden">
      {/* Background ambient glow */}
      <div className="absolute top-0 right-0 w-48 h-48 bg-[#E5FE40]/10 rounded-full blur-3xl pointer-events-none" />

      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-2">
          <div className="w-8 h-8 rounded-lg bg-[#E5FE40]/20 border border-[#E5FE40]/50 flex items-center justify-center">
            <Trophy className="w-4 h-4 text-[#E5FE40]" />
          </div>
          <div>
            <h3 className="font-mono text-sm font-black text-white tracking-wider uppercase">
              CRED MAX // JACKPOT
            </h3>
            <p className="text-[11px] text-[#8A8A8A] font-mono">Burn 100 coins for high-status loot</p>
          </div>
        </div>
        <div className="flex items-center space-x-1.5 px-3 py-1 rounded-full bg-black/60 border border-[#E5FE40]/40">
          <Sparkles className="w-3.5 h-3.5 text-[#E5FE40]" />
          <span className="font-mono font-black text-xs text-[#E5FE40]">{coins} COINS</span>
        </div>
      </div>

      {/* REWARD ROLLER */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-2 my-4">
        {CRED_REWARDS_POOL.map((item, idx) => {
          const isHighlighted = idx === spinIndex;
          const isWinner = selectedReward && selectedReward.id === item.id;
          return (
            <div
              key={item.id}
              className={`p-3 rounded-[14px] transition-all text-center border ${
                isWinner
                  ? 'bg-[#E5FE40] text-black border-[#E5FE40] scale-105 shadow-[0_0_20px_rgba(229,254,64,0.6)] font-bold'
                  : isHighlighted
                  ? 'bg-white/15 border-white/40 scale-102 text-white'
                  : 'bg-black/30 border-white/5 text-[#8A8A8A]'
              }`}
            >
              <span className="text-[9px] font-mono tracking-widest uppercase block mb-1 font-black text-[#00F0FF]">
                {item.rarity}
              </span>
              <p className="text-xs font-mono font-bold leading-tight line-clamp-2">{item.title}</p>
            </div>
          );
        })}
      </div>

      {selectedReward && (
        <div className="my-3 p-3 rounded-[12px] bg-[#E5FE40]/10 border border-[#E5FE40]/40 flex items-center justify-between">
          <div>
            <span className="text-[10px] font-mono font-black uppercase text-[#E5FE40]">
              🎉 REWARD UNLOCKED:
            </span>
            <p className="text-xs font-mono font-bold text-white">{selectedReward.title}</p>
            <p className="text-[10px] text-[#A1A1AA]">{selectedReward.desc}</p>
          </div>
          <span className="text-[10px] font-mono font-black px-2 py-1 rounded bg-[#E5FE40] text-black">
            EQUIPPED
          </span>
        </div>
      )}

      {/* SPIN BUTTON */}
      <button
        onClick={handleSpin}
        disabled={isSpinning || coins < 100}
        className="w-full mt-2 py-3.5 rounded-[14px] cred-plunk-primary flex items-center justify-center space-x-2 text-xs font-mono font-black tracking-wider uppercase disabled:opacity-50"
      >
        <Zap className="w-4 h-4" />
        <span>{isSpinning ? 'REELING MAX LOOT...' : 'SPIN TO CLAIM REWARD (100 COINS)'}</span>
      </button>
    </div>
  );
}
