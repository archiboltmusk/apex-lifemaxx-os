import React, { useState } from 'react';
import {
  X,
  Crown,
  ShieldCheck,
  Sparkles,
  Zap,
  Coins,
  CheckCircle2,
  User,
  Heart,
  Dumbbell,
  Laptop,
  Save
} from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function AccountTesterModal({
  isOpen,
  onClose,
  userProfile,
  setUserProfile,
  coins,
  setCoins,
  streakDays,
  setStreakDays,
  onCompleteAllProtocols,
  unitSystem = 'metric',
  onToggleUnitSystem,
}) {
  const [nameInput, setNameInput] = useState(userProfile.name || 'Mac User');
  const [handleInput, setHandleInput] = useState(userProfile.handle || '@user');
  const [appleIdInput, setAppleIdInput] = useState(userProfile.appleId || 'user@icloud.com');
  const [backupMsg, setBackupMsg] = useState('');

  if (!isOpen) return null;

  const handleExportBackup = () => {
    playPlunk();
    try {
      const snapshot = {
        version: 1,
        exportedAt: new Date().toISOString(),
        deviceName: userProfile.device || 'APEX Mac Companion',
        unitSystem,
        userProfile,
        bloodwork: JSON.parse(localStorage.getItem('apex_user_bloodwork') || '[]'),
        facialScans: JSON.parse(localStorage.getItem('apex_facial_scans') || '[]'),
        meals: JSON.parse(localStorage.getItem('apex_logged_meals') || '[]'),
        journalTagsByDate: JSON.parse(localStorage.getItem('apex_daily_journal_tags_v1') || '{}'),
        latestIosBackup: JSON.parse(localStorage.getItem('apex_latest_ios_backup_v1') || 'null'),
      };
      const blob = new Blob([JSON.stringify(snapshot, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `APEX-OS-Backup-${new Date().toISOString().slice(0, 10)}.apexbackup.json`;
      a.click();
      URL.revokeObjectURL(url);
      setBackupMsg('Exported portable .apexbackup.json snapshot.');
    } catch {
      setBackupMsg('Failed to export snapshot.');
    }
  };

  const handleImportBackup = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const parsed = JSON.parse(String(reader.result || '{}'));
        if (parsed.userProfile) {
          setUserProfile(parsed.userProfile);
          localStorage.setItem('apex_user_profile', JSON.stringify(parsed.userProfile));
        }
        if (Array.isArray(parsed.bloodwork)) {
          localStorage.setItem('apex_user_bloodwork', JSON.stringify(parsed.bloodwork));
          window.dispatchEvent(new CustomEvent('apex:bloodwork-updated'));
        }
        if (Array.isArray(parsed.facialScans)) {
          localStorage.setItem('apex_facial_scans', JSON.stringify(parsed.facialScans));
          window.dispatchEvent(new CustomEvent('apex:facial-scan-updated'));
        }
        if (Array.isArray(parsed.meals)) {
          localStorage.setItem('apex_logged_meals', JSON.stringify(parsed.meals));
          window.dispatchEvent(new CustomEvent('apex:meals-updated'));
        }
        if (parsed.dailyTagsByDate || parsed.journalTagsByDate) {
          localStorage.setItem(
            'apex_daily_journal_tags_v1',
            JSON.stringify(parsed.dailyTagsByDate || parsed.journalTagsByDate)
          );
          window.dispatchEvent(new CustomEvent('apex:journal-updated'));
        }
        playCoinChime();
        setBackupMsg(`Imported snapshot from ${parsed.deviceName || 'backup file'}.`);
      } catch {
        setBackupMsg('Invalid .apexbackup JSON file.');
      }
    };
    reader.readAsText(file);
  };

  const handleSaveProfile = (e) => {
    e.preventDefault();
    playPlunk();
    playCoinChime();
    const updated = {
      ...userProfile,
      name: nameInput,
      handle: handleInput,
      appleId: appleIdInput,
    };
    setUserProfile(updated);
    try {
      localStorage.setItem('apex_user_profile', JSON.stringify(updated));
      confetti({
        particleCount: 50,
        spread: 50,
        colors: ['#E5FE40', '#00F0FF', '#10B981'],
      });
    } catch {}
    onClose();
  };

  const addFreeCoins = (amount = 2500) => {
    playPlunk();
    playCoinChime();
    setCoins((c) => c + amount);
    try {
      confetti({
        particleCount: 50,
        spread: 50,
        colors: ['#E5FE40', '#10B981'],
      });
    } catch {}
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-2xl animate-fade-in">
      <div className="liquid-glass-elevated w-full max-w-lg rounded-[32px] p-6 border border-white/20 relative shadow-[0_25px_80px_rgba(0,0,0,0.95)]">
        {/* Close Button */}
        <button
          onClick={() => {
            playPlunk();
            onClose();
          }}
          className="absolute top-5 right-5 w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white/80 transition"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Modal Header */}
        <div className="flex items-center space-x-3 mb-6">
          <div className="w-12 h-12 rounded-[16px] bg-[#E5FE40]/20 border border-[#E5FE40]/40 flex items-center justify-center">
            <User className="w-6 h-6 text-[#E5FE40]" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h2 className="text-lg font-black text-white tracking-tight">User Account & Hardware Profile</h2>
              <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40">
                VERIFIED HOST
              </span>
            </div>
            <p className="text-xs text-[#A1A1AA] font-mono mt-0.5">
              Personalize your biological profile & device synchronization
            </p>
          </div>
        </div>

        {/* Edit User Profile Form */}
        <form onSubmit={handleSaveProfile} className="space-y-4 mb-6">
          <div className="space-y-1.5 text-xs font-mono">
            <label className="text-[#8A8A8A] block font-bold">FULL NAME</label>
            <input
              type="text"
              value={nameInput}
              onChange={(e) => setNameInput(e.target.value)}
              className="w-full px-3.5 py-2.5 rounded-[14px] bg-black/60 border border-white/15 text-white font-bold"
            />
          </div>

          <div className="grid grid-cols-2 gap-3 text-xs font-mono">
            <div className="space-y-1.5">
              <label className="text-[#8A8A8A] block font-bold">HANDLE</label>
              <input
                type="text"
                value={handleInput}
                onChange={(e) => setHandleInput(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-[14px] bg-black/60 border border-white/15 text-[#00F0FF] font-bold"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-[#8A8A8A] block font-bold">APPLE ID / ICLOUD</label>
              <input
                type="text"
                value={appleIdInput}
                onChange={(e) => setAppleIdInput(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-[14px] bg-black/60 border border-white/15 text-white"
              />
            </div>
          </div>

          <div className="p-3 rounded-[16px] bg-white/[0.04] border border-white/10 flex items-center justify-between text-xs font-mono">
            <div className="flex items-center space-x-2">
              <Laptop className="w-4 h-4 text-[#00F0FF]" />
              <span className="text-[#8A8A8A]">HOST HARDWARE:</span>
            </div>
            <span className="text-white font-bold">
              {userProfile.device ||
                (typeof window !== 'undefined' && window.__macDeviceTelemetry
                  ? `${window.__macDeviceTelemetry.modelName} · ${window.__macDeviceTelemetry.ramString}`
                  : 'Local Mac Host')}
            </span>
          </div>

          <button
            type="submit"
            className="w-full py-3 rounded-[14px] bg-[#E5FE40] hover:bg-[#d8f030] text-black font-mono font-black text-xs uppercase tracking-wider flex items-center justify-center space-x-2 shadow-[0_0_15px_rgba(229,254,64,0.4)] transition"
          >
            <Save className="w-4 h-4" />
            <span>SAVE REAL ACCOUNT PROFILE</span>
          </button>
        </form>

        {/* Quick Utilities */}
        <div className="grid grid-cols-2 gap-2.5 pt-3 border-t border-white/10 text-xs font-mono">
          <button
            onClick={() => addFreeCoins(5000)}
            className="p-3 rounded-[14px] bg-black/40 hover:bg-black/60 border border-white/10 text-left transition flex items-center justify-between"
          >
            <div>
              <span className="text-[10px] text-[#E5FE40] font-bold block">+5,000 COINS</span>
              <span className="text-[9px] text-[#8A8A8A]">Staking & Rewards</span>
            </div>
            <Coins className="w-4 h-4 text-[#E5FE40]" />
          </button>

          <button
            onClick={() => {
              playPlunk();
              if (onCompleteAllProtocols) onCompleteAllProtocols();
              onClose();
            }}
            className="p-3 rounded-[14px] bg-black/40 hover:bg-black/60 border border-white/10 text-left transition flex items-center justify-between"
          >
            <div>
              <span className="text-[10px] text-[#10B981] font-bold block">COMPLETE PROTOCOLS</span>
              <span className="text-[9px] text-[#8A8A8A]">Daily Checklist (100%)</span>
            </div>
            <CheckCircle2 className="w-4 h-4 text-[#10B981]" />
          </button>

          <button
            onClick={handleExportBackup}
            className="p-3 rounded-[14px] bg-black/40 hover:bg-black/60 border border-white/10 text-left transition flex items-center justify-between"
          >
            <div>
              <span className="text-[10px] text-[#00F0FF] font-bold block">EXPORT .APEXBACKUP</span>
              <span className="text-[9px] text-[#8A8A8A]">Portable JSON snapshot</span>
            </div>
            <Save className="w-4 h-4 text-[#00F0FF]" />
          </button>

          <label className="p-3 rounded-[14px] bg-black/40 hover:bg-black/60 border border-white/10 text-left transition flex items-center justify-between cursor-pointer">
            <div>
              <span className="text-[10px] text-[#8B5CF6] font-bold block">IMPORT .APEXBACKUP</span>
              <span className="text-[9px] text-[#8A8A8A]">Restore from iPhone / Mac</span>
            </div>
            <Laptop className="w-4 h-4 text-[#8B5CF6]" />
            <input type="file" accept=".json,.apexbackup" onChange={handleImportBackup} className="hidden" />
          </label>
        </div>

        {onToggleUnitSystem && (
          <div className="mt-3 pt-3 border-t border-white/10 flex items-center justify-between text-xs font-mono">
            <span className="text-[#8A8A8A]">DISPLAY UNITS:</span>
            <button
              onClick={onToggleUnitSystem}
              className="px-3 py-1 rounded-[10px] bg-white/10 hover:bg-white/20 text-white font-bold border border-white/15"
            >
              {unitSystem === 'metric' ? 'METRIC (KG · MG/DL)' : 'IMPERIAL (LBS · MMOL/L)'}
            </button>
          </div>
        )}

        {backupMsg && (
          <p className="text-[11px] font-mono text-[#10B981] mt-2 text-center">{backupMsg}</p>
        )}
      </div>
    </div>
  );
}
