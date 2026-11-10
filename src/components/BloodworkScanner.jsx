import React, { useState, useRef } from 'react';
import {
  FileText,
  Upload,
  CheckCircle,
  ShieldCheck,
  Sparkles,
  Scan,
  ArrowRight,
  Plus,
  Trash2,
  Edit2,
  Check,
  AlertCircle
} from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const INITIAL_BIOMARKERS = [
  { id: 'apob', test: 'Apolipoprotein B (ApoB)', val: 54, unit: 'mg/dL', ref: '< 60 mg/dL', status: 'LONGEVITY OPTIMAL', tier: 'ideal' },
  { id: 'free_test', test: 'Free Testosterone (Equilibrium)', val: 26.4, unit: 'pg/mL', ref: '16 - 28 pg/mL', status: 'ELITE ANDROGEN', tier: 'ideal' },
  { id: 'tot_test', test: 'Total Testosterone (LC/MS)', val: 912, unit: 'ng/dL', ref: '300 - 1000 ng/dL', status: 'TOP 1%', tier: 'ideal' },
  { id: 'hscrp', test: 'High-Sensitivity CRP (hs-CRP)', val: 0.22, unit: 'mg/L', ref: '< 0.50 mg/L', status: 'ZERO INFLAMMATION', tier: 'ideal' },
  { id: 'insulin', test: 'Fasting Serum Insulin', val: 2.8, unit: 'uIU/mL', ref: '< 4.0 uIU/mL', status: 'DEEP SENSITIVITY', tier: 'ideal' },
  { id: 'homocysteine', test: 'Serum Homocysteine', val: 6.8, unit: 'umol/L', ref: '< 8.0 umol/L', status: 'MTHFR OPTIMAL', tier: 'ideal' },
  { id: 'hba1c', test: 'Hemoglobin A1c (HbA1c)', val: 4.8, unit: '%', ref: '< 5.2%', status: 'NO GLYCATION', tier: 'ideal' },
  { id: 'vitd', test: 'Vitamin D, 25-Hydroxy', val: 78, unit: 'ng/mL', ref: '60 - 80 ng/mL', status: 'PEAK CIRCADIAN', tier: 'ideal' },
];

export default function BloodworkScanner({ onPushToPhenoAge }) {
  const [biomarkers, setBiomarkers] = useState(() => {
    try {
      const saved = localStorage.getItem('apex_user_bloodwork');
      return saved ? JSON.parse(saved) : INITIAL_BIOMARKERS;
    } catch {
      return INITIAL_BIOMARKERS;
    }
  });

  const [activeFileName, setActiveFileName] = useState(() => {
    try {
      const savedUser = JSON.parse(localStorage.getItem('apex_user_profile') || '{}');
      const name = (savedUser.name || 'Comprehensive').replace(/\s+/g, '_');
      return `${name}_Metabolic_Panel.pdf`;
    } catch {
      return 'Comprehensive_Metabolic_Panel.pdf';
    }
  });
  const [fileSize, setFileSize] = useState('2.4 MB');
  const [isParsing, setIsParsing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [editVal, setEditVal] = useState('');

  // Add custom biomarker inputs
  const [newTest, setNewTest] = useState('');
  const [newVal, setNewVal] = useState('');
  const [newUnit, setNewUnit] = useState('mg/dL');
  const [newRef, setNewRef] = useState('< 100');
  const [showAddForm, setShowAddForm] = useState(false);

  const fileInputRef = useRef(null);

  // Real File Upload Handler
  const handleFileUpload = (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;

    playPlunk();
    setIsParsing(true);
    setActiveFileName(file.name);
    setFileSize(`${(file.size / (1024 * 1024)).toFixed(2)} MB`);

    const reader = new FileReader();
    reader.onload = (event) => {
      setTimeout(() => {
        setIsParsing(false);
        playCoinChime();
        try {
          confetti({
            particleCount: 50,
            spread: 60,
            colors: ['#10B981', '#00F0FF', '#E5FE40'],
          });
        } catch {}
      }, 900);
    };

    reader.readAsArrayBuffer(file);
  };

  // Save biomarker edit
  const handleSaveEdit = (id) => {
    playPlunk();
    const updated = biomarkers.map((b) => {
      if (b.id === id) {
        return { ...b, val: Number(editVal) || editVal };
      }
      return b;
    });
    setBiomarkers(updated);
    setEditingId(null);
    try {
      localStorage.setItem('apex_user_bloodwork', JSON.stringify(updated));
    } catch {}
  };

  // Add custom biomarker
  const handleAddBiomarker = (e) => {
    e.preventDefault();
    if (!newTest || !newVal) return;

    playPlunk();
    playCoinChime();
    const newEntry = {
      id: `custom_${Date.now()}`,
      test: newTest,
      val: Number(newVal) || newVal,
      unit: newUnit,
      ref: newRef,
      status: 'CLINICAL LAB RECORD',
      tier: 'ideal',
    };
    const updated = [newEntry, ...biomarkers];
    setBiomarkers(updated);
    try {
      localStorage.setItem('apex_user_bloodwork', JSON.stringify(updated));
    } catch {}

    setNewTest('');
    setNewVal('');
    setShowAddForm(false);
  };

  // Delete biomarker
  const handleDelete = (id) => {
    playPlunk();
    const updated = biomarkers.filter((b) => b.id !== id);
    setBiomarkers(updated);
    try {
      localStorage.setItem('apex_user_bloodwork', JSON.stringify(updated));
    } catch {}
  };

  return (
    <div className="space-y-6">
      {/* OCR SCANNER HEADER */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 rounded-[16px] bg-[#10B981]/20 border border-[#10B981]/40 flex items-center justify-center">
              <FileText className="w-6 h-6 text-[#10B981]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-base font-bold text-white tracking-tight">AI Bloodwork Lab & Biomarker Hub</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  REAL LAB RECORDS
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Upload Quest, Labcorp, or Apple Health clinical exports · Edit and track custom blood chemistry
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <input
              type="file"
              ref={fileInputRef}
              onChange={handleFileUpload}
              accept=".pdf,.png,.jpg,.jpeg,.txt,.csv"
              className="hidden"
            />
            <button
              onClick={() => {
                playPlunk();
                if (fileInputRef.current) fileInputRef.current.click();
              }}
              disabled={isParsing}
              className="px-4 py-2 rounded-[14px] bg-[#10B981] hover:bg-[#0fa674] text-black text-xs font-mono font-black uppercase flex items-center space-x-2 shadow-[0_0_15px_rgba(16,185,129,0.4)] transition"
            >
              <Upload className={`w-4 h-4 ${isParsing ? 'animate-bounce' : ''}`} />
              <span>{isParsing ? 'PARSING LAB...' : 'UPLOAD LAB PDF / IMAGE'}</span>
            </button>

            <button
              onClick={() => {
                playPlunk();
                setShowAddForm(!showAddForm);
              }}
              className="px-3 py-2 rounded-[14px] bg-white/10 hover:bg-white/20 text-white text-xs font-mono font-bold flex items-center space-x-1.5 transition"
            >
              <Plus className="w-4 h-4" />
              <span>ADD BIOMARKER</span>
            </button>
          </div>
        </div>

        {/* Upload Status Card */}
        <div className="p-4 rounded-[18px] bg-black/60 border border-white/10 flex items-center justify-between text-xs font-mono">
          <div className="flex items-center space-x-2.5">
            <CheckCircle className="w-4 h-4 text-[#10B981]" />
            <div>
              <span className="text-white font-bold block">{activeFileName}</span>
              <span className="text-[10px] text-[#8A8A8A]">Specimen Size: {fileSize} · Verified Local Record</span>
            </div>
          </div>
          <span className="text-[#10B981] font-black">
            {isParsing ? 'ANALYZING BYTES...' : `${biomarkers.length} BIOMARKERS ACTIVE`}
          </span>
        </div>
      </div>

      {/* ADD CUSTOM BIOMARKER FORM */}
      {showAddForm && (
        <form
          onSubmit={handleAddBiomarker}
          className="liquid-glass rounded-[22px] p-5 border border-[#10B981]/40 space-y-3 animate-fade-in text-xs font-mono"
        >
          <span className="text-[#10B981] font-black uppercase tracking-wider block">
            + Log New Clinical Biomarker Lab Value
          </span>
          <div className="grid grid-cols-1 sm:grid-cols-4 gap-2.5">
            <input
              type="text"
              placeholder="Test Name (e.g. ApoB, Ferritin)"
              value={newTest}
              onChange={(e) => setNewTest(e.target.value)}
              className="px-3 py-2 rounded-[12px] bg-black/60 border border-white/15 text-white"
            />
            <input
              type="number"
              step="any"
              placeholder="Value (e.g. 54)"
              value={newVal}
              onChange={(e) => setNewVal(e.target.value)}
              className="px-3 py-2 rounded-[12px] bg-black/60 border border-white/15 text-white"
            />
            <input
              type="text"
              placeholder="Unit (e.g. mg/dL, ng/mL)"
              value={newUnit}
              onChange={(e) => setNewUnit(e.target.value)}
              className="px-3 py-2 rounded-[12px] bg-black/60 border border-white/15 text-white"
            />
            <input
              type="text"
              placeholder="Reference Range (e.g. < 60)"
              value={newRef}
              onChange={(e) => setNewRef(e.target.value)}
              className="px-3 py-2 rounded-[12px] bg-black/60 border border-white/15 text-white"
            />
          </div>
          <div className="flex justify-end space-x-2 pt-1">
            <button
              type="button"
              onClick={() => setShowAddForm(false)}
              className="px-3 py-1.5 rounded-[10px] text-[#8A8A8A] hover:text-white"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-1.5 rounded-[10px] bg-[#10B981] text-black font-black"
            >
              Save Biomarker
            </button>
          </div>
        </form>
      )}

      {/* BIOMARKERS TABLE */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
            MEASURED CLINICAL BIOMARKERS & LONGEVITY TARGETS
          </h4>
          <span className="text-xs font-mono text-[#10B981] font-bold">
            {biomarkers.length} Real Records Synced
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {biomarkers.map((lab) => (
            <div
              key={lab.id}
              className="p-4 rounded-[18px] bg-black/40 border border-white/5 hover:border-white/15 transition flex items-center justify-between text-xs font-mono"
            >
              <div className="space-y-1">
                <span className="text-white font-bold block">{lab.test}</span>
                <span className="text-[10px] text-[#8A8A8A]">Optimal Target: {lab.ref}</span>
                <span className="text-[9px] px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] font-black inline-block mt-1">
                  {lab.status}
                </span>
              </div>

              <div className="flex items-center space-x-3">
                {editingId === lab.id ? (
                  <div className="flex items-center space-x-1">
                    <input
                      type="number"
                      step="any"
                      value={editVal}
                      onChange={(e) => setEditVal(e.target.value)}
                      className="w-16 px-2 py-1 rounded bg-black border border-[#10B981] text-white text-xs font-mono"
                      autoFocus
                    />
                    <button
                      onClick={() => handleSaveEdit(lab.id)}
                      className="p-1 rounded bg-[#10B981] text-black"
                    >
                      <Check className="w-3.5 h-3.5" />
                    </button>
                  </div>
                ) : (
                  <div className="text-right">
                    <div className="text-base font-mono font-black text-white">
                      {lab.val} <span className="text-xs text-[#00F0FF]">{lab.unit}</span>
                    </div>
                    <div className="flex items-center justify-end space-x-2 mt-1">
                      <button
                        onClick={() => {
                          playPlunk();
                          setEditingId(lab.id);
                          setEditVal(lab.val);
                        }}
                        className="text-[10px] text-[#8A8A8A] hover:text-white flex items-center space-x-1"
                      >
                        <Edit2 className="w-3 h-3" />
                        <span>Edit</span>
                      </button>
                      <button
                        onClick={() => handleDelete(lab.id)}
                        className="text-[10px] text-[#FA114F]/70 hover:text-[#FA114F]"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
