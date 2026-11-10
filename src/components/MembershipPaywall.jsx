import React, { useState } from 'react';
import {
  X,
  Check,
  Zap,
  ShieldCheck,
  Sparkles,
  Trophy,
  CreditCard,
  Lock,
  ChevronRight,
  Award,
  Crown
} from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function MembershipPaywall({ isOpen, onClose, onMembershipActivated, currentPlan }) {
  const [billingCycle, setBillingCycle] = useState('annual'); // 'monthly' | 'annual' | 'lifetime'
  const [isProcessing, setIsProcessing] = useState(false);

  if (!isOpen) return null;

  const handleSubscribe = () => {
    playPlunk();
    setIsProcessing(true);

    setTimeout(() => {
      setIsProcessing(false);
      playCoinChime();
      try {
        confetti({
          particleCount: 100,
          spread: 80,
          origin: { y: 0.6 },
          colors: ['#E5FE40', '#00F0FF', '#FA114F', '#10B981'],
        });
      } catch {}
      if (onMembershipActivated) onMembershipActivated(billingCycle);
      onClose();
    }, 1200);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-2xl animate-fade-in">
      <div className="liquid-glass-elevated w-full max-w-xl rounded-[32px] p-6 md:p-8 border border-white/20 relative shadow-[0_25px_80px_rgba(0,0,0,0.95)] overflow-hidden">
        {/* Background Ambient Glow */}
        <div className="absolute top-0 right-0 w-80 h-80 bg-gradient-to-br from-[#E5FE40]/15 via-[#FA114F]/10 to-transparent rounded-full blur-3xl pointer-events-none" />

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
        <div className="text-center space-y-2 mb-6">
          <div className="inline-flex items-center space-x-1.5 px-3 py-1 rounded-full bg-[#E5FE40]/20 text-[#E5FE40] border border-[#E5FE40]/40 text-[10px] font-mono font-black uppercase tracking-widest">
            <Crown className="w-3.5 h-3.5 text-[#E5FE40]" />
            <span>APEX SOVEREIGN MEMBERSHIP</span>
          </div>
          <h2 className="text-2xl md:text-3xl font-black text-white tracking-tight">
            Ascend to the <span className="holo-glow">Top 0.01%</span>
          </h2>
          <p className="text-xs text-[#A1A1AA] max-w-md mx-auto">
            Choose your membership tier: Flexible monthly recurring or zero-subscription lifetime ownership.
          </p>
        </div>

        {/* BILLING TOGGLE (MONTHLY vs ANNUAL vs ONE-TIME LIFETIME) */}
        <div className="p-1 rounded-[16px] bg-black/60 border border-white/10 flex items-center justify-between mb-6 text-xs font-mono">
          <button
            onClick={() => {
              playPlunk();
              setBillingCycle('monthly');
            }}
            className={`flex-1 py-2.5 rounded-[12px] transition font-bold ${
              billingCycle === 'monthly'
                ? 'bg-white/15 text-white shadow-[0_0_12px_rgba(255,255,255,0.2)] font-black'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            Monthly Recurring
          </button>

          <button
            onClick={() => {
              playPlunk();
              setBillingCycle('annual');
            }}
            className={`flex-1 py-2.5 rounded-[12px] transition font-bold relative ${
              billingCycle === 'annual'
                ? 'bg-[#E5FE40] text-black font-black shadow-[0_0_15px_rgba(229,254,64,0.4)]'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            Annual (Save 43%)
            <span className="absolute -top-2 right-2 text-[9px] font-mono font-black px-1.5 py-0.2 rounded bg-[#FA114F] text-white">
              POPULAR
            </span>
          </button>

          <button
            onClick={() => {
              playPlunk();
              setBillingCycle('lifetime');
            }}
            className={`flex-1 py-2.5 rounded-[12px] transition font-bold ${
              billingCycle === 'lifetime'
                ? 'bg-[#00F0FF] text-black font-black shadow-[0_0_15px_rgba(0,240,255,0.4)]'
                : 'text-[#8A8A8A] hover:text-white'
            }`}
          >
            One-Time Lifetime
          </button>
        </div>

        {/* PRICING HERO CARD */}
        <div className="liquid-glass rounded-[22px] p-5 border border-white/15 mb-6 text-center">
          {billingCycle === 'monthly' && (
            <div>
              <span className="text-[10px] font-mono text-[#8A8A8A] uppercase">MONTHLY SUBSCRIPTION</span>
              <div className="flex items-baseline justify-center space-x-1 my-1">
                <span className="text-4xl font-mono font-black text-white">$29</span>
                <span className="text-xs font-mono text-[#8A8A8A]">/ month</span>
              </div>
              <p className="text-[11px] text-[#A1A1AA]">Cancel anytime with 1-click in App Store settings</p>
            </div>
          )}

          {billingCycle === 'annual' && (
            <div>
              <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase">
                ANNUAL SOVEREIGN MEMBERSHIP
              </span>
              <div className="flex items-baseline justify-center space-x-1 my-1">
                <span className="text-4xl font-mono font-black text-white">$199</span>
                <span className="text-xs font-mono text-[#8A8A8A]">/ year ($16.58 / mo)</span>
              </div>
              <p className="text-[11px] text-[#A1A1AA]">Includes 5,000 bonus APEX coins + physical titanium NFC card</p>
            </div>
          )}

          {billingCycle === 'lifetime' && (
            <div>
              <span className="text-[10px] font-mono text-[#00F0FF] font-black uppercase">
                FOUNDER'S ONE-TIME LIFETIME PASS
              </span>
              <div className="flex items-baseline justify-center space-x-1 my-1">
                <span className="text-4xl font-mono font-black text-white">$499</span>
                <span className="text-xs font-mono text-[#00F0FF] font-bold">ONE-TIME (ZERO SUBSCRIPTION FOREVER)</span>
              </div>
              <p className="text-[11px] text-[#A1A1AA]">Pay once, own all current & future APEX OS updates for life</p>
            </div>
          )}
        </div>

        {/* FEATURE UNLOCKS CHECKLIST */}
        <div className="space-y-2 mb-6 text-xs font-mono">
          {[
            'Unlimited Apple HealthKit v18.2 biometric synchronization',
            'Full Multi-Frequency Binaural Engine (Gamma 40Hz, Alpha, Theta, Delta, Brown Noise)',
            'On-Device Lifemaxx AI Consigliere & Bloodwork OCR Parser',
            'TrueDepth LiDAR Cranial Scanner & Facial Symmetry Index',
            'The Anti-Charity Burn Vault & 0.01% Global Clan Access',
            'Dexcom CGM Glycemic Modeling & Circadian Jetlag Protocols',
            billingCycle === 'lifetime'
              ? 'VIP Founder Crown Badge & Physical Titanium NFC Member Card'
              : 'Continuous Cloud Telemetry Backup',
          ].map((item, idx) => (
            <div key={idx} className="flex items-center space-x-2.5 text-white/90">
              <div className="w-4 h-4 rounded-full bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center shrink-0">
                <Check className="w-2.5 h-2.5 text-[#10B981] stroke-[3]" />
              </div>
              <span>{item}</span>
            </div>
          ))}
        </div>

        {/* CHECKOUT BUTTON WITH APPLE PAY */}
        <button
          onClick={handleSubscribe}
          disabled={isProcessing}
          className="w-full py-4 rounded-[16px] cred-plunk-primary flex items-center justify-center space-x-2 text-xs font-mono font-black uppercase tracking-wider"
        >
          <CreditCard className="w-4 h-4" />
          <span>
            {isProcessing
              ? 'CONFIRMING VIA APPLE PAY...'
              : billingCycle === 'lifetime'
              ? 'UNLOCK LIFETIME ACCESS ($499 ONE-TIME)'
              : billingCycle === 'annual'
              ? 'SUBSCRIBE ANNUALLY ($199 / YEAR)'
              : 'SUBSCRIBE MONTHLY ($29 / MONTH)'}
          </span>
        </button>

        <p className="text-center text-[10px] font-mono text-[#8A8A8A] mt-3">
          Secured with Apple In-App Purchases & 256-bit biometrics. Restore purchases anytime.
        </p>
      </div>
    </div>
  );
}
