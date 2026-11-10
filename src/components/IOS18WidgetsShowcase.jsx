import React, { useState } from 'react';
import { Smartphone, Watch, Zap, Sparkles, Sliders, Bell, LayoutGrid, Check } from 'lucide-react';
import { playPlunk } from '../utils/audioSynth';

export default function IOS18WidgetsShowcase() {
  const [actionButtonSetting, setActionButtonSetting] = useState('flow');

  return (
    <div className="space-y-6">
      {/* ACTION BUTTON CONFIGURATOR */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center">
              <Zap className="w-5 h-5 text-[#E5FE40]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">iPhone 16 Pro Action Button Integration</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#E5FE40]/20 text-[#E5FE40] border border-[#E5FE40]/40 font-black">
                  HARDWARE KEY
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                1-Press physical trigger mapped to your highest-leverage protocol
              </span>
            </div>
          </div>
          <span className="text-xs font-mono text-[#10B981] font-bold">MAPPED</span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
          {[
            { id: 'flow', label: 'Start 40Hz Flow Block', desc: 'Instantly initiates 25m sprint with binaural audio', tag: 'NEURAL' },
            { id: 'mewing', label: 'Trigger Mewing Check', desc: 'Starts palatal suction posture timer', tag: 'AESTHETIC' },
            { id: 'plunge', label: 'Log Cryo Plunge', desc: 'Auto-logs 3m 4°C cold plunge to Apple Health', tag: 'LONGEVITY' },
          ].map((act) => (
            <div
              key={act.id}
              onClick={() => {
                playPlunk();
                setActionButtonSetting(act.id);
              }}
              className={`p-3.5 rounded-[16px] border transition cursor-pointer ${
                actionButtonSetting === act.id
                  ? 'bg-[#E5FE40]/15 border-[#E5FE40] text-white shadow-[0_0_12px_rgba(229,254,64,0.3)]'
                  : 'bg-black/40 border-white/10 text-[#8A8A8A] hover:border-white/25'
              }`}
            >
              <span className="text-[10px] font-mono font-black text-[#E5FE40] uppercase block">
                {act.tag}
              </span>
              <h4 className="text-xs font-bold text-white mt-0.5">{act.label}</h4>
              <p className="text-[10px] text-[#A1A1AA] mt-1">{act.desc}</p>
            </div>
          ))}
        </div>
      </div>

      {/* APPLE WATCH MODULAR ULTRA & LOCK SCREEN LIVE ACTIVITY */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Apple Watch Modular Face */}
        <div className="liquid-glass rounded-[24px] p-5 border border-white/10 space-y-3">
          <div className="flex items-center space-x-2">
            <Watch className="w-4 h-4 text-[#FA114F]" />
            <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
              APPLE WATCH ULTRA MODULAR FACE (watchOS 11)
            </h4>
          </div>

          <div className="p-4 rounded-[18px] bg-black/80 border border-white/15 flex flex-col justify-between h-40">
            <div className="flex items-center justify-between font-mono text-xs">
              <span className="text-[#FA114F] font-bold">APEX RECOVERY: 94%</span>
              <span className="text-white font-bold">09:41</span>
            </div>
            <div className="text-center">
              <span className="text-3xl font-mono font-black text-white">40Hz FLOW</span>
              <span className="text-[10px] font-mono text-[#00F0FF] block">BINAURAL AUDIO ACTIVE</span>
            </div>
            <div className="flex items-center justify-between font-mono text-[10px] text-[#8A8A8A]">
              <span>RHR: 48 BPM</span>
              <span>STRAIN: 16.8</span>
              <span>BIO: 22.8y</span>
            </div>
          </div>
        </div>

        {/* Lock Screen Live Activity */}
        <div className="liquid-glass rounded-[24px] p-5 border border-white/10 space-y-3">
          <div className="flex items-center space-x-2">
            <Smartphone className="w-4 h-4 text-[#00F0FF]" />
            <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
              iOS 18 LOCK SCREEN LIVE ACTIVITY
            </h4>
          </div>

          <div className="p-4 rounded-[18px] bg-black/80 border border-white/15 flex flex-col justify-between h-40">
            <div className="flex items-center justify-between text-xs font-mono">
              <span className="text-white font-bold flex items-center space-x-1.5">
                <span className="w-2 h-2 rounded-full bg-[#10B981] animate-ping" />
                <span>MEWING SUCTION ACTIVE</span>
              </span>
              <span className="text-[#E5FE40] font-black">+80 XP</span>
            </div>
            <div className="text-center">
              <span className="text-2xl font-mono font-black text-white">04:22 ELAPSED</span>
              <span className="text-[10px] font-mono text-[#A1A1AA] block">Palatal Suction Seal: Optimal</span>
            </div>
            <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
              <div className="h-full bg-[#00F0FF] rounded-full w-2/3" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
