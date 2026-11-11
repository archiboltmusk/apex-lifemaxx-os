// Comprehensive Lifemaxxing Datasets, Apple Health, CRED Rewards, Biometric Hardware & Protocols

export const INITIAL_PILLARS = [
  { id: 'looks', name: 'Looksmaxxing', score: null, color: '#00F0FF', icon: 'Sparkles', desc: 'Facial symmetry, jaw angle, vocal pitch & posture' },
  { id: 'bio', name: 'Biomaxxing', score: null, color: '#10B981', icon: 'Activity', desc: 'Biological age, VO2 max, ApoB, bloodwork & labs' },
  { id: 'brain', name: 'Brainmaxxing', score: null, color: '#8B5CF6', icon: 'Brain', desc: 'Flow sprints, dopamine detox, N-Back focus' },
  { id: 'wealth', name: 'Wealthmaxxing', score: null, color: '#F59E0B', icon: 'TrendingUp', desc: 'Deep work sprints, execution streak & leverage' },
  { id: 'sleep', name: 'Sleepmaxxing', score: null, color: '#38BDF8', icon: 'Moon', desc: 'Sleep staging, HRV, circadian light alignment' },
  { id: 'fitness', name: 'Fitness & Strain', score: null, color: '#FA114F', icon: 'Flame', desc: 'Daily strain, workouts, VBT & cardio zones' }
];

export const APPLE_HEALTH_DATA = {
  syncStatus: 'AWAITING SYNC',
  deviceSource: 'Connect iPhone APEX OS or import export.xml',
  lastSynced: 'Not synced',
  activityRings: {
    move: { current: 0, target: 750, unit: 'kcal', percentage: 0, color: '#FA114F' },
    exercise: { current: 0, target: 45, unit: 'min', percentage: 0, color: '#92E82A' },
    stand: { current: 0, target: 12, unit: 'hrs', percentage: 0, color: '#00D6E6' },
  },
  metrics: {
    restingHeartRate: { value: 0, unit: 'BPM', status: 'Awaiting Sync', trend: '--' },
    hrv: { value: 0, unit: 'ms', status: 'Awaiting Sync', trend: '--' },
    bloodOxygen: { value: 0, unit: '%', status: 'Awaiting Sync', trend: '--' },
    vo2Max: { value: 0, unit: 'mL/kg/min', status: 'Awaiting Sync', trend: '--' },
    steps: { value: '0', unit: 'steps', status: 'Awaiting Sync', trend: '0 km' },
    respiratoryRate: { value: 0, unit: 'brpm', status: 'Awaiting Sync', trend: '--' },
    wristTemperature: { value: '--', unit: 'deviation', status: 'Awaiting Sync', trend: '--' },
    cardioRecovery: { value: '--', unit: 'drop in 1m', status: 'Awaiting Sync', trend: '--' }
  },
  sleepStages: {
    score: 0,
    totalHours: '0h 0m',
    efficiency: '--',
    deep: { time: '0h 0m', percentage: 0, color: '#3B82F6' },
    rem: { time: '0h 0m', percentage: 0, color: '#8B5CF6' },
    core: { time: '0h 0m', percentage: 0, color: '#06B6D4' },
    awake: { time: '0m', percentage: 0, color: '#64748B' }
  }
};

export const RECOVERY_STRAIN_DATA = {
  recoveryScore: 0,
  recoveryStatus: 'AWAITING HEALTHKIT',
  recoveryMessage: 'Connect Apple Health or import your health export to compute readiness from HRV and resting heart rate.',
  strainCurrent: 0,
  strainTarget: 18.0,
  caloriesBurned: 0,
  zones: [
    { zone: 'Zone 1 (Restorative)', range: '< 110 bpm', time: '0m', pct: 0 },
    { zone: 'Zone 2 (Mitochondrial)', range: '110-135 bpm', time: '0m', pct: 0 },
    { zone: 'Zone 3 (Aerobic Tempo)', range: '135-155 bpm', time: '0m', pct: 0 },
    { zone: 'Zone 4 (Threshold)', range: '155-172 bpm', time: '0m', pct: 0 },
    { zone: 'Zone 5 (Max VO2)', range: '172+ bpm', time: '0m', pct: 0 },
  ]
};

export const HARDWARE_GARAGE = [];

export const NUTRITION_MACRO_DATA = {
  calories: { current: 0, target: 2600, unit: 'kcal' },
  protein: { current: 0, target: 205, unit: 'g' },
  carbs: { current: 0, target: 240, unit: 'g' },
  fats: { current: 0, target: 68, unit: 'g' },
  water: { current: 0, target: 4.0, unit: 'L' },
  supplements: [
    { name: 'NMN (Nicotinamide Mononucleotide)', dose: '1,000 mg', timing: 'Morning', taken: false },
    { name: 'Trans-Resveratrol (with fats)', dose: '500 mg', timing: 'Morning', taken: false },
    { name: 'Creatine Monohydrate', dose: '5,000 mg', timing: 'Post-Workout', taken: false },
    { name: 'EPA/DHA Ultra-Pure Omega-3', dose: '2,400 mg', timing: 'With Lunch', taken: false },
    { name: 'Vitamin D3 + K2 (MK-7)', dose: '5,000 IU', timing: 'Morning', taken: false },
    { name: 'Magnesium L-Threonate', dose: '144 mg', timing: '9:00 PM', taken: false },
    { name: 'Apigenin', dose: '50 mg', timing: '9:30 PM', taken: false },
    { name: 'L-Theanine + Glycine', dose: '200mg / 3g', timing: '9:30 PM', taken: false }
  ]
};

export const CRED_REWARDS_POOL = [
  { id: 'r1', title: 'Titanium Ascendant Badge', cost: 100, rarity: 'LEGENDARY', desc: 'Unlocks ultra-rare holographic profile shader' },
  { id: 'r2', title: 'Blueprint Longevity Protocol Vol. 2', cost: 250, rarity: 'EPIC', desc: 'Full epigenetic methylation lab analysis template' },
  { id: 'r3', title: 'Whoop Onyx Custom Watchface Skin', cost: 150, rarity: 'RARE', desc: 'Exportable Apple Watch modular face with live strain rings' },
  { id: 'r4', title: '1-on-1 Blood Chemistry AI Audit', cost: 500, rarity: 'MYTHIC', desc: 'Deep biomarker panel review and protocol adjustments' },
  { id: 'r5', title: '40Hz Gamma Master Flowpack', cost: 75, rarity: 'COMMON', desc: 'Unlock 8 binaural frequencies (Gamma, Theta, Alpha)' }
];

export const DAILY_PROTOCOLS = [
  { id: 'p1', time: '06:00 AM', title: 'Circadian Lux Exposure', category: 'sleep', desc: '10-15m direct sunlight in eyes. Suppresses melatonin, spikes cortisol awakening response.', completed: false, xp: 50 },
  { id: 'p2', time: '06:30 AM', title: '500ml Cellular Hydration & Electrolytes', category: 'bio', desc: 'Spring water + electrolytes + magnesium glycinate.', completed: false, xp: 40 },
  { id: 'p3', time: '07:00 AM', title: 'Zone 2 Metabolic Flush (Apple Health Synced)', category: 'bio', desc: '45 mins steady-state nasal breathing (HR 130-140 bpm). Mitochondrial biogenesis.', completed: false, xp: 120 },
  { id: 'p4', time: '08:15 AM', title: 'Cryo Shock Cold Plunge (4°C)', category: 'bio', desc: '3 mins cold immersion for norepinephrine & dopamine support.', completed: false, xp: 90 },
  { id: 'p5', time: '09:00 AM', title: 'Morning Neuro Longevity Stack', category: 'brain', desc: 'Morning supplement stack (if applicable).', completed: false, xp: 60 },
  { id: 'p6', time: '09:30 AM', title: 'Deep Work Block 1 (40Hz Gamma Flow)', category: 'wealth', desc: '90m zero-distraction deep focus session with binaural beats.', completed: false, xp: 150 },
  { id: 'p7', time: '01:30 PM', title: 'Whole-Food Protein Meal (Logged in Fuel)', category: 'looks', desc: 'Nutrient-dense meal scanned & logged into MealScanner.', completed: false, xp: 70 },
  { id: 'p8', time: '03:00 PM', title: 'Deep Work Block 2 (Execution)', category: 'wealth', desc: '90m execution sprint & cognitive training.', completed: false, xp: 140 },
  { id: 'p9', time: '05:30 PM', title: 'Resistance / Velocity Workout', category: 'looks', desc: 'Track reps & velocity via AI Camera Workout Tracker or Hevy logger.', completed: false, xp: 160 },
  { id: 'p10', time: '07:30 PM', title: 'Posture & Craniofacial Check', category: 'looks', desc: 'Palatal posture check + facial scan progression.', completed: false, xp: 80 },
  { id: 'p11', time: '09:30 PM', title: 'Digital Sunset & Sleep Prep', category: 'sleep', desc: 'Dim ambient lighting & cool room temp for deep N3 sleep.', completed: false, xp: 100 }
];

export const BIOMARKER_DATA = [];

export const LOOKSMAXXING_METRICS = {};

export const MASTER_BLUEPRINTS = [
  {
    id: 'b1',
    name: 'The Bryan Johnson Blueprint Reversal',
    tag: 'Longevity & Epigenetics',
    desc: 'Reverse biological pace of aging below 0.75x/yr through 60+ biomarkers, caloric restriction, and targeted polyphenol intake.',
    duration: '180 Days',
    difficulty: 'Extreme'
  },
  {
    id: 'b2',
    name: 'The Golden Era V-Taper Aesthetics',
    tag: 'Looks & Hypertrophy',
    desc: 'Targeted clavicular broadening, lateral delt hypertrophy, lat flare, and sub-11% body fat preservation without hormonal crash.',
    duration: '90 Days',
    difficulty: 'High'
  },
  {
    id: 'b3',
    name: 'The Huberman Neuro-Dopamine Reset',
    tag: 'Cognition & Focus',
    desc: 'Reset baseline dopamine receptor sensitivity, eliminate cheap hyper-stimulation, and sustain 4 hours of daily deep flow output.',
    duration: '30 Days',
    difficulty: 'Moderate'
  },
  {
    id: 'b4',
    name: 'The Naval Ravikant Permissionless Leverage',
    tag: 'Wealth & Capital',
    desc: 'Systematically shift hourly labor into code, media, and automated cashflow assets with infinite upside asymmetry.',
    duration: '365 Days',
    difficulty: 'Mastery'
  }
];
