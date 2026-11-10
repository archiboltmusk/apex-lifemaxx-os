// Comprehensive Lifemaxxing Datasets, Apple Health, CRED Rewards, Biometric Hardware & Protocols

export const INITIAL_PILLARS = [
  { id: 'looks', name: 'Looksmaxxing', score: 92, color: '#00F0FF', icon: 'Sparkles', desc: 'Facial symmetry, lean mass, skin architecture, posture' },
  { id: 'bio', name: 'Biomaxxing', score: 96, color: '#10B981', icon: 'Activity', desc: 'Biological age reduction, VO2 max, ApoB, hormonal balance' },
  { id: 'brain', name: 'Brainmaxxing', score: 90, color: '#8B5CF6', icon: 'Brain', desc: 'Flow state hours, dopamine detox, cognitive velocity' },
  { id: 'wealth', name: 'Wealthmaxxing', score: 88, color: '#F59E0B', icon: 'TrendingUp', desc: 'Code/media leverage, capital velocity, freedom runway' },
  { id: 'sleep', name: 'Sleepmaxxing', score: 95, color: '#38BDF8', icon: 'Moon', desc: 'Deep sleep %, HRV 94ms, circadian alignment' },
  { id: 'fitness', name: 'Fitness & Strain', score: 94, color: '#FA114F', icon: 'Flame', desc: 'Whoop strain 16.8, Zone 2 cardio, 1RM strength' }
];

export const APPLE_HEALTH_DATA = {
  syncStatus: 'SYNCHRONIZED',
  deviceSource: 'Apple Watch Ultra 2 (watchOS 11.2)',
  lastSynced: 'Just now',
  activityRings: {
    move: { current: 840, target: 750, unit: 'kcal', percentage: 112, color: '#FA114F' },
    exercise: { current: 54, target: 45, unit: 'min', percentage: 120, color: '#92E82A' },
    stand: { current: 14, target: 12, unit: 'hrs', percentage: 116, color: '#00D6E6' },
  },
  metrics: {
    restingHeartRate: { value: 48, unit: 'BPM', status: 'Athlete Elite', trend: '-2 bpm' },
    hrv: { value: 94, unit: 'ms', status: 'Optimal Recovery', trend: '+14 ms' },
    bloodOxygen: { value: 99, unit: '%', status: 'Perfect', trend: 'Steady' },
    vo2Max: { value: 58.4, unit: 'mL/kg/min', status: 'Top 1% Longevity', trend: '+1.2' },
    steps: { value: '14,840', unit: 'steps', status: 'Active Peak', trend: '11.4 km' },
    respiratoryRate: { value: 13.1, unit: 'brpm', status: 'Normal', trend: 'Steady' },
    wristTemperature: { value: '-0.3°F', unit: 'deviation', status: 'Baseline', trend: 'Optimal' },
    cardioRecovery: { value: '38 bpm', unit: 'drop in 1m', status: 'Exceptional', trend: '+4 bpm' }
  },
  sleepStages: {
    score: 95,
    totalHours: '8h 22m',
    efficiency: '97%',
    deep: { time: '2h 15m', percentage: 27, color: '#3B82F6' },
    rem: { time: '1h 55m', percentage: 23, color: '#8B5CF6' },
    core: { time: '3h 56m', percentage: 47, color: '#06B6D4' },
    awake: { time: '16m', percentage: 3, color: '#64748B' }
  }
};

export const RECOVERY_STRAIN_DATA = {
  recoveryScore: 94, // 0 - 100
  recoveryStatus: 'PEAK RECOVERY',
  recoveryMessage: 'High parasympathetic dominance detected (HRV 94ms). Your nervous system is primed for max cognitive & physical strain today.',
  strainCurrent: 16.8,
  strainTarget: 18.0,
  caloriesBurned: 2940,
  zones: [
    { zone: 'Zone 1 (Restorative)', range: '< 110 bpm', time: '4h 12m', pct: 45 },
    { zone: 'Zone 2 (Mitochondrial)', range: '110-135 bpm', time: '1h 15m', pct: 35 },
    { zone: 'Zone 3 (Aerobic Tempo)', range: '135-155 bpm', time: '30m', pct: 12 },
    { zone: 'Zone 4 (Threshold)', range: '155-172 bpm', time: '18m', pct: 6 },
    { zone: 'Zone 5 (Max VO2)', range: '172+ bpm', time: '6m', pct: 2 },
  ]
};

export const HARDWARE_GARAGE = [
  {
    id: 'h1',
    name: 'Apple Watch Ultra 2',
    model: 'Titanium (49mm) · watchOS 11.2',
    category: 'Vitals & ECG',
    battery: '88%',
    signal: 'Connected (BLE 5.3)',
    status: 'ACTIVE SENSING',
    icon: 'Watch',
    accent: '#FA114F'
  },
  {
    id: 'h2',
    name: 'Oura Ring Gen 4',
    model: 'Horizon Brushed Silver · Size 10',
    category: 'Sleep & Temperature',
    battery: '74%',
    signal: 'Synced 8m ago',
    status: 'OPTIMAL',
    icon: 'Disc',
    accent: '#8B5CF6'
  },
  {
    id: 'h3',
    name: 'Whoop 4.0 Onyx',
    model: 'SuperKnit HydroBand',
    category: 'Cardio Strain & HRV',
    battery: '91%',
    signal: 'Continuous 100Hz',
    status: 'REAL-TIME',
    icon: 'Activity',
    accent: '#00F0FF'
  },
  {
    id: 'h4',
    name: 'Dexcom G7 CGM',
    model: 'Tricep Sub-Q Sensor',
    category: 'Continuous Glucose',
    battery: '8 Days Left',
    signal: '88 mg/dL Flat',
    status: 'METABOLIC PEAK',
    icon: 'Zap',
    accent: '#10B981'
  },
  {
    id: 'h5',
    name: 'Eight Sleep Pod 4 Ultra',
    model: 'Dynamic Autopilot Cover',
    category: 'Thermal Regulation',
    battery: 'Mains Powered',
    signal: '-2.5°F Target',
    status: 'READY FOR SLEEP',
    icon: 'Moon',
    accent: '#38BDF8'
  }
];

export const NUTRITION_MACRO_DATA = {
  calories: { current: 2280, target: 2600, unit: 'kcal' },
  protein: { current: 198, target: 205, unit: 'g' },
  carbs: { current: 210, target: 240, unit: 'g' },
  fats: { current: 62, target: 68, unit: 'g' },
  water: { current: 3.6, target: 4.0, unit: 'L' },
  supplements: [
    { name: 'NMN (Nicotinamide Mononucleotide)', dose: '1,000 mg', timing: 'Morning', taken: true },
    { name: 'Trans-Resveratrol (with fats)', dose: '500 mg', timing: 'Morning', taken: true },
    { name: 'Creatine Monohydrate', dose: '5,000 mg', timing: 'Post-Workout', taken: true },
    { name: 'EPA/DHA Ultra-Pure Omega-3', dose: '2,400 mg', timing: 'With Lunch', taken: true },
    { name: 'Vitamin D3 + K2 (MK-7)', dose: '5,000 IU', timing: 'Morning', taken: true },
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
  { id: 'p1', time: '06:00 AM', title: 'Circadian Lux Exposure', category: 'sleep', desc: '10-15m direct sunlight in eyes. Suppresses melatonin, spikes cortisol awakening response.', completed: true, xp: 50 },
  { id: 'p2', time: '06:30 AM', title: '500ml Cellular Hydration & Electrolytes', category: 'bio', desc: 'Spring water + 1/2 tsp Himalayan salt + magnesium glycinate.', completed: true, xp: 40 },
  { id: 'p3', time: '07:00 AM', title: 'Zone 2 Metabolic Flush (Apple Health Synced)', category: 'bio', desc: '45 mins steady-state nasal breathing (HR 130-140 bpm). Mitochondrial biogenesis.', completed: true, xp: 120 },
  { id: 'p4', time: '08:15 AM', title: 'Cryo Shock Cold Plunge (4°C)', category: 'bio', desc: '3 mins cold immersion. 250% sustained dopamine elevation for 4 hours.', completed: true, xp: 90 },
  { id: 'p5', time: '09:00 AM', title: 'Morning Neuro Longevity Stack', category: 'brain', desc: 'NMN 1000mg + L-Theanine 200mg + Lion’s Mane 1000mg + Creatine 5g.', completed: true, xp: 60 },
  { id: 'p6', time: '09:30 AM', title: 'Deep Work Block 1 (40Hz Gamma Flow)', category: 'wealth', desc: '90m zero-distraction code or equity creation with binaural waves.', completed: false, xp: 150 },
  { id: 'p7', time: '01:30 PM', title: 'Ancestral Refeed (High Protein, Zero Seed Oils)', category: 'looks', desc: 'Grass-fed ribeye / pasture eggs + fermented kraut + avocado.', completed: false, xp: 70 },
  { id: 'p8', time: '03:00 PM', title: 'Deep Work Block 2 (Distribution Leverage)', category: 'wealth', desc: '90m distribution, media leverage, and systems automation.', completed: false, xp: 140 },
  { id: 'p9', time: '05:30 PM', title: 'Heavy Compound Lift (V-Taper Overload)', category: 'looks', desc: 'Overhead press, weighted pull-ups, lateral raises for golden ratio.', completed: false, xp: 160 },
  { id: 'p10', time: '07:30 PM', title: 'Skin & Mewing Suction Protocol', category: 'looks', desc: '10m red light 660nm + Tretinoin 0.05% + palatal tongue posture.', completed: false, xp: 80 },
  { id: 'p11', time: '09:30 PM', title: 'Digital Sunset, Mouth Tape & Mag-Threonate', category: 'sleep', desc: 'Zero blue light, 65°F room temp, 144mg Magnesium L-Threonate.', completed: false, xp: 100 }
];

export const BIOMARKER_DATA = [
  { marker: 'ApoB (Atherogenic Particles)', value: '54 mg/dL', target: '< 60 mg/dL', status: 'OPTIMAL', delta: '-12 mg/dL', icon: 'Heart' },
  { marker: 'Free Testosterone', value: '26.4 pg/mL', target: '> 20 pg/mL', status: 'ELITE', delta: '+4.2 pg/mL', icon: 'Flame' },
  { marker: 'Total Testosterone', value: '912 ng/dL', target: '> 800 ng/dL', status: 'ELITE', delta: '+120 ng/dL', icon: 'Zap' },
  { marker: 'Fasting Insulin', value: '2.8 uIU/mL', target: '< 4.0 uIU/mL', status: 'OPTIMAL', delta: '-0.8', icon: 'Activity' },
  { marker: 'hs-CRP (Systemic Inflammation)', value: '0.22 mg/L', target: '< 0.5 mg/L', status: 'OPTIMAL', delta: '-0.15', icon: 'ShieldCheck' },
  { marker: 'VO2 Max', value: '58.4 mL/kg/min', target: '> 55 mL/kg/min', status: 'TOP 1%', delta: '+2.4', icon: 'Wind' },
  { marker: 'Vitamin D3', value: '78 ng/mL', target: '60-80 ng/mL', status: 'OPTIMAL', delta: '+6', icon: 'Sun' },
  { marker: 'HbA1c', value: '4.8%', target: '< 5.2%', status: 'OPTIMAL', delta: '-0.2%', icon: 'Check' }
];

export const LOOKSMAXXING_METRICS = {
  midfaceRatio: { value: 0.98, target: '0.95 - 1.0', label: 'Midface Ratio (Compact)' },
  canthalTilt: { value: '+4.2°', target: '+3° to +5°', label: 'Canthal Tilt (Positive Hunter)' },
  gonialAngle: { value: '122°', target: '120° - 128°', label: 'Gonial Angle (Chiseled Jaw)' },
  ffmi: { value: 23.6, target: '22 - 24', label: 'Fat-Free Mass Index (Natural Peak)' },
  bodyFat: { value: '10.5%', target: '10% - 12%', label: 'Body Fat (Vascular Abs)' },
  shoulderToWaist: { value: '1.618', target: '1.618 (Golden Ratio)', label: 'V-Taper Index (Adonis)' }
};

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
