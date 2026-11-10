import React, { useState } from 'react';
import {
  Camera,
  Scan,
  Sparkles,
  CheckCircle,
  Plus,
  Flame,
  TrendingUp,
  ShieldCheck,
  RefreshCw
} from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function MealScanner() {
  const [isScanning, setIsScanning] = useState(false);
  const [mealLogged, setMealLogged] = useState(false);

  const handleScan = () => {
    playPlunk();
    setIsScanning(true);
    setMealLogged(false);
    setTimeout(() => {
      setIsScanning(false);
      playCoinChime();
    }, 1200);
  };

  const handleLogMeal = () => {
    playPlunk();
    playCoinChime();
    setMealLogged(true);
    try {
      confetti({
        particleCount: 50,
        spread: 60,
        colors: ['#00F0FF', '#E5FE40', '#10B981'],
      });
    } catch {}
  };

  return (
    <div className="space-y-6">
      {/* AI COMPUTER VISION VIEWFINDER */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 relative overflow-hidden">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-2.5">
            <div className="w-10 h-10 rounded-[12px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 flex items-center justify-center">
              <Camera className="w-5 h-5 text-[#00F0FF]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">AI Vision Macro Scanner</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  ON-DEVICE VISION
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                MobileNetV4 (<code className="text-[#00F0FF]">food_macro_vision.onnx</code> 37MB) · On-Device Nutrition Inference
              </span>
            </div>
          </div>

          <button
            onClick={handleScan}
            disabled={isScanning}
            className="px-3.5 py-1.5 rounded-[12px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center space-x-1.5"
          >
            <Scan className={`w-3.5 h-3.5 ${isScanning ? 'animate-spin' : ''}`} />
            <span>{isScanning ? 'ANALYZING...' : 'SCAN MEAL'}</span>
          </button>
        </div>

        {/* Viewfinder Graphic */}
        <div className="relative h-64 rounded-[20px] bg-gradient-to-b from-black/80 to-[#0B0E14] border border-white/15 flex flex-col justify-between p-4 overflow-hidden">
          {/* Scanning Beam */}
          {isScanning && (
            <div className="absolute inset-x-0 h-1 bg-[#00F0FF] shadow-[0_0_15px_#00F0FF] animate-bounce" />
          )}

          {/* Top Camera HUD */}
          <div className="flex items-center justify-between text-[10px] font-mono text-white/70">
            <span>ISO 100 · 4K 60FPS</span>
            <span className="text-[#00F0FF] font-bold">DETECTED 3 INGREDIENTS (99.4% CONFIDENCE)</span>
          </div>

          {/* Food Bounding Boxes */}
          <div className="space-y-2">
            <div className="inline-block p-2 rounded-[10px] bg-black/70 border border-[#E5FE40]/60 text-xs font-mono backdrop-blur-md">
              <span className="text-[#E5FE40] font-black block">🥩 GRASS-FED RIBEYE (240g)</span>
              <span className="text-[10px] text-white">64g Protein · 28g Fats · 508 kcal</span>
            </div>
            <br />
            <div className="inline-block p-2 rounded-[10px] bg-black/70 border border-[#00F0FF]/60 text-xs font-mono backdrop-blur-md">
              <span className="text-[#00F0FF] font-black block">🍠 ROASTED SWEET POTATO (180g)</span>
              <span className="text-[10px] text-white">42g Clean Carbs · 3.5g Protein · 186 kcal</span>
            </div>
          </div>

          {/* Bottom HUD */}
          <div className="flex items-center justify-between text-xs font-mono">
            <span className="text-white font-bold">TOTAL: 800 KCAL</span>
            <span className="text-[#10B981] font-black">68.7g PROTEIN · 47g CARBS · 37g FATS</span>
          </div>
        </div>

        {/* Log Button */}
        <button
          onClick={handleLogMeal}
          disabled={mealLogged}
          className="w-full mt-4 py-3.5 rounded-[14px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center justify-center space-x-2"
        >
          <CheckCircle className="w-4 h-4" />
          <span>{mealLogged ? 'MEAL LOGGED TO APPLE HEALTH' : 'LOG 800 KCAL MEAL TO HEALTHKIT'}</span>
        </button>
      </div>

      {/* DYNAMIC EXPENDITURE (MACROFACTOR ENGINE) */}
      <div className="liquid-glass rounded-[22px] p-5 border border-white/10 flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 rounded-[12px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
            <TrendingUp className="w-5 h-5 text-[#10B981]" />
          </div>
          <div>
            <span className="text-[10px] font-mono text-[#10B981] font-black uppercase">
              DYNAMIC ENERGY EXPENDITURE (TDEE)
            </span>
            <div className="flex items-baseline space-x-2">
              <span className="text-2xl font-mono font-black text-white">2,840 kcal / day</span>
              <span className="text-xs font-mono text-[#10B981] font-bold">+180 kcal metabolic rate</span>
            </div>
            <p className="text-[10px] text-[#A1A1AA]">
              Calculated via expenditure algorithm factoring activity strain & thermic effect
            </p>
          </div>
        </div>

        <span className="text-xs font-mono px-3 py-1.5 rounded bg-black/60 text-[#E5FE40] border border-white/10 font-bold">
          SURPLUS +240 kcal
        </span>
      </div>
    </div>
  );
}
