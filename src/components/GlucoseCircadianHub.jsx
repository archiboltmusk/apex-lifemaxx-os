import React, { useState, useEffect } from 'react';
import {
  Zap,
  Sun,
  Moon,
  ArrowRight,
  ShieldCheck,
  TrendingDown,
  Clock,
  Plane,
  Play,
  Pause,
  RotateCcw,
  Coffee,
  Footprints,
  AlertCircle
} from 'lucide-react';
import { playPlunk, playCoinChime, playHealthSyncChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function GlucoseCircadianHub() {
  // Circadian Peak Window State
  const [wakeHour, setWakeHour] = useState(6.5); // 06:30 AM
  const peakStartHour = wakeHour + 9.5; // 4:00 PM
  const peakEndHour = wakeHour + 11.5; // 6:00 PM

  // Post-Meal GLUT4 Walk Timer State
  const [glut4Seconds, setGlut4Seconds] = useState(15 * 60); // 15 mins
  const [isGlut4Running, setIsGlut4Running] = useState(false);
  const [glut4Steps, setGlut4Steps] = useState(0);

  // Caffeine Adenosine Decay State
  const [caffeineDoseMg, setCaffeineDoseMg] = useState(150); // 150mg Double Espresso
  const [hoursSinceCaffeine, setHoursSinceCaffeine] = useState(4); // 4 hours ago
  const caffeineHalfLife = 5.7; // hours
  const remainingCaffeineMg = +(caffeineDoseMg * Math.pow(0.5, hoursSinceCaffeine / caffeineHalfLife)).toFixed(1);
  const timeToSleepClearance = Math.max(0, +(caffeineHalfLife * Math.log2(caffeineDoseMg / 15) - hoursSinceCaffeine).toFixed(1));

  // GLUT4 Timer Interval
  useEffect(() => {
    let interval = null;
    if (isGlut4Running && glut4Seconds > 0) {
      interval = setInterval(() => {
        setGlut4Seconds((s) => s - 1);
        setGlut4Steps((steps) => steps + 1);
      }, 1000);
    } else if (glut4Seconds === 0 && isGlut4Running) {
      setIsGlut4Running(false);
      playCoinChime();
      try {
        confetti({
          particleCount: 50,
          spread: 60,
          colors: ['#10B981', '#E5FE40', '#00F0FF'],
        });
      } catch {}
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [isGlut4Running, glut4Seconds]);

  // Listen for external GLUT4 triggers from MealScanner or Proactive Directive
  useEffect(() => {
    const handleGlut4External = () => {
      setIsGlut4Running(true);
      setGlut4Seconds(15 * 60);
      setGlut4Steps(0);
    };
    window.addEventListener('apex:start-glut4-walk', handleGlut4External);
    return () => window.removeEventListener('apex:start-glut4-walk', handleGlut4External);
  }, []);

  const handleStartGlut4 = () => {
    playPlunk();
    setIsGlut4Running(!isGlut4Running);
  };

  const handleResetGlut4 = () => {
    playPlunk();
    setIsGlut4Running(false);
    setGlut4Seconds(15 * 60);
    setGlut4Steps(0);
  };

  return (
    <div className="space-y-6">
      {/* 1. CIRCADIAN PEAK STRENGTH & 1RM WINDOW */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center">
              <Sun className="w-5 h-5 text-[#E5FE40]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">Circadian Peak Physical Output Engine</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  OPTIMAL 1RM WINDOW
                </span>
              </div>
              <p className="text-[11px] font-mono text-[#8A8A8A]">
                Core body temperature & neuromuscular conduction velocity peak 9–11h after waking
              </p>
            </div>
          </div>
          <span className="text-xs font-mono font-bold text-[#E5FE40]">
            PEAK: 04:00 PM – 06:00 PM
          </span>
        </div>

        <div className="p-4 rounded-[18px] bg-black/60 border border-white/10 grid grid-cols-1 md:grid-cols-3 gap-3 text-xs font-mono">
          <div className="p-3 rounded-[12px] bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#8A8A8A] block">WAKE TIME DETECTED</span>
            <strong className="text-white text-base">06:30 AM</strong>
            <span className="text-[9px] text-[#10B981] block">Cortisol awakening response</span>
          </div>

          <div className="p-3 rounded-[12px] bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#E5FE40] block">MAX STRENGTH CAPACITY</span>
            <strong className="text-white text-base">+6.2% Peak Torque</strong>
            <span className="text-[9px] text-[#8A8A8A] block">Between 4:00 PM - 6:00 PM</span>
          </div>

          <div className="p-3 rounded-[12px] bg-white/5 border border-white/5">
            <span className="text-[10px] text-[#FA114F] block">CAFFEINE CUTOFF</span>
            <strong className="text-white text-base">02:00 PM</strong>
            <span className="text-[9px] text-[#FA114F] block">Strict cutoff for delta sleep</span>
          </div>
        </div>
      </div>

      {/* 2. POSTPRANDIAL GLUT4 GLUCOSE BLUNTING ENGINE */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
              <Footprints className="w-5 h-5 text-[#10B981]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">Postprandial GLUT4 Glucose Blunting Walk</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  -38% GLYCEMIC SPIKE
                </span>
              </div>
              <p className="text-[11px] font-mono text-[#8A8A8A]">
                15 minutes of light locomotion stimulates non-insulin dependent GLUT4 muscle translocation
              </p>
            </div>
          </div>

          <span className="text-xs font-mono text-[#10B981] font-bold">1,000 STEP TARGET</span>
        </div>

        {/* Interactive Walk Timer */}
        <div className="p-5 rounded-[20px] bg-black/60 border border-white/10 flex flex-wrap items-center justify-between gap-4 font-mono">
          <div>
            <span className="text-[10px] text-[#8A8A8A] block uppercase">COUNTDOWN TIMER</span>
            <div className="text-3xl font-black text-white">
              {Math.floor(glut4Seconds / 60)}:{(glut4Seconds % 60).toString().padStart(2, '0')}
            </div>
            <span className="text-[11px] text-[#10B981]">{glut4Steps} steps estimated</span>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={handleStartGlut4}
              className={`px-5 py-2.5 rounded-[12px] font-black text-xs uppercase flex items-center space-x-2 transition ${
                isGlut4Running
                  ? 'bg-[#F59E0B] text-black'
                  : 'bg-[#10B981] text-black hover:bg-[#10B981]/80 shadow-[0_0_15px_rgba(16,185,129,0.4)]'
              }`}
            >
              {isGlut4Running ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4 fill-black" />}
              <span>{isGlut4Running ? 'PAUSE WALK' : 'START 15M WALK'}</span>
            </button>

            <button
              onClick={handleResetGlut4}
              className="px-3.5 py-2.5 rounded-[12px] bg-white/10 hover:bg-white/20 text-white text-xs"
            >
              <RotateCcw className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* 3. CAFFEINE ADENOSINE DECAY CURVE */}
      <div className="liquid-glass rounded-[26px] p-6 border border-white/10 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#FA114F]/20 border border-[#FA114F]/40 flex items-center justify-center">
              <Coffee className="w-5 h-5 text-[#FA114F]" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-white tracking-tight">Caffeine Adenosine Pharmacokinetics (t½ = 5.7h)</h3>
              <p className="text-[11px] font-mono text-[#8A8A8A]">
                Predicts circulating caffeine and receptor clearance for restorative sleep
              </p>
            </div>
          </div>
          <span className="text-xs font-mono font-bold text-[#FA114F]">
            {remainingCaffeineMg} mg IN BLOODSTREAM
          </span>
        </div>

        {/* Dose Selector */}
        <div className="flex flex-wrap items-center gap-2 font-mono text-xs">
          <span className="text-[#8A8A8A] text-[11px]">LOGGED DOSE:</span>
          {[
            { label: 'Single Espresso (75mg)', dose: 75 },
            { label: 'Double Espresso (150mg)', dose: 150 },
            { label: 'Cold Brew (200mg)', dose: 200 },
            { label: 'Pre-Workout (300mg)', dose: 300 },
          ].map((item) => (
            <button
              key={item.dose}
              onClick={() => {
                playPlunk();
                setCaffeineDoseMg(item.dose);
              }}
              className={`px-3 py-1.5 rounded-[10px] transition ${
                caffeineDoseMg === item.dose
                  ? 'bg-[#FA114F] text-white font-black shadow-[0_0_12px_rgba(250,17,79,0.4)]'
                  : 'bg-white/5 text-[#8A8A8A] hover:text-white'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>

        {/* Clearance Card */}
        <div className="p-4 rounded-[18px] bg-black/60 border border-white/10 flex items-center justify-between text-xs font-mono">
          <div>
            <span className="text-[#8A8A8A] text-[10px] block">HOURS UNTIL SLEEP RECEPTORS CLEAR (&lt; 15mg)</span>
            <strong className="text-lg text-white font-black">{timeToSleepClearance} Hours Remaining</strong>
          </div>
          <span className="text-[#10B981] font-bold px-3 py-1 rounded bg-[#10B981]/20 border border-[#10B981]/40">
            {timeToSleepClearance <= 2 ? 'SAFE FOR SLEEP' : 'DECAY IN PROGRESS'}
          </span>
        </div>
      </div>
    </div>
  );
}
