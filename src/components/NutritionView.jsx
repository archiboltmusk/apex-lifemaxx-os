import React, { useState } from 'react';
import { Plus, Check, Droplets, Pill, Flame, Sparkles } from 'lucide-react';
import { NUTRITION_MACRO_DATA } from '../utils/lifemaxxData';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function NutritionView() {
  const [supps, setSupps] = useState(NUTRITION_MACRO_DATA.supplements);
  const [water, setWater] = useState(NUTRITION_MACRO_DATA.water.current);
  const { calories, protein, carbs, fats } = NUTRITION_MACRO_DATA;

  const toggleSupp = (name) => {
    playPlunk();
    setSupps((prev) =>
      prev.map((s) => {
        if (s.name === name) {
          const next = !s.taken;
          if (next) {
            playCoinChime();
          }
          return { ...s, taken: next };
        }
        return s;
      })
    );
  };

  const addWater = () => {
    playPlunk();
    setWater((w) => {
      const next = Math.min(6.0, +(w + 0.25).toFixed(2));
      if (next >= 4.0 && w < 4.0) {
        try {
          confetti({
            particleCount: 50,
            spread: 50,
            colors: ['#00D6E6', '#00F0FF', '#FFFFFF']
          });
        } catch {}
      }
      return next;
    });
  };

  return (
    <div className="space-y-6">
      {/* MACRO OVERVIEW */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="liquid-glass rounded-[20px] p-4 border border-white/10">
          <span className="text-[10px] font-mono text-[#FA114F] uppercase font-black">CALORIES</span>
          <div className="flex items-baseline space-x-1 mt-1">
            <span className="text-2xl font-mono font-black text-white">{calories.current}</span>
            <span className="text-xs font-mono text-[#8A8A8A]">/ {calories.target}</span>
          </div>
          <div className="w-full h-1.5 bg-black/50 rounded-full mt-3 overflow-hidden">
            <div className="h-full bg-[#FA114F] rounded-full" style={{ width: `${(calories.current / calories.target) * 100}%` }} />
          </div>
        </div>

        <div className="liquid-glass rounded-[20px] p-4 border border-white/10">
          <span className="text-[10px] font-mono text-[#00F0FF] uppercase font-black">PROTEIN (ANABOLIC)</span>
          <div className="flex items-baseline space-x-1 mt-1">
            <span className="text-2xl font-mono font-black text-white">{protein.current}g</span>
            <span className="text-xs font-mono text-[#8A8A8A]">/ {protein.target}g</span>
          </div>
          <div className="w-full h-1.5 bg-black/50 rounded-full mt-3 overflow-hidden">
            <div className="h-full bg-[#00F0FF] rounded-full" style={{ width: `${(protein.current / protein.target) * 100}%` }} />
          </div>
        </div>

        <div className="liquid-glass rounded-[20px] p-4 border border-white/10">
          <span className="text-[10px] font-mono text-[#E5FE40] uppercase font-black">GLYCOGEN CARBS</span>
          <div className="flex items-baseline space-x-1 mt-1">
            <span className="text-2xl font-mono font-black text-white">{carbs.current}g</span>
            <span className="text-xs font-mono text-[#8A8A8A]">/ {carbs.target}g</span>
          </div>
          <div className="w-full h-1.5 bg-black/50 rounded-full mt-3 overflow-hidden">
            <div className="h-full bg-[#E5FE40] rounded-full" style={{ width: `${(carbs.current / carbs.target) * 100}%` }} />
          </div>
        </div>

        <div className="liquid-glass rounded-[20px] p-4 border border-white/10">
          <span className="text-[10px] font-mono text-[#10B981] uppercase font-black">CELLULAR FATS</span>
          <div className="flex items-baseline space-x-1 mt-1">
            <span className="text-2xl font-mono font-black text-white">{fats.current}g</span>
            <span className="text-xs font-mono text-[#8A8A8A]">/ {fats.target}g</span>
          </div>
          <div className="w-full h-1.5 bg-black/50 rounded-full mt-3 overflow-hidden">
            <div className="h-full bg-[#10B981] rounded-full" style={{ width: `${(fats.current / fats.target) * 100}%` }} />
          </div>
        </div>
      </div>

      {/* HYDRATION WIDGET */}
      <div className="liquid-glass rounded-[22px] p-5 border border-white/10 flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <div className="w-12 h-12 rounded-[16px] bg-[#00D6E6]/20 border border-[#00D6E6]/40 flex items-center justify-center">
            <Droplets className="w-6 h-6 text-[#00D6E6]" />
          </div>
          <div>
            <span className="text-[10px] font-mono text-[#00D6E6] font-black uppercase tracking-wider">
              CELLULAR HYDRATION & SALTS
            </span>
            <div className="flex items-baseline space-x-2">
              <span className="text-2xl font-mono font-black text-white">{water} L</span>
              <span className="text-xs font-mono text-[#8A8A8A]">/ 4.0 L Goal</span>
            </div>
            <p className="text-[11px] text-[#A1A1AA]">Optimized with Redmond real salt + Magnesium ions</p>
          </div>
        </div>

        <button
          onClick={addWater}
          className="px-4 py-2 rounded-[12px] cred-plunk-dark text-xs font-mono font-bold flex items-center space-x-1.5 border border-[#00D6E6]/40"
        >
          <Plus className="w-3.5 h-3.5 text-[#00D6E6]" />
          <span>+250ml SIP</span>
        </button>
      </div>

      {/* LONGEVITY SUPPLEMENT DISPENSARY */}
      <div className="liquid-glass rounded-[22px] p-5 border border-white/10">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-2">
            <Pill className="w-4 h-4 text-[#8B5CF6]" />
            <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
              BRYAN JOHNSON BLUEPRINT SUPPLEMENT DISPENSARY
            </h4>
          </div>
          <span className="text-xs font-mono text-[#E5FE40] font-black">
            {supps.filter((s) => s.taken).length} / {supps.length} CONSUMED
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5">
          {supps.map((supp, idx) => (
            <div
              key={idx}
              onClick={() => toggleSupp(supp.name)}
              className={`p-3 rounded-[14px] border transition cursor-pointer flex items-center justify-between ${
                supp.taken
                  ? 'bg-white/[0.03] border-white/10 opacity-70'
                  : 'bg-white/[0.08] border-white/20 hover:border-white/40'
              }`}
            >
              <div className="flex items-center space-x-3">
                <div
                  className={`w-6 h-6 rounded-lg flex items-center justify-center border ${
                    supp.taken
                      ? 'bg-[#10B981] border-[#10B981] text-black font-bold'
                      : 'border-white/30 bg-black/40'
                  }`}
                >
                  {supp.taken && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                </div>
                <div>
                  <span className={`text-xs font-mono font-bold block ${supp.taken ? 'line-through text-[#8A8A8A]' : 'text-white'}`}>
                    {supp.name}
                  </span>
                  <span className="text-[10px] font-mono text-[#A1A1AA]">
                    {supp.dose} · {supp.timing}
                  </span>
                </div>
              </div>

              <span className="text-[9px] font-mono font-black px-1.5 py-0.5 rounded bg-black/50 text-[#8B5CF6] border border-white/10">
                {supp.timing}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
