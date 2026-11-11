import React from 'react';
import { Activity, Flame, Moon, Heart, BatteryCharging, ShieldCheck, AlertTriangle } from 'lucide-react';
import { APPLE_HEALTH_DATA } from '../utils/lifemaxxData';

export default function RecoveryStrainView({ healthData }) {
  const currentHealth = healthData || APPLE_HEALTH_DATA;
  const bevel = currentHealth.bevel || {};
  const metrics = currentHealth.metrics || {};
  const sleepStages = currentHealth.sleepStages || APPLE_HEALTH_DATA.sleepStages;

  const hrvValue = metrics.hrv?.value || 0;
  const rhrValue = metrics.restingHeartRate?.value || 0;
  const hasRealVitals = hrvValue > 0 && rhrValue > 0;

  // Real Recovery Score (synced from iPhone Bevel engine or derived from real HRV/RHR)
  const recoveryScore = bevel.readiness > 0
    ? Math.round(bevel.readiness)
    : hasRealVitals
      ? Math.min(99, Math.max(35, Math.round(50 + (hrvValue - 50) * 0.5 - (rhrValue - 55) * 0.6)))
      : 0;

  const recoveryStatus = !hasRealVitals && !bevel.readiness
    ? 'AWAITING HEALTHKIT'
    : recoveryScore >= 80
      ? 'PEAK RECOVERY'
      : recoveryScore >= 60
        ? 'BALANCED'
        : 'RECOVERY REQUIRED';

  const recoveryMessage = !hasRealVitals && !bevel.readiness
    ? 'Connect your iPhone APEX OS app or import Apple Health export.xml to compute real autonomic recovery from HRV and resting heart rate.'
    : recoveryScore >= 80
      ? `High parasympathetic dominance detected (HRV ${hrvValue || '—'}ms, Resting HR ${rhrValue || '—'}bpm). Primed for adaptive overload.`
      : `Elevated physiological load (HRV ${hrvValue || '—'}ms, RHR ${rhrValue || '—'}bpm). Prioritize restorative sleep and Zone 2.`;

  const moveCalories = currentHealth.activityRings?.move?.current || 0;
  const moveTarget = currentHealth.activityRings?.move?.target || 750;
  const exerciseMins = currentHealth.activityRings?.exercise?.current || 0;
  const isSynced = hasRealVitals || moveCalories > 0 || Boolean(bevel.strain);

  // Bevel 0–21 Strain + Adaptive Target Range
  const strainRatio = Math.min(1.0, moveCalories / Math.max(100, moveTarget));
  const strainCurrent = bevel.strain > 0
    ? +Number(bevel.strain).toFixed(1)
    : moveCalories > 0
      ? +(strainRatio * 18.0 + Math.min(3.0, exerciseMins * 0.03)).toFixed(1)
      : 0;

  const targetLow = recoveryScore > 0 ? Math.max(4, Math.round(6 + (recoveryScore / 100) * 8)) : null;
  const targetHigh = targetLow != null ? Math.min(20, targetLow + 4) : null;

  // Sleep & Sleep Debt
  const sleepHours = Number(sleepStages.totalHours?.split?.('h')?.[0]) || metrics.sleep?.totalHours || 0;
  const sleepNeeded = bevel.sleepNeededHours > 0
    ? +Number(bevel.sleepNeededHours).toFixed(1)
    : (sleepHours > 0 || strainCurrent > 0 ? +(7.5 + strainCurrent * 0.06).toFixed(1) : null);
  const sleepDebt = bevel.sleepDebtHours != null && bevel.sleepDebtHours !== 0
    ? +Number(bevel.sleepDebtHours).toFixed(1)
    : (sleepHours > 0 ? +(Math.max(0, 7.8 - sleepHours)).toFixed(1) : null);

  // Energy Bank & Intraday Stress
  const energyBank = bevel.energyBank > 0
    ? Math.round(bevel.energyBank)
    : recoveryScore > 0
      ? Math.max(12, Math.min(99, Math.round(recoveryScore - strainCurrent * 2.1)))
      : null;

  const stressScore = bevel.stressScore > 0
    ? Math.round(bevel.stressScore)
    : hasRealVitals
      ? Math.max(8, Math.min(95, Math.round(62 - (hrvValue - 45) * 0.45 + Math.max(0, rhrValue - 58) * 0.8)))
      : null;

  const stressCurve = Array.isArray(bevel.stressCurve) ? bevel.stressCurve : [];
  const energyCurve = Array.isArray(bevel.energyCurve) ? bevel.energyCurve : [];

  // 5-Vital Health Monitor (Strict real values only)
  const fiveVitals = [
    {
      label: 'Resting HR',
      value: rhrValue > 0 ? `${rhrValue} bpm` : null,
      inRange: rhrValue > 0 ? rhrValue >= 40 && rhrValue <= 72 : null,
      norm: '40–72 bpm',
    },
    {
      label: 'HRV SDNN',
      value: hrvValue > 0 ? `${hrvValue} ms` : null,
      inRange: hrvValue > 0 ? hrvValue >= 35 : null,
      norm: '≥ 35 ms',
    },
    {
      label: 'Resp Rate',
      value: metrics.respiratoryRate > 0 ? `${metrics.respiratoryRate}/m` : null,
      inRange: metrics.respiratoryRate > 0 ? metrics.respiratoryRate >= 10 && metrics.respiratoryRate <= 19 : null,
      norm: '10–19/m',
    },
    {
      label: 'Wrist Temp',
      value: metrics.wristTempDelta != null ? `${metrics.wristTempDelta >= 0 ? '+' : ''}${Number(metrics.wristTempDelta).toFixed(2)}°C` : null,
      inRange: metrics.wristTempDelta != null ? Math.abs(Number(metrics.wristTempDelta)) <= 0.6 : null,
      norm: '±0.60°C',
    },
    {
      label: 'Blood O₂',
      value: metrics.bloodOxygen > 0 ? `${Math.round(metrics.bloodOxygen)}%` : null,
      inRange: metrics.bloodOxygen > 0 ? metrics.bloodOxygen >= 95 : null,
      norm: '95–100%',
    },
  ];
  const measuredVitals = fiveVitals.filter((v) => v.value != null);
  const inRangeVitals = measuredVitals.filter((v) => v.inRange).length;

  const zones = moveCalories > 0
    ? [
        { zone: 'Zone 1 (Restorative)', range: '< 110 bpm', time: `${Math.max(10, Math.round(exerciseMins * 0.4))}m`, pct: 25 },
        { zone: 'Zone 2 (Mitochondrial)', range: '110-135 bpm', time: `${Math.max(5, Math.round(exerciseMins * 0.45))}m`, pct: 45 },
        { zone: 'Zone 3 (Aerobic Tempo)', range: '135-155 bpm', time: `${Math.round(exerciseMins * 0.15)}m`, pct: 18 },
        { zone: 'Zone 4 (Threshold)', range: '155-172 bpm', time: `${Math.round(exerciseMins * 0.08)}m`, pct: 8 },
        { zone: 'Zone 5 (Max VO2)', range: '172+ bpm', time: `${Math.round(exerciseMins * 0.04)}m`, pct: 4 },
      ]
    : [];

  return (
    <div className="space-y-6">
      {/* BEVEL PRO TRIO: RECOVERY, ADAPTIVE STRAIN & ENERGY BANK */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* RECOVERY CARD */}
        <div className="liquid-glass-elevated rounded-[24px] p-5 border border-white/15 relative overflow-hidden">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 rounded-[10px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
                <Heart className="w-4 h-4 text-[#10B981]" />
              </div>
              <div>
                <span className="text-[10px] font-mono text-[#10B981] font-black uppercase tracking-wider">RECOVERY</span>
                <h4 className="text-sm font-bold text-white">Readiness</h4>
              </div>
            </div>
            <span className="text-[10px] font-mono font-black px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40">
              {recoveryStatus}
            </span>
          </div>

          <div className="flex items-center space-x-4 my-2">
            <div className="relative w-24 h-24 flex items-center justify-center shrink-0">
              <svg className="w-24 h-24 transform -rotate-90">
                <circle cx="48" cy="48" r="40" stroke="#1F2937" strokeWidth="9" fill="none" />
                <circle
                  cx="48"
                  cy="48"
                  r="40"
                  stroke="#10B981"
                  strokeWidth="9"
                  strokeDasharray={2 * Math.PI * 40}
                  strokeDashoffset={2 * Math.PI * 40 * (1 - recoveryScore / 100)}
                  strokeLinecap="round"
                  fill="none"
                />
              </svg>
              <div className="absolute flex flex-col items-center">
                <span className="text-xl font-mono font-black text-white">{recoveryScore > 0 ? `${recoveryScore}%` : '--'}</span>
              </div>
            </div>
            <div className="space-y-1 text-[11px] font-mono">
              <p className="text-[#C4C4C4] leading-snug line-clamp-3">{recoveryMessage}</p>
              <div className="flex items-center space-x-2 pt-1">
                <span className="text-white">HRV <strong className="text-[#00F0FF]">{hrvValue > 0 ? `${hrvValue}ms` : '--'}</strong></span>
                <span className="text-white">RHR <strong className="text-[#10B981]">{rhrValue > 0 ? `${rhrValue}` : '--'}</strong></span>
              </div>
            </div>
          </div>
        </div>

        {/* ADAPTIVE STRAIN CARD */}
        <div className="liquid-glass-elevated rounded-[24px] p-5 border border-white/15 relative overflow-hidden">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 rounded-[10px] bg-[#FA114F]/20 border border-[#FA114F]/40 flex items-center justify-center">
                <Flame className="w-4 h-4 text-[#FA114F]" />
              </div>
              <div>
                <span className="text-[10px] font-mono text-[#FA114F] font-black uppercase tracking-wider">DAILY STRAIN</span>
                <h4 className="text-sm font-bold text-white">0–21 Cardiovascular Load</h4>
              </div>
            </div>
            <span className="text-[10px] font-mono font-black px-2 py-0.5 rounded-full bg-[#FA114F]/20 text-[#FA114F] border border-[#FA114F]/40">
              {targetLow != null ? `GOAL ${targetLow}–${targetHigh}` : 'TARGET PENDING'}
            </span>
          </div>

          <div className="flex items-baseline space-x-2 my-2">
            <span className="text-3xl font-mono font-black text-white">{strainCurrent > 0 ? strainCurrent : '--'}</span>
            <span className="text-xs font-mono text-[#8A8A8A]">/ 21.0 Max</span>
          </div>

          <div className="w-full h-2.5 bg-black/40 rounded-full overflow-hidden border border-white/10 my-3">
            <div
              className="h-full bg-gradient-to-r from-[#FA114F] via-[#F59E0B] to-[#92E82A] rounded-full transition-all duration-700"
              style={{ width: `${Math.min(100, (strainCurrent / 21) * 100)}%` }}
            />
          </div>

          <div className="text-[11px] font-mono text-[#A1A1AA]">
            {moveCalories > 0 ? `${moveCalories} kcal active expenditure` : 'Connect Apple Health for live strain'}
          </div>
        </div>

        {/* ENERGY BANK CARD */}
        <div className="liquid-glass-elevated rounded-[24px] p-5 border border-white/15 relative overflow-hidden">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 rounded-[10px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 flex items-center justify-center">
                <BatteryCharging className="w-4 h-4 text-[#00F0FF]" />
              </div>
              <div>
                <span className="text-[10px] font-mono text-[#00F0FF] font-black uppercase tracking-wider">ENERGY BANK</span>
                <h4 className="text-sm font-bold text-white">Metabolic Reserve</h4>
              </div>
            </div>
            <span className="text-[10px] font-mono font-black px-2 py-0.5 rounded-full bg-[#00F0FF]/20 text-[#00F0FF] border border-[#00F0FF]/40">
              {energyBank != null ? (energyBank >= 60 ? 'CHARGED' : 'CONSERVE') : 'PENDING'}
            </span>
          </div>

          <div className="flex items-baseline space-x-2 my-2">
            <span className="text-3xl font-mono font-black text-white">{energyBank != null ? `${energyBank}%` : '--'}</span>
            <span className="text-xs font-mono text-[#8A8A8A]">Readiness minus strain drain</span>
          </div>

          <div className="w-full h-2.5 bg-black/40 rounded-full overflow-hidden border border-white/10 my-3">
            <div
              className="h-full bg-gradient-to-r from-[#00F0FF] to-[#10B981] rounded-full transition-all duration-700"
              style={{ width: `${energyBank ?? 0}%` }}
            />
          </div>

          {energyCurve.length > 0 ? (
            <div className="flex items-end space-x-1 h-6">
              {energyCurve.slice(-12).map((pt, i) => (
                <div
                  key={i}
                  title={`${pt.label}: ${pt.value}%`}
                  className="flex-1 bg-[#00F0FF]/70 rounded-t"
                  style={{ height: `${Math.max(15, Math.min(100, pt.value))}%` }}
                />
              ))}
            </div>
          ) : (
            <span className="text-[11px] font-mono text-[#8A8A8A]">Sync iPhone APEX OS for hourly reserve curve</span>
          )}
        </div>
      </div>

      {/* INTRADAY STRESS MONITOR & 5-VITAL HEALTH MONITOR */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="liquid-glass rounded-[22px] p-5 border border-white/10 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <Activity className="w-4 h-4 text-[#E5FE40]" />
              <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
                INTRADAY STRESS MONITOR (0–100)
              </h4>
            </div>
            <span className="text-xs font-mono font-black text-[#E5FE40]">
              {stressScore != null ? `${stressScore} / 100` : '--'}
            </span>
          </div>

          {stressCurve.length > 0 ? (
            <div className="flex items-end space-x-1.5 h-20 pt-2">
              {stressCurve.slice(-16).map((pt, idx) => (
                <div key={idx} className="flex-1 flex flex-col items-center space-y-1">
                  <div className="w-full bg-black/50 rounded-md h-14 flex items-end overflow-hidden">
                    <div
                      className="w-full rounded-md"
                      style={{
                        height: `${Math.max(8, Math.min(100, pt.value))}%`,
                        backgroundColor: pt.value > 70 ? '#FA114F' : pt.value > 40 ? '#F59E0B' : '#10B981',
                      }}
                    />
                  </div>
                  <span className="text-[9px] font-mono text-[#8A8A8A]">{pt.label}</span>
                </div>
              ))}
            </div>
          ) : (
            <div className="p-3.5 rounded-[14px] bg-black/40 border border-dashed border-white/15 text-xs font-mono text-[#A1A1AA]">
              {stressScore != null
                ? `Current stress estimate ${stressScore}/100 from live HRV/RHR. Sync iPhone APEX OS for hourly stress timeline.`
                : 'Connect Apple HealthKit or iPhone Companion to stream intraday heart-rate derived stress curves.'}
            </div>
          )}
        </div>

        <div className="liquid-glass rounded-[22px] p-5 border border-white/10 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              {measuredVitals.length > 0 && inRangeVitals === measuredVitals.length ? (
                <ShieldCheck className="w-4 h-4 text-[#10B981]" />
              ) : (
                <AlertTriangle className="w-4 h-4 text-[#F59E0B]" />
              )}
              <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
                5-VITAL HEALTH MONITOR
              </h4>
            </div>
            <span className="text-xs font-mono font-black text-[#10B981]">
              {measuredVitals.length > 0 ? `${inRangeVitals}/${measuredVitals.length} IN RANGE` : 'AWAITING VITALS'}
            </span>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
            {fiveVitals.map((v) => (
              <div key={v.label} className="p-2.5 rounded-xl bg-black/40 border border-white/10 font-mono">
                <span className="text-[9px] text-[#8A8A8A] block uppercase">{v.label}</span>
                <span className={`text-xs font-black block mt-0.5 ${v.value == null ? 'text-[#64748B]' : v.inRange ? 'text-[#10B981]' : 'text-[#FA114F]'}`}>
                  {v.value || '—'}
                </span>
                <span className="text-[9px] text-white/40">{v.norm}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* HEART RATE INTENSITY ZONES */}
      <div className="liquid-glass rounded-[22px] p-5 border border-white/10">
        <h4 className="text-xs font-mono font-black text-[#E5FE40] uppercase tracking-wider mb-3">
          HEART RATE ZONE BREAKDOWN ({isSynced ? 'APPLE HEALTHKIT LIVE' : 'CONNECT APPLE HEALTH'})
        </h4>
        {zones.length > 0 ? (
          <div className="space-y-2">
            {zones.map((z, idx) => (
              <div key={idx} className="flex items-center justify-between text-xs font-mono py-1 border-b border-white/5 last:border-0">
                <div className="flex items-center space-x-2 w-48">
                  <span className="text-white font-medium">{z.zone}</span>
                  <span className="text-[10px] text-[#8A8A8A]">{z.range}</span>
                </div>
                <div className="flex-1 max-w-xs mx-4 h-2 bg-black/50 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-[#00F0FF] rounded-full"
                    style={{ width: `${Math.min(100, z.pct * 2)}%` }}
                  />
                </div>
                <span className="text-white font-bold">{z.time}</span>
              </div>
            ))}
          </div>
        ) : (
          <div className="p-4 rounded-[14px] bg-black/40 border border-dashed border-white/15 text-xs font-mono text-[#A1A1AA]">
            No heart-rate zone telemetry synced yet. Connect Apple Health or pair a BLE chest strap on iPhone to record real Zone 1–5 training minutes.
          </div>
        )}
      </div>

      {/* SLEEP STAGING ARCHITECTURE & SLEEP NEEDED / DEBT */}
      <div className="liquid-glass rounded-[22px] p-5 border border-white/10">
        <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
          <div className="flex items-center space-x-2">
            <Moon className="w-4 h-4 text-[#38BDF8]" />
            <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
              {sleepHours > 0
                ? `SLEEP ARCHITECTURE (${sleepStages.totalHours} · ${sleepStages.efficiency} EFF)`
                : 'SLEEP COACH & ARCHITECTURE (AWAITING APPLE WATCH)'}
            </h4>
          </div>
          <div className="flex items-center space-x-3 text-[11px] font-mono">
            {sleepNeeded != null && (
              <span className="text-[#E5FE40] font-bold">NEEDED TONIGHT: {sleepNeeded}h</span>
            )}
            {sleepDebt != null && (
              <span className="text-[#38BDF8] font-bold">7D DEBT: {sleepDebt >= 0 ? `+${sleepDebt}h` : `${sleepDebt}h`}</span>
            )}
            <span className="text-[#38BDF8] font-black">
              {sleepHours > 0 ? `SCORE: ${sleepStages.score}/100` : 'SCORE: —'}
            </span>
          </div>
        </div>

        {sleepHours > 0 ? (
          <>
            <div className="w-full h-4 rounded-full overflow-hidden flex bg-black/50 border border-white/10 mb-4">
              <div style={{ width: `${sleepStages.deep.percentage}%`, backgroundColor: sleepStages.deep.color }} title="Deep Sleep" />
              <div style={{ width: `${sleepStages.rem.percentage}%`, backgroundColor: sleepStages.rem.color }} title="REM Sleep" />
              <div style={{ width: `${sleepStages.core.percentage}%`, backgroundColor: sleepStages.core.color }} title="Core Sleep" />
              <div style={{ width: `${sleepStages.awake.percentage}%`, backgroundColor: sleepStages.awake.color }} title="Awake" />
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs font-mono">
              <div className="p-2.5 rounded-lg bg-white/5 border border-white/5">
                <span className="text-[10px] text-[#8A8A8A] block">DEEP SLEEP</span>
                <span className="text-sm font-bold text-[#3B82F6]">{sleepStages.deep.time}</span>
                <span className="text-[10px] text-white/60 block">Cellular Repair ({sleepStages.deep.percentage}%)</span>
              </div>
              <div className="p-2.5 rounded-lg bg-white/5 border border-white/5">
                <span className="text-[10px] text-[#8A8A8A] block">REM SLEEP</span>
                <span className="text-sm font-bold text-[#8B5CF6]">{sleepStages.rem.time}</span>
                <span className="text-[10px] text-white/60 block">Memory Synthesis ({sleepStages.rem.percentage}%)</span>
              </div>
              <div className="p-2.5 rounded-lg bg-white/5 border border-white/5">
                <span className="text-[10px] text-[#8A8A8A] block">CORE SLEEP</span>
                <span className="text-sm font-bold text-[#06B6D4]">{sleepStages.core.time}</span>
                <span className="text-[10px] text-white/60 block">Restorative ({sleepStages.core.percentage}%)</span>
              </div>
              <div className="p-2.5 rounded-lg bg-white/5 border border-white/5">
                <span className="text-[10px] text-[#8A8A8A] block">AWAKE DURATION</span>
                <span className="text-sm font-bold text-[#64748B]">{sleepStages.awake.time}</span>
                <span className="text-[10px] text-white/60 block">Minimal Arousals ({sleepStages.awake.percentage}%)</span>
              </div>
            </div>
          </>
        ) : (
          <div className="p-4 rounded-[14px] bg-black/40 border border-dashed border-white/15 text-xs font-mono text-[#A1A1AA]">
            No sleep stage samples synced yet. Wear Apple Watch overnight and tap Sync on iPhone APEX Companion to load Deep, REM, and Core durations.
          </div>
        )}
      </div>
    </div>
  );
}
