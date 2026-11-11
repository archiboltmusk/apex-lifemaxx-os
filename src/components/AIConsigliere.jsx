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

export default function AIConsigliere({ healthData, onConnectHealth }) {
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

  const buildLiveTelemetrySummary = () => {
    const hrv = healthData?.metrics?.hrv?.value || 0;
    const rhr = healthData?.metrics?.restingHeartRate?.value || 0;
    const vo2 = healthData?.metrics?.vo2Max?.value || 0;
    const move = healthData?.activityRings?.move?.current || 0;
    const moveTarget = healthData?.activityRings?.move?.target || 750;
    const sleep = healthData?.metrics?.sleep?.totalHours || 0;
    const bevel = healthData?.bevel || {};
    const readiness = bevel.readiness ?? healthData?.readinessScore ?? (hrv > 0 && rhr > 0 ? Math.min(99, Math.max(35, Math.round(50 + (hrv - 50) * 0.5 - (rhr - 55) * 0.6))) : null);
    const strain = bevel.strain ?? (move > 0 ? +((Math.min(1, move / Math.max(100, moveTarget))) * 18).toFixed(1) : null);
    const energyBank = bevel.energyBank ?? (readiness != null ? Math.max(12, Math.min(99, Math.round(readiness - (strain || 0) * 2))) : null);
    const stressScore = bevel.stressScore ?? (hrv > 0 && rhr > 0 ? Math.max(8, Math.min(95, Math.round(62 - (hrv - 45) * 0.45 + Math.max(0, rhr - 58) * 0.8))) : null);
    let labsCount = 0;
    let mealsCount = 0;
    let nutritionScore = null;
    let glucoseLatest = healthData?.metrics?.glucoseLatest || null;
    let journalTagsToday = [];
    try {
      labsCount = JSON.parse(localStorage.getItem('apex_user_bloodwork') || '[]').length;
      mealsCount = JSON.parse(localStorage.getItem('apex_logged_meals') || '[]').length;
      const nutSum = JSON.parse(localStorage.getItem('apex_ios_nutrition_summary') || 'null');
      nutritionScore = nutSum?.qualityScore || null;
      const gLogs = JSON.parse(localStorage.getItem('apex_glucose_logs_v1') || '[]');
      if (!glucoseLatest && gLogs[0]?.valueMgDl) glucoseLatest = gLogs[0].valueMgDl;
      const todayKey = new Date().toISOString().slice(0, 10);
      const jMap = JSON.parse(localStorage.getItem('apex_daily_journal_tags_v1') || '{}');
      journalTagsToday = jMap[todayKey] || [];
    } catch {}
    return {
      hrv,
      rhr,
      vo2,
      move,
      moveTarget,
      sleep,
      readiness,
      strain,
      energyBank,
      stressScore,
      sleepNeeded: bevel.sleepNeededHours || null,
      sleepDebt: bevel.sleepDebtHours ?? null,
      labsCount,
      mealsCount,
      nutritionScore,
      glucoseLatest,
      journalTagsToday,
      isSynced: hrv > 0 || move > 0 || Boolean(bevel.strain),
    };
  };

  const [messages, setMessages] = useState(() => {
    const firstName = getUserFirstName();
    const t = buildLiveTelemetrySummary();
    const initialText = t.isSynced
      ? `Hey ${firstName}! Your Apple Health sync is live: ${t.readiness != null ? `Readiness ${t.readiness}%, ` : ''}${t.hrv > 0 ? `HRV ${t.hrv}ms, ` : ''}${t.rhr > 0 ? `Resting HR ${t.rhr} bpm, ` : ''}${t.move} / ${t.moveTarget} kcal burned today. What would you like to analyze next?`
      : `Hey ${firstName}! Connect Apple Health (via iPhone APEX Companion or export.xml) or log your first Camera Workout, Meal, or Lab panel so I can give you real biometric coaching instead of guesses.`;
    return [{ role: 'assistant', text: initialText }];
  });

  const [inputPrompt, setInputPrompt] = useState('');
  const [isTyping, setIsTyping] = useState(false);

  const handlePersonaSwitch = (newPersona) => {
    playPlunk();
    setCoachPersona(newPersona);
    const t = buildLiveTelemetrySummary();
    const greeting =
      newPersona === 'buddy'
        ? t.isSynced
          ? `Switched to Buddy mode! Reading your live telemetry (HRV ${t.hrv || '—'}ms, Move ${t.move} kcal). What goal are we tackling today?`
          : `Switched to Buddy mode! Tap Connect Apple Health above whenever you want me to read your real HRV, sleep, and rings.`
        : t.isSynced
        ? `Switched to Nerd mode (Clinical Telemetry Synthesis). Active inputs: HRV ${t.hrv || '—'} ms, RHR ${t.rhr || '—'} bpm, VO2 Max ${t.vo2 || '—'}, Lab biomarkers: ${t.labsCount}.`
        : `Switched to Nerd mode (Clinical Synthesis). Waiting on Apple HealthKit sync or uploaded bloodwork to run quantitative inference.`;
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

      const t = buildLiveTelemetrySummary();
      let reply = '';
      const lower = prompt.toLowerCase();

      if (!t.isSynced && t.labsCount === 0 && t.mealsCount === 0 && !t.glucoseLatest) {
        reply = `No physiological streams are connected yet for "${prompt}". Connect Apple Health in the header, start a Face/Workout camera session, log Fuel/Glucose, or upload your bloodwork so I can reference your real numbers.`;
      } else if (lower.includes('morning briefing')) {
        const targetLow = t.readiness != null ? Math.max(4, Math.round(6 + (t.readiness / 100) * 8)) : '—';
        const targetHigh = typeof targetLow === 'number' ? Math.min(20, targetLow + 4) : '—';
        reply = `Morning Briefing: Recovery Readiness is ${t.readiness ?? '—'}%, Energy Bank at ${t.energyBank ?? '—'}% (HRV ${t.hrv || '—'} ms, RHR ${t.rhr || '—'} bpm). Adaptive Strain Target today is ${targetLow}–${targetHigh}. ${t.sleepNeeded ? `Tonight's sleep need: ${t.sleepNeeded.toFixed(1)}h.` : ''} Prioritize electrolytes & outdoor light before noon.`;
      } else if (lower.includes('evening wrap') || lower.includes('wrap-up')) {
        reply = `Evening Wrap-Up: Closed at Strain ${t.strain ?? '—'}/21 (${t.move} kcal), Intraday Stress ${t.stressScore ?? '—'}/100, Energy Bank ${t.energyBank ?? '—'}%. Meals logged: ${t.mealsCount}${t.nutritionScore ? ` (Quality ${t.nutritionScore}/100)` : ''}${t.glucoseLatest ? `, Glucose ${t.glucoseLatest} mg/dL` : ''}. Active Journal tags: ${t.journalTagsToday.length ? t.journalTagsToday.join(', ') : 'none yet'}. Target ${t.sleepNeeded ? `${t.sleepNeeded.toFixed(1)}h sleep` : 'consistent bedtime'} tonight.`;
      } else if (lower.includes('energy') || lower.includes('stress') || lower.includes('strain')) {
        reply = `Autonomic Status: Energy Bank ${t.energyBank ?? '—'}%, Stress ${t.stressScore ?? '—'}/100, Daily Strain ${t.strain ?? '—'}/21. ${t.energyBank != null && t.energyBank < 45 ? 'Metabolic reserve is dipping — favor restorative walking or a 20m NSDR reset.' : 'Reserve is healthy for focused training or deep cognitive work.'}`;
      } else if (coachPersona === 'buddy') {
        if (lower.includes('push') || lower.includes('workout') || lower.includes('exercise')) {
          reply = t.readiness != null
            ? `Your readiness is ${t.readiness}% (HRV ${t.hrv}ms, RHR ${t.rhr} bpm). ${t.readiness >= 75 ? 'Great green-light window for progressive overload in Camera Workout Tracker!' : 'Modulate volume today and focus on technical form + Zone 2 walking.'}`
            : `You have ${t.move} kcal logged today. Sync Apple Watch sleep/HRV for an autonomic push score, or open AI Camera Workout Tracker to measure real bar velocity.`;
        } else if (lower.includes('sleep') || lower.includes('tired')) {
          reply = t.sleep > 0
            ? `Last synced sleep duration was ${t.sleep} hours (HRV ${t.hrv || '—'}ms). Keep a consistent wake time and cap caffeine ~8 hours before bed.`
            : `Sleep hours haven't synced from Apple Health yet. Wear your Apple Watch overnight and sync from iPhone APEX Companion to inspect Deep & REM stages.`;
        } else {
          reply = `Current real telemetry: ${t.move}/${t.moveTarget} kcal move, ${t.hrv > 0 ? `HRV ${t.hrv}ms` : 'HRV unsynced'}, ${t.labsCount} lab biomarkers, and ${t.mealsCount} meals logged today.`;
        }
      } else {
        if (lower.includes('push') || lower.includes('workout') || lower.includes('exercise')) {
          reply = `Autonomic summary: Readiness ${t.readiness ?? 'N/A'}%, HRV SDNN ${t.hrv || '—'} ms, RHR ${t.rhr || '—'} bpm, VO2 Max ${t.vo2 || '—'} mL/kg/min. ${t.readiness >= 80 ? 'Sympathovagal balance supports high-threshold recruitment or Zone 5 intervals.' : 'Recommend Zone 2 mitochondrial work or recovery mobility.'}`;
        } else if (lower.includes('sleep') || lower.includes('tired')) {
          reply = t.sleep > 0
            ? `Synced sleep duration: ${t.sleep}h. Autonomic overnight HRV recorded at ${t.hrv || '—'} ms with RHR ${t.rhr || '—'} bpm.`
            : `No sleep stages present in current HealthKit packet. Pair Apple Watch sleep tracking and sync to evaluate N3/REM architecture.`;
        } else {
          reply = `Telemetry ledger for "${prompt}": Move ${t.move}/${t.moveTarget} kcal, HRV ${t.hrv || '—'} ms, RHR ${t.rhr || '—'} bpm, Clinical labs on file: ${t.labsCount}, Meals logged: ${t.mealsCount}.`;
        }
      }

      setMessages((prev) => [...prev, { role: 'assistant', text: reply }]);
    }, 350);
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
                  {buildLiveTelemetrySummary().isSynced ? 'LIVE TELEMETRY SYNCED' : 'AWAITING HEALTHKIT'}
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Reads synced Apple HealthKit, bloodwork & logged meals
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {!buildLiveTelemetrySummary().isSynced && onConnectHealth && (
              <button
                onClick={() => {
                  playPlunk();
                  onConnectHealth();
                }}
                className="px-3 py-1.5 rounded-[10px] bg-[#E5FE40] text-black text-[11px] font-mono font-black"
              >
                CONNECT HEALTH
              </button>
            )}
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

        {/* Quick Suggestion Chips + Bevel Briefings */}
        <div className="flex items-center space-x-2 pb-3 overflow-x-auto no-scrollbar text-[11px] font-mono text-[#A1A1AA]">
          <button
            onClick={() => handleSend('Give me my Morning Briefing')}
            className="px-2.5 py-1 rounded-full bg-[#E5FE40]/15 hover:bg-[#E5FE40]/25 text-[#E5FE40] border border-[#E5FE40]/40 font-bold shrink-0 transition"
          >
            Morning Briefing
          </button>
          <button
            onClick={() => handleSend('Give me my Evening Wrap-Up')}
            className="px-2.5 py-1 rounded-full bg-[#00F0FF]/15 hover:bg-[#00F0FF]/25 text-[#00F0FF] border border-[#00F0FF]/40 font-bold shrink-0 transition"
          >
            Evening Wrap-Up
          </button>
          <button
            onClick={() => handleSend('How is my Energy Bank, Stress & Strain?')}
            className="px-2.5 py-1 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 shrink-0 transition"
          >
            "Energy &amp; Stress?"
          </button>
          <button
            onClick={() => handleSend('Should I push today or recover?')}
            className="px-2.5 py-1 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 shrink-0 transition"
          >
            "Push or recover?"
          </button>
          <button
            onClick={() => handleSend('How was my sleep?')}
            className="px-2.5 py-1 rounded-full bg-white/5 hover:bg-white/10 border border-white/10 shrink-0 transition"
          >
            "How was my sleep?"
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
