import React, { useState } from 'react';
import {
  Bot,
  Send,
  Sparkles,
  User,
  Zap,
  ShieldCheck,
  RefreshCw,
  Heart,
  Smile,
  Glasses,
  Flame,
  CheckCircle2
} from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';

export default function AIConsigliere() {
  // Livity AI Coach Persona: 'buddy' | 'nerd'
  const [coachPersona, setCoachPersona] = useState('buddy'); // 'buddy' | 'nerd'

  const getUserFirstName = () => {
    try {
      const saved = JSON.parse(localStorage.getItem('apex_user_profile') || '{}');
      return saved.name ? saved.name.split(' ')[0] : 'there';
    } catch {
      return 'there';
    }
  };

  const [messages, setMessages] = useState(() => {
    const firstName = getUserFirstName();
    return [
      {
        role: 'assistant',
        text: `Hey ${firstName}! 🚀 You crushed your sleep last night (8h 22m with 2h 15m deep sleep)! Your recovery score is 94% — you're completely in the green. Today is an absolute push day. Let's hit that 18.0 strain target and lock in a workout! How are you feeling right now?`,
      },
    ];
  });

  const [inputPrompt, setInputPrompt] = useState('');
  const [isTyping, setIsTyping] = useState(false);

  const handlePersonaSwitch = (newPersona) => {
    playPlunk();
    setCoachPersona(newPersona);
    const greeting =
      newPersona === 'buddy'
        ? "Switched to Buddy mode! ⚡ I've got your back. I read your sleep and recovery and I'm ready to keep you fired up all day. What do you want to conquer next?"
        : "Switched to Nerd mode (Sports Science & Clinical Precision). 🧬 Calibrated to Attia, Huberman, and Levine protocols. Standing by for biometric queries.";
    setMessages((prev) => [...prev, { role: 'assistant', text: greeting }]);
  };

  const handleSend = (textToSend) => {
    const prompt = textToSend || inputPrompt;
    if (!prompt.trim()) return;

    playPlunk();
    const userMsg = { role: 'user', text: prompt };
    setMessages((prev) => [...prev, userMsg]);
    setInputPrompt('');
    setIsTyping(true);

    setTimeout(() => {
      setIsTyping(false);
      playCoinChime();

      let reply = '';
      const lower = prompt.toLowerCase();

      if (coachPersona === 'buddy') {
        if (lower.includes('push') || lower.includes('workout') || lower.includes('exercise')) {
          reply =
            "Heck yeah! Today is 100% a green light to PUSH! 💥 Your body is fully recharged at 94% recovery. Fire up the camera workout tracker for some deep squats or hit heavy deadlifts. You've got the energy in the tank, make it count!";
        } else if (lower.includes('sleep') || lower.includes('tired')) {
          reply =
            "Your sleep last night was phenomenal — 2h 15m of deep repair sleep! If you're feeling an afternoon dip around 2:30 PM, that's just your natural circadian rhythm. Grab some water, get 5 minutes of sunlight, and push through — no caffeine after 2 PM!";
        } else if (lower.includes('week') || lower.includes('progress') || lower.includes('pattern')) {
          reply =
            "Looking at your week, you're on a 42-day streak! 🔥 You hit all three activity rings 6 out of 7 days, your fitness age dropped another 0.4 years, and your average strain was 16.8. You are crushing the top 1%!";
        } else {
          reply = `Awesome question! With your current 94% recovery and 840 active calories burned, you're in prime shape. Stay hydrated, keep that momentum going, and let's crush today's protocols together! 🏆`;
        }
      } else {
        // Nerd Persona
        if (lower.includes('push') || lower.includes('workout') || lower.includes('exercise')) {
          reply =
            "Cardiovascular & Muscular Analysis: Autonomic readiness index: 94.2/100. Vagal tone supports maximal cardiac output (VO2 Max 54.2 mL/kg). Prescribed stimulus: 45 min Zone 2 aerobic base (134-142 bpm) followed by 4x4 min Zone 5 HIIT at >90% HRmax. Expected EPOC: 380 kcal.";
        } else if (lower.includes('sleep') || lower.includes('tired')) {
          reply =
            "Polysomnography breakdown: Deep N3 cellular stage 27% (135 min), REM stage 23% (115 min). Core temperature nadir occurred at 04:12 AM. Postprandial dip at 14:15 reflects circadian adenosine accumulation. Light intervention: 10,000 lux outdoor photon stimulation resets melanopsin retinal ganglion cells.";
        } else if (lower.includes('week') || lower.includes('progress') || lower.includes('pattern')) {
          reply =
            "Weekly Epigenetic & Hemodynamic Retrospective: Cumulative strain 118.4 Borg units. Resting heart rate trending downward (-2 bpm delta). PhenoAge regression indicates pace of aging sustained at 0.74x/yr. DunedinPACE cohort rank: 99.9th percentile.";
        } else {
          reply = `Biometric evaluation for "${prompt}": Telemetry matches optimal homeostasis. Fasting insulin estimated < 3.0 uIU/mL, Hs-CRP at 0.22 mg/L. All physiological systems are within longevity target brackets.`;
        }
      }

      setMessages((prev) => [...prev, { role: 'assistant', text: reply }]);
    }, 750);
  };

  return (
    <div className="space-y-4">
      {/* CHAT CONTAINER */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 flex flex-col h-[540px] justify-between">
        {/* Top Header */}
        <div className="flex flex-wrap items-center justify-between pb-3 border-b border-white/10 shrink-0 gap-3">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center">
              <Bot className="w-5 h-5 text-[#E5FE40]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">Livity AI Virtual Coach</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-bold">
                  READS LIVE RECOVERY & STRAIN
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Like a sports scientist in your pocket · Remembers your goals
              </span>
            </div>
          </div>

          {/* Persona Switcher: Buddy vs Nerd */}
          <div className="flex items-center space-x-1 p-1 rounded-[14px] bg-black/60 border border-white/10 text-xs font-mono">
            <button
              onClick={() => handlePersonaSwitch('buddy')}
              className={`px-3 py-1.5 rounded-[10px] font-bold flex items-center space-x-1.5 transition ${
                coachPersona === 'buddy'
                  ? 'bg-[#E5FE40] text-black font-black shadow-[0_0_10px_rgba(229,254,64,0.4)]'
                  : 'text-[#8A8A8A] hover:text-white'
              }`}
            >
              <Smile className="w-3.5 h-3.5" />
              <span>BUDDY (Warm)</span>
            </button>

            <button
              onClick={() => handlePersonaSwitch('nerd')}
              className={`px-3 py-1.5 rounded-[10px] font-bold flex items-center space-x-1.5 transition ${
                coachPersona === 'nerd'
                  ? 'bg-[#00F0FF] text-black font-black shadow-[0_0_10px_rgba(0,240,255,0.4)]'
                  : 'text-[#8A8A8A] hover:text-white'
              }`}
            >
              <Glasses className="w-3.5 h-3.5" />
              <span>NERD (Data)</span>
            </button>
          </div>
        </div>

        {/* Message Thread */}
        <div className="flex-1 overflow-y-auto no-scrollbar py-4 space-y-3">
          {messages.map((m, idx) => (
            <div
              key={idx}
              className={`flex items-start space-x-2.5 ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              {m.role === 'assistant' && (
                <div className="w-7 h-7 rounded-lg bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center shrink-0 mt-0.5">
                  <Bot className="w-4 h-4 text-[#E5FE40]" />
                </div>
              )}

              <div
                className={`p-3.5 rounded-[18px] max-w-md text-xs font-mono leading-relaxed ${
                  m.role === 'user'
                    ? 'bg-[#E5FE40] text-black font-bold shadow-[2px_2px_0px_#000]'
                    : 'bg-black/60 border border-white/10 text-white/95'
                }`}
              >
                {m.text}
              </div>

              {m.role === 'user' && (
                <div className="w-7 h-7 rounded-full bg-white/20 flex items-center justify-center shrink-0 mt-0.5">
                  <User className="w-4 h-4 text-white" />
                </div>
              )}
            </div>
          ))}

          {isTyping && (
            <div className="flex items-center space-x-2 text-[#E5FE40] font-mono text-xs animate-pulse">
              <Bot className="w-4 h-4" />
              <span>
                {coachPersona === 'buddy'
                  ? 'Coach Buddy is checking your recovery scores...'
                  : 'Running inference across physiological telemetry...'}
              </span>
            </div>
          )}
        </div>

        {/* Quick Suggestion Chips */}
        <div className="flex items-center space-x-2 pb-3 overflow-x-auto no-scrollbar text-[11px] font-mono text-[#A1A1AA]">
          <button
            onClick={() => handleSend('Should I push today or recover?')}
            className="px-2.5 py-1 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 shrink-0 transition"
          >
            "Should I push today or recover?"
          </button>
          <button
            onClick={() => handleSend('How was my week and sleep?')}
            className="px-2.5 py-1 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 shrink-0 transition"
          >
            "How was my week and sleep?"
          </button>
          <button
            onClick={() => handleSend('What patterns should I know?')}
            className="px-2.5 py-1 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 shrink-0 transition"
          >
            "What patterns should I know?"
          </button>
        </div>

        {/* Prompt Input Form */}
        <form
          onSubmit={(e) => {
            e.preventDefault();
            handleSend();
          }}
          className="flex items-center space-x-2 pt-2 border-t border-white/10 shrink-0"
        >
          <input
            type="text"
            placeholder={
              coachPersona === 'buddy'
                ? 'Ask Coach Buddy anything about your workouts, sleep, or goals...'
                : 'Ask Coach Nerd for biomarker regressions, HRV analysis, or Zone 2 target...'
            }
            value={inputPrompt}
            onChange={(e) => setInputPrompt(e.target.value)}
            className="flex-1 px-4 py-3 rounded-[16px] bg-black/60 border border-white/15 text-white placeholder-white/40 font-mono text-xs focus:outline-none focus:border-[#E5FE40] transition"
          />
          <button
            type="submit"
            className="w-11 h-11 rounded-[16px] bg-[#E5FE40] hover:bg-[#d8f030] text-black flex items-center justify-center font-bold transition shadow-[0_0_15px_rgba(229,254,64,0.4)]"
          >
            <Send className="w-4 h-4" />
          </button>
        </form>
      </div>
    </div>
  );
}
