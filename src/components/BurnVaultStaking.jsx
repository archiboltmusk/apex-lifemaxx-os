import React, { useState } from 'react';
import { Flame, ShieldAlert, Trophy, Award, Zap, ChevronRight, Lock, CheckCircle2 } from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function BurnVaultStaking({ coins, setCoins }) {
  const [activeStake, setActiveStake] = useState(null); // { amount: 500, target: '10,000 Steps' }
  const [stakeAmount, setStakeAmount] = useState(500);

  const lockStake = () => {
    if (coins < stakeAmount) {
      alert('Insufficient APEX Coins to lock stake!');
      return;
    }
    playPlunk();
    setCoins((c) => c - stakeAmount);
    setActiveStake({
      amount: stakeAmount,
      target: 'Lock in 10,000 Steps & 90% Sleep Need Today',
      potentialWin: stakeAmount * 2,
    });
    playCoinChime();
    try {
      confetti({
        particleCount: 50,
        spread: 60,
        colors: ['#FA114F', '#F59E0B', '#E5FE40'],
      });
    } catch {}
  };

  const claimWin = () => {
    if (!activeStake) return;
    playPlunk();
    playCoinChime();
    setCoins((c) => c + activeStake.potentialWin);
    setActiveStake(null);
    try {
      confetti({
        particleCount: 100,
        spread: 80,
        colors: ['#E5FE40', '#10B981', '#00F0FF'],
      });
    } catch {}
  };

  return (
    <div className="space-y-6">
      {/* THE BURN VAULT HERO */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 relative overflow-hidden">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#FA114F]/20 border border-[#FA114F]/40 flex items-center justify-center">
              <Flame className="w-5 h-5 text-[#FA114F]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-base font-bold text-white tracking-tight">The Anti-Charity Burn Vault</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#FA114F]/20 text-[#FA114F] border border-[#FA114F]/40 font-black">
                  HIGH STAKES
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Put skin in the game. Hit your protocols or burn your coins.
              </span>
            </div>
          </div>

          <div className="text-right">
            <span className="text-[10px] font-mono text-[#8A8A8A] block uppercase">COIN BALANCE</span>
            <span className="text-lg font-mono font-black text-[#E5FE40]">{coins} APEX</span>
          </div>
        </div>

        {/* Active Stake or Staking Form */}
        {activeStake ? (
          <div className="p-4 rounded-[18px] bg-[#FA114F]/10 border border-[#FA114F]/40 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <Lock className="w-4 h-4 text-[#FA114F]" />
                <span className="text-xs font-mono font-bold text-white uppercase">
                  ACTIVE STAKE LOCKED: {activeStake.amount} COINS
                </span>
              </div>
              <span className="text-xs font-mono font-black text-[#10B981]">
                PAYOUT: +{activeStake.potentialWin} COINS
              </span>
            </div>
            <p className="text-xs text-white/90">{activeStake.target}</p>
            <button
              onClick={claimWin}
              className="w-full py-3 rounded-[12px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center justify-center space-x-2"
            >
              <CheckCircle2 className="w-4 h-4" />
              <span>GOAL ACHIEVED · CLAIM +{activeStake.potentialWin} COINS</span>
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex items-center space-x-2">
              {[250, 500, 1000].map((amt) => (
                <button
                  key={amt}
                  onClick={() => setStakeAmount(amt)}
                  className={`flex-1 py-2.5 rounded-[12px] text-xs font-mono font-bold border transition ${
                    stakeAmount === amt
                      ? 'bg-[#E5FE40] text-black border-[#E5FE40] font-black'
                      : 'bg-black/40 text-white border-white/10'
                  }`}
                >
                  {amt} COINS
                </button>
              ))}
            </div>

            <button
              onClick={lockStake}
              className="w-full py-3.5 rounded-[14px] cred-plunk-dark text-xs font-mono font-black uppercase border border-[#FA114F]/50 text-white flex items-center justify-center space-x-2"
            >
              <Flame className="w-4 h-4 text-[#FA114F]" />
              <span>LOCK {stakeAmount} COINS INTO BURN VAULT (2X WIN OR BURN)</span>
            </button>
          </div>
        )}
      </div>

      {/* GLOBAL 0.01% CLAN LEADERBOARD */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Trophy className="w-5 h-5 text-[#E5FE40]" />
            <h4 className="text-sm font-mono font-black text-white uppercase tracking-wider">
              GLOBAL 0.01% LIFEMAXXING CLAN LEADERBOARDS
            </h4>
          </div>
          <span className="text-xs font-mono text-[#E5FE40] font-black">SEASON 1</span>
        </div>

        <div className="space-y-2">
          {[
            { rank: 1, name: 'Clan Blueprint 0.01%', score: '14,920 pts', metric: '-7.4y Bio Age', badge: '👑 APEX ELITE' },
            { rank: 2, name: 'Titanium Sovereigns', score: '13,840 pts', metric: 'VO2 Max 62.4', badge: '🥈 DIAMOND' },
            { rank: 3, name: 'Apollo Apex Syndicate', score: '12,910 pts', metric: 'HRV 112ms', badge: '🥉 PLATINUM' },
            { rank: 42, name: 'You (Ascendant Warrior)', score: `${coins} pts`, metric: '-6.2y Bio Age', badge: '🔥 TOP 1%' },
          ].map((clan) => (
            <div
              key={clan.rank}
              className={`p-3.5 rounded-[16px] border flex items-center justify-between text-xs font-mono ${
                clan.rank === 42
                  ? 'bg-[#E5FE40]/10 border-[#E5FE40]/40 text-white'
                  : 'bg-white/[0.03] border-white/5 text-[#A1A1AA]'
              }`}
            >
              <div className="flex items-center space-x-3">
                <span className="font-mono font-black text-white w-6">#{clan.rank}</span>
                <div>
                  <span className="font-bold text-white block">{clan.name}</span>
                  <span className="text-[10px] text-[#00F0FF]">{clan.metric}</span>
                </div>
              </div>

              <div className="text-right">
                <span className="text-white font-black block">{clan.score}</span>
                <span className="text-[9px] font-bold text-[#E5FE40]">{clan.badge}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
