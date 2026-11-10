import React from 'react';
import {
  X,
  Crown,
  ShieldCheck,
  Sparkles,
  Zap,
  RefreshCw,
  Coins,
  CheckCircle2,
  Lock,
  Unlock,
  User,
  Heart
} from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function AccountTesterModal({
  isOpen,
  onClose,
  userProfile,
  setUserProfile,
  coins,
  setCoins,
  streakDays,
  setStreakDays,
  onCompleteAllProtocols,
  membershipPlan,
  setMembershipPlan,
}) {
  if (!isOpen) return null;

  const switchToFounder = () => {
    playPlunk();
    playCoinChime();
    setUserProfile({
      name: 'Alexander Vance',
      handle: '@vance.apex',
      tier: 'LIFETIME SOVEREIGN (FOUNDER #001)',
      badge: '👑 APEX 0.01%',
      appleId: 'alexander.vance@apex.club',
      status: 'VERIFIED TESTER',
    });
    setMembershipPlan('lifetime');
    setCoins((c) => Math.max(c, 10000));
    setStreakDays(42);
    try {
      confetti({
        particleCount: 70,
        spread: 60,
        colors: ['#E5FE40', '#00F0FF', '#FA114F'],
      });
    } catch {}
  };

  const switchToFreeUser = () => {
    playPlunk();
    setUserProfile({
      name: 'Test Athlete (Guest)',
      handle: '@guest.trial',
      tier: 'FREE TIER (PAYWALL ACTIVE)',
      badge: 'GUEST',
      appleId: 'guest@icloud.com',
      status: 'UNVERIFIED',
    });
    setMembershipPlan(null);
    setCoins(150);
    setStreakDays(1);
  };

  const addFreeCoins = (amount = 1000) => {
    playPlunk();
    playCoinChime();
    setCoins((c) => c + amount);
    try {
      confetti({
        particleCount: 50,
        spread: 50,
        colors: ['#E5FE40', '#10B981'],
      });
    } catch {}
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-2xl animate-fade-in">
      <div className="liquid-glass-elevated w-full max-w-lg rounded-[32px] p-6 border border-white/20 relative shadow-[0_25px_80px_rgba(0,0,0,0.95)]">
        {/* Close Button */}
        <button
          onClick={() => {
            playPlunk();
            onClose();
          }}
          className="absolute top-5 right-5 w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white/80 transition"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Header */}
        <div className="flex items-center space-x-3 mb-5">
          <div className="w-12 h-12 rounded-[16px] bg-[#E5FE40] text-black font-mono font-black text-xl flex items-center justify-center border border-black shadow-[2px_2px_0px_#000]">
            ▲
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h3 className="text-lg font-bold text-white tracking-tight">Testing Account Hub</h3>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-bold">
                DEV MODE
              </span>
            </div>
            <p className="text-xs text-[#A1A1AA] font-mono">
              Switch test accounts & trigger developer bypass states
            </p>
          </div>
        </div>

        {/* ACTIVE PROFILE BADGE */}
        <div className="p-4 rounded-[20px] bg-black/60 border border-white/15 mb-5 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-[#E5FE40] via-[#00F0FF] to-[#FA114F] p-0.5">
                <div className="w-full h-full rounded-full bg-black flex items-center justify-center text-white font-mono font-black text-sm">
                  {userProfile.name[0]}
                </div>
              </div>
              <div>
                <h4 className="text-sm font-bold text-white">{userProfile.name}</h4>
                <span className="text-[11px] font-mono text-[#00F0FF] block">{userProfile.handle}</span>
              </div>
            </div>

            <span className="text-[10px] font-mono font-black px-2.5 py-1 rounded bg-[#E5FE40] text-black">
              {userProfile.badge}
            </span>
          </div>

          <div className="grid grid-cols-2 gap-2 text-xs font-mono pt-2 border-t border-white/5">
            <div>
              <span className="text-[10px] text-[#8A8A8A] block">MEMBERSHIP STATUS</span>
              <span className="text-white font-bold">{userProfile.tier}</span>
            </div>
            <div>
              <span className="text-[10px] text-[#8A8A8A] block">COIN BALANCE</span>
              <span className="text-[#E5FE40] font-black">{coins} APEX COINS</span>
            </div>
          </div>
        </div>

        {/* TEST ACCOUNT SWITCHER */}
        <div className="space-y-2 mb-5">
          <span className="text-[10px] font-mono text-[#8A8A8A] uppercase tracking-wider block">
            PRE-CONFIGURED TEST PROFILES
          </span>

          {/* Profile 1: VIP Founder */}
          <div
            onClick={switchToFounder}
            className={`p-3.5 rounded-[16px] border transition cursor-pointer flex items-center justify-between ${
              membershipPlan === 'lifetime'
                ? 'bg-[#E5FE40]/15 border-[#E5FE40] text-white shadow-[0_0_15px_rgba(229,254,64,0.3)]'
                : 'bg-white/[0.04] border-white/10 hover:border-white/25'
            }`}
          >
            <div className="flex items-center space-x-3">
              <Crown className="w-5 h-5 text-[#E5FE40]" />
              <div>
                <div className="flex items-center space-x-2">
                  <span className="text-xs font-mono font-black text-white">VIP 0.01% FOUNDER ACCOUNT</span>
                  <span className="text-[9px] font-mono px-1.5 rounded bg-[#10B981] text-black font-bold">
                    RECOMMENDED
                  </span>
                </div>
                <span className="text-[11px] text-[#A1A1AA] block">
                  All features unlocked · 10,000 Coins · 42-day Warrior streak · Zero paywalls
                </span>
              </div>
            </div>
            {membershipPlan === 'lifetime' && <CheckCircle2 className="w-4 h-4 text-[#E5FE40]" />}
          </div>

          {/* Profile 2: Free User Trial */}
          <div
            onClick={switchToFreeUser}
            className={`p-3.5 rounded-[16px] border transition cursor-pointer flex items-center justify-between ${
              !membershipPlan
                ? 'bg-white/15 border-white/40 text-white'
                : 'bg-white/[0.04] border-white/10 hover:border-white/25'
            }`}
          >
            <div className="flex items-center space-x-3">
              <Lock className="w-5 h-5 text-[#FA114F]" />
              <div>
                <span className="text-xs font-mono font-bold text-white block">GUEST / FREE TIER ACCOUNT</span>
                <span className="text-[11px] text-[#A1A1AA] block">
                  Paywalls active · 150 Coins · Test upgrade checkout flows
                </span>
              </div>
            </div>
            {!membershipPlan && <CheckCircle2 className="w-4 h-4 text-white" />}
          </div>
        </div>

        {/* DEVELOPER RAPID TEST TRIGGERS */}
        <div className="grid grid-cols-2 gap-2 mb-4">
          <button
            onClick={() => addFreeCoins(2500)}
            className="py-2.5 px-3 rounded-[12px] bg-white/10 hover:bg-white/15 text-xs font-mono font-bold text-white border border-white/10 flex items-center justify-center space-x-1.5 transition"
          >
            <Coins className="w-3.5 h-3.5 text-[#E5FE40]" />
            <span>+2,500 COINS</span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              if (onCompleteAllProtocols) onCompleteAllProtocols();
            }}
            className="py-2.5 px-3 rounded-[12px] bg-white/10 hover:bg-white/15 text-xs font-mono font-bold text-white border border-white/10 flex items-center justify-center space-x-1.5 transition"
          >
            <CheckCircle2 className="w-3.5 h-3.5 text-[#10B981]" />
            <span>COMPLETE PROTOCOLS</span>
          </button>
        </div>

        {/* Done Button */}
        <button
          onClick={() => {
            playPlunk();
            onClose();
          }}
          className="w-full py-3.5 rounded-[14px] cred-plunk-primary text-xs font-mono font-black uppercase tracking-wider"
        >
          RETURN TO APEX // OS
        </button>
      </div>
    </div>
  );
}
