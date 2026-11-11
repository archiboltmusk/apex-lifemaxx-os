import React, { useState, useEffect } from 'react';
import { Plus, Check, Droplets, Pill } from 'lucide-react';
import { NUTRITION_MACRO_DATA } from '../utils/lifemaxxData';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const loadLoggedMeals = () => {
  try {
    return JSON.parse(localStorage.getItem('apex_logged_meals') || '[]');
  } catch {
    return [];
  }
};

export default function NutritionView({ onOpenScanner }) {
  const [supps, setSupps] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_supplements_state');
      if (saved) return JSON.parse(saved);
    } catch {}
    return NUTRITION_MACRO_DATA.supplements.map((s) => ({ ...s, taken: false }));
  });
  const [water, setWater] = useState(() => {
    try {
      return Number(localStorage.getItem('apex_water_liters') || '0');
    } catch {
      return 0;
    }
  });
  const [meals, setMeals] = useState(loadLoggedMeals);
  const [iosSummary, setIosSummary] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('apex_ios_nutrition_summary') || 'null');
    } catch {
      return null;
    }
  });

  useEffect(() => {
    const refreshMeals = () => {
      setMeals(loadLoggedMeals());
      try {
        setIosSummary(JSON.parse(localStorage.getItem('apex_ios_nutrition_summary') || 'null'));
      } catch {}
    };
    window.addEventListener('storage', refreshMeals);
    window.addEventListener('apex:meals-updated', refreshMeals);
    return () => {
      window.removeEventListener('storage', refreshMeals);
      window.removeEventListener('apex:meals-updated', refreshMeals);
    };
  }, []);

  const totals = meals.reduce(
    (acc, m) => {
      acc.calories += Number(m.calories) || 0;
      acc.protein += Number(m.protein) || 0;
      acc.carbs += Number(m.carbs) || 0;
      acc.fats += Number(m.fat ?? m.fats) || 0;
      acc.fiber += Number(m.fiber) || 0;
      acc.sugar += Number(m.sugar) || 0;
      return acc;
    },
    { calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, sugar: 0 }
  );

  const effectiveCalories = totals.calories || iosSummary?.calories || 0;
  const effectiveProtein = totals.protein || iosSummary?.protein || 0;
  const effectiveCarbs = totals.carbs || iosSummary?.carbs || 0;
  const effectiveFats = totals.fats || iosSummary?.fat || 0;
  const effectiveFiber = totals.fiber || iosSummary?.fiber || 0;
  const effectiveSugar = totals.sugar || iosSummary?.sugar || 0;

  const nutritionQualityScore = (() => {
    if (meals.length === 0 && !iosSummary?.qualityScore) return null;
    if (iosSummary?.qualityScore && meals.length === 0) return iosSummary.qualityScore;
    const calRatio = Math.min(1.2, effectiveCalories / Math.max(1000, NUTRITION_MACRO_DATA.calories.target));
    const proteinRatio = Math.min(1.0, effectiveProtein / Math.max(60, NUTRITION_MACRO_DATA.protein.target));
    const fiberRatio = Math.min(1.0, effectiveFiber / 32);
    const sugarPenalty = Math.max(0, (effectiveSugar - 38) * 0.45);
    const wholeRatio = meals.filter((m) => (m.fiber || 0) >= 3 && (m.sugar || 0) < 12).length / Math.max(1, meals.length);
    const raw = 28 + proteinRatio * 34 + fiberRatio * 18 + wholeRatio * 15 + (calRatio >= 0.7 && calRatio <= 1.15 ? 5 : 0) - sugarPenalty;
    return Math.round(Math.max(12, Math.min(100, raw)));
  })();

  const calories = { current: effectiveCalories, target: NUTRITION_MACRO_DATA.calories.target };
  const protein = { current: effectiveProtein, target: NUTRITION_MACRO_DATA.protein.target };
  const carbs = { current: effectiveCarbs, target: NUTRITION_MACRO_DATA.carbs.target };
  const fats = { current: effectiveFats, target: NUTRITION_MACRO_DATA.fats.target };

  const toggleSupp = (name) => {
    playPlunk();
    setSupps((prev) => {
      const nextList = prev.map((s) => {
        if (s.name === name) {
          const next = !s.taken;
          if (next) {
            playCoinChime();
          }
          return { ...s, taken: next };
        }
        return s;
      });
      try {
        localStorage.setItem('apex_supplements_state', JSON.stringify(nextList));
      } catch {}
      return nextList;
    });
  };

  const addWater = () => {
    playPlunk();
    setWater((w) => {
      const next = Math.min(6.0, +(w + 0.25).toFixed(2));
      try {
        localStorage.setItem('apex_water_liters', String(next));
      } catch {}
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
      {meals.length === 0 && (
        <div className="liquid-glass rounded-[18px] p-4 border border-[#00D6E6]/30 flex flex-wrap items-center justify-between gap-3 font-mono text-xs">
          <div>
            <span className="text-[#00D6E6] font-black block">NO MEALS LOGGED TODAY</span>
            <span className="text-[#A1A1AA]">Totals start at 0 until you scan or log real meals.</span>
          </div>
          {onOpenScanner && (
            <button
              onClick={() => {
                playPlunk();
                onOpenScanner();
              }}
              className="px-3.5 py-2 rounded-[10px] bg-[#00D6E6] text-black font-black"
            >
              OPEN MEAL SCANNER
            </button>
          )}
        </div>
      )}
      {/* BEVEL NUTRITION QUALITY SCORE + FIBER / SUGAR */}
      <div className="liquid-glass-elevated rounded-[22px] p-5 border border-white/15 flex flex-wrap items-center justify-between gap-4">
        <div>
          <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-wider">
            BEVEL NUTRITION QUALITY SCORE
          </span>
          <div className="flex items-baseline space-x-2 mt-1">
            <span className="text-3xl font-mono font-black text-white">
              {nutritionQualityScore != null ? `${nutritionQualityScore}/100` : '—'}
            </span>
            <span className="text-xs font-mono text-[#A1A1AA]">
              {nutritionQualityScore != null
                ? 'Protein density · Fiber · Glycemic & Sugar control'
                : 'Log a meal in Scanner or iPhone Fuel to score diet quality'}
            </span>
          </div>
        </div>
        <div className="flex items-center space-x-3 font-mono text-xs">
          <div className="px-3 py-1.5 rounded-xl bg-black/40 border border-white/10">
            <span className="text-[#8A8A8A] block text-[9px]">FIBER</span>
            <strong className="text-[#10B981]">{effectiveFiber}g / 32g</strong>
          </div>
          <div className="px-3 py-1.5 rounded-xl bg-black/40 border border-white/10">
            <span className="text-[#8A8A8A] block text-[9px]">SUGAR</span>
            <strong className={effectiveSugar > 38 ? 'text-[#FA114F]' : 'text-[#00F0FF]'}>{effectiveSugar}g</strong>
          </div>
        </div>
      </div>

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
