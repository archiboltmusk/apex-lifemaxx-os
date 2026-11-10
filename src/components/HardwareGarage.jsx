import React from 'react';
import { Watch, Disc, Activity, Zap, Moon, Check, ChevronRight, Battery, Wifi } from 'lucide-react';
import { HARDWARE_GARAGE } from '../utils/lifemaxxData';
import { playPlunk } from '../utils/audioSynth';

export default function HardwareGarage({ onDeviceSelect }) {
  const getIcon = (iconName) => {
    switch (iconName) {
      case 'Watch': return Watch;
      case 'Disc': return Disc;
      case 'Activity': return Activity;
      case 'Zap': return Zap;
      case 'Moon': return Moon;
      default: return Activity;
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-widest">
            BIOMETRIC TELEMETRY
          </span>
          <h3 className="text-base font-bold text-white tracking-tight">Connected Hardware Garage</h3>
        </div>
        <span className="text-[10px] font-mono px-2.5 py-1 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/30">
          5 / 5 CONNECTED
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {HARDWARE_GARAGE.map((device) => {
          const Icon = getIcon(device.icon);
          return (
            <div
              key={device.id}
              onClick={() => {
                playPlunk();
                if (onDeviceSelect) onDeviceSelect(device);
              }}
              className="liquid-glass rounded-[18px] p-4 border border-white/10 hover:border-white/25 transition cursor-pointer relative group"
            >
              <div className="flex items-start justify-between">
                <div className="flex items-center space-x-3">
                  <div
                    className="w-10 h-10 rounded-[12px] flex items-center justify-center border border-white/10"
                    style={{ backgroundColor: `${device.accent}20` }}
                  >
                    <Icon className="w-5 h-5" style={{ color: device.accent }} />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-white tracking-tight">{device.name}</h4>
                    <span className="text-[11px] font-mono text-[#8A8A8A] block">{device.model}</span>
                  </div>
                </div>
                <div className="flex items-center space-x-1.5 px-2 py-0.5 rounded bg-black/40 border border-white/10">
                  <Battery className="w-3.5 h-3.5 text-[#10B981]" />
                  <span className="text-[10px] font-mono font-bold text-white">{device.battery}</span>
                </div>
              </div>

              <div className="mt-3 pt-2.5 border-t border-white/5 flex items-center justify-between text-xs font-mono">
                <div className="flex items-center space-x-1.5 text-[#A1A1AA]">
                  <Wifi className="w-3 h-3 text-[#00F0FF]" />
                  <span className="text-[10px]">{device.signal}</span>
                </div>
                <span className="text-[10px] font-bold text-[#10B981] group-hover:translate-x-0.5 transition flex items-center space-x-1">
                  <span>{device.status}</span>
                  <ChevronRight className="w-3 h-3" />
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
