import React, { useState } from 'react';
import { Bot, Send, Sparkles, User, Zap, ShieldCheck, RefreshCw } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';

const INITIAL_MESSAGES = [
  {
    role: 'assistant',
    text: 'Greetings, Alexander. I am your APEX AI Consigliere, calibrated to the clinical methodologies of Peter Attia, Bryan Johnson, and Andrew Huberman. Your biological age is currently 22.8y (-6.2y reversed) and your morning autonomic recovery is at 94% (HRV 94ms). How shall we optimize your biology today?',
  },
];

export default function AIConsigliere() {
  const [messages, setMessages] = useState(INITIAL_MESSAGES);
  const [inputPrompt, setInputPrompt] = useState('');
  const [isTyping, setIsTyping] = useState(false);

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
      if (lower.includes('hrv') || lower.includes('recovery')) {
        reply =
          'Your overnight HRV of 94ms indicates high vagal nerve parasympathetic dominance. Last night’s mouth taping and 144mg Magnesium L-Threonate prevented micro-arousals. You are in an optimal neuro-muscular window for maximum strain: aim for 18.0 Day Strain with heavy overhead pressing and Zone 2 flush.';
      } else if (lower.includes('glucose') || lower.includes('sugar') || lower.includes('cgm')) {
        reply =
          'With your baseline fasting glucose at 82 mg/dL, take 1 tbsp Apple Cider Vinegar diluted in 250ml water 10 minutes prior to complex carbohydrates. Following your meal, a 12-minute brisk walk activates non-insulin-mediated GLUT4 translocation in your soleus muscle, flattening glycemic excursions by 34%.';
      } else if (lower.includes('phenoage') || lower.includes('longevity') || lower.includes('age')) {
        reply =
          'Your PhenoAge is calculated at 22.8 years versus your 29.0 chronological age. To push your pace of aging below 0.70x/yr, focus on keeping your hs-CRP below 0.25 mg/L via daily omega-3 (2,400mg EPA/DHA) and maintaining your ApoB below 55 mg/dL to prevent any atherogenic subendothelial retention.';
      } else {
        reply = `Prescription locked for: "${prompt}". Based on your blood chemistry and genetic profile, sustain 15 minutes of direct solar lux, 3 minutes in the 4°C cold plunge for RBM3 cold shock induction, and maintain your 40Hz binaural flow state during deep equity-building sprints.`;
      }

      setMessages((prev) => [...prev, { role: 'assistant', text: reply }]);
    }, 900);
  };

  return (
    <div className="space-y-4">
      {/* CHAT CONTAINER */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 flex flex-col h-[520px] justify-between">
        {/* Top Header */}
        <div className="flex items-center justify-between pb-3 border-b border-white/10 shrink-0">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center">
              <Bot className="w-5 h-5 text-[#E5FE40]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">APEX AI Consigliere</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-bold">
                  ON-DEVICE NEURAL MODEL
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Trained on 40,000+ clinical longevity & biomechanics papers
              </span>
            </div>
          </div>

          <span className="text-xs font-mono text-[#00F0FF] font-bold">ATTIA & BLUEPRINT ENGINE</span>
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
            <div className="flex items-center space-x-2 text-xs font-mono text-[#8A8A8A] pl-1">
              <span className="w-1.5 h-1.5 rounded-full bg-[#E5FE40] animate-bounce" />
              <span className="w-1.5 h-1.5 rounded-full bg-[#E5FE40] animate-bounce [animation-delay:0.2s]" />
              <span className="w-1.5 h-1.5 rounded-full bg-[#E5FE40] animate-bounce [animation-delay:0.4s]" />
              <span>Synthesizing clinical protocol...</span>
            </div>
          )}
        </div>

        {/* Quick Prompts */}
        <div className="flex items-center space-x-2 overflow-x-auto no-scrollbar py-2 border-t border-white/10 shrink-0">
          {[
            'Why is my HRV 94ms today?',
            'Optimize my post-workout meal',
            'How to suppress postprandial glucose spike?',
            'Prescribe my PhenoAge reduction stack',
          ].map((prompt, idx) => (
            <button
              key={idx}
              onClick={() => handleSend(prompt)}
              className="px-3 py-1 rounded-[10px] bg-white/[0.04] hover:bg-white/[0.08] text-[10px] font-mono text-white/80 whitespace-nowrap border border-white/10 transition shrink-0"
            >
              {prompt}
            </button>
          ))}
        </div>

        {/* Text Input */}
        <div className="flex items-center space-x-2 pt-2 shrink-0">
          <input
            type="text"
            value={inputPrompt}
            onChange={(e) => setInputPrompt(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
            placeholder="Ask your longevity consigliere..."
            className="flex-1 bg-black/60 border border-white/15 rounded-[14px] px-4 py-3 text-xs font-mono text-white placeholder-[#8A8A8A] focus:outline-none focus:border-[#E5FE40]"
          />
          <button
            onClick={() => handleSend()}
            className="p-3 rounded-[14px] cred-plunk-primary text-black"
          >
            <Send className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
