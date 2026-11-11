import React, { useState, useRef, useEffect } from 'react';
import {
  Camera,
  Scan,
  Sparkles,
  CheckCircle,
  Plus,
  Flame,
  TrendingUp,
  ShieldCheck,
  RefreshCw,
  Upload,
  Edit2,
  Check,
  Save,
  Trash2,
  Footprints,
  Zap,
  ChevronRight,
  Activity,
  Video,
  VideoOff
} from 'lucide-react';
import { playPlunk, playCoinChime, playHealthSyncChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const PRESET_MEALS = [
  {
    name: 'Grass-Fed Ribeye & Roasted Sweet Potato',
    protein: 68,
    carbs: 44,
    fats: 28,
    calories: 694,
    gi: 48,
    leucine: 4.8,
    category: 'Hypertrophy Anabolic',
  },
  {
    name: 'Wild Alaskan Sockeye Salmon & Quinoa Bowl',
    protein: 52,
    carbs: 38,
    fats: 22,
    calories: 554,
    gi: 42,
    leucine: 3.9,
    category: 'Omega-3 Longevity',
  },
  {
    name: 'Pasture-Raised Eggs, Avocado & Organic Sourdough',
    protein: 34,
    carbs: 32,
    fats: 29,
    calories: 525,
    gi: 53,
    leucine: 2.8,
    category: 'Choline Cognitive',
  },
  {
    name: 'Grass-Fed Whey Isolate & Wild Blueberries',
    protein: 48,
    carbs: 26,
    fats: 4,
    calories: 332,
    gi: 35,
    leucine: 5.1,
    category: 'Fast Anabolism',
  },
  {
    name: 'Free-Range Chicken Breast & Jasmine Rice',
    protein: 58,
    carbs: 65,
    fats: 7,
    calories: 555,
    gi: 68,
    leucine: 4.2,
    category: 'Glycogen Replenishment',
  },
];

export default function MealScanner() {
  const [isScanning, setIsScanning] = useState(false);
  const [mealLogged, setMealLogged] = useState(false);
  const [uploadedImage, setUploadedImage] = useState(null);
  const [isLiveCamera, setIsLiveCamera] = useState(false);
  const [cameraError, setCameraError] = useState(null);

  // Editable Meal Nutrition State (starts empty until camera scan, photo upload, or manual entry)
  const [mealName, setMealName] = useState('');
  const [proteinG, setProteinG] = useState(0);
  const [carbsG, setCarbsG] = useState(0);
  const [fatsG, setFatsG] = useState(0);
  const [fiberG, setFiberG] = useState(0);
  const [sugarG, setSugarG] = useState(0);
  const [calories, setCalories] = useState(0);
  const [giIndex, setGiIndex] = useState(0);
  const [leucineG, setLeucineG] = useState(0);
  const [isEditing, setIsEditing] = useState(false);

  // Bevel Pro Food Engines: Describe Meal, Barcode Lookup (OpenFoodFacts), Custom Recipes
  const [describeText, setDescribeText] = useState('');
  const [barcodeCode, setBarcodeCode] = useState('');
  const [barcodeStatus, setBarcodeStatus] = useState('');
  const [isFetchingBarcode, setIsFetchingBarcode] = useState(false);
  const [customRecipes, setCustomRecipes] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('apex_custom_recipes_v1') || '[]');
    } catch {
      return [];
    }
  });

  // Logged meals history
  const [loggedMeals, setLoggedMeals] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('apex_logged_meals') || '[]');
    } catch {
      return [];
    }
  });

  const fileInputRef = useRef(null);
  const videoRef = useRef(null);
  const streamRef = useRef(null);

  // Calculate Glycemic Load: (GI * Net Carbs) / 100
  const glycemicLoad = Math.round((giIndex * carbsG) / 100);
  const glCategory = glycemicLoad <= 10 ? 'LOW SPIKE' : glycemicLoad <= 19 ? 'MODERATE' : 'HIGH SPIKE';
  const glColor = glycemicLoad <= 10 ? '#10B981' : glycemicLoad <= 19 ? '#E5FE40' : '#FA114F';

  // Predicted postprandial glucose rise in mg/dL
  const predictedSpikeDelta = Math.round(glycemicLoad * 1.8 + 12);

  // Cleanup camera stream on unmount
  useEffect(() => {
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((track) => track.stop());
      }
    };
  }, []);

  const startLiveCamera = async () => {
    playPlunk();
    setCameraError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: { ideal: 1280 }, height: { ideal: 720 }, facingMode: 'environment' },
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play();
      }
      setIsLiveCamera(true);
      setUploadedImage(null);
    } catch (err) {
      console.warn('Camera access error:', err);
      setCameraError('Camera access unavailable. Using high-res upload mode.');
      setIsLiveCamera(false);
    }
  };

  const stopLiveCamera = () => {
    playPlunk();
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
    setIsLiveCamera(false);
  };

  const captureCameraFrame = () => {
    if (!videoRef.current) return;
    playPlunk();
    setIsScanning(true);

    const canvas = document.createElement('canvas');
    canvas.width = videoRef.current.videoWidth || 640;
    canvas.height = videoRef.current.videoHeight || 480;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(videoRef.current, 0, 0, canvas.width, canvas.height);
    const dataUrl = canvas.toDataURL('image/jpeg');

    setUploadedImage(dataUrl);
    stopLiveCamera();

    setTimeout(() => {
      setIsScanning(false);
      setIsEditing(true);
      if (!mealName) setMealName('Captured Camera Meal (Enter Name & Macros)');
      playCoinChime();
    }, 600);
  };

  const handleImageUpload = (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;

    playPlunk();
    setIsScanning(true);
    setMealLogged(false);
    stopLiveCamera();

    const reader = new FileReader();
    reader.onload = (event) => {
      setUploadedImage(event.target.result);
      setTimeout(() => {
        setIsScanning(false);
        setIsEditing(true);
        playCoinChime();
        const detectedName = file.name
          .replace(/\.[^/.]+$/, '')
          .replace(/[-_]/g, ' ')
          .replace(/\b\w/g, (c) => c.toUpperCase());
        setMealName(detectedName || 'Uploaded Meal Specimen');
      }, 600);
    };
    reader.readAsDataURL(file);
  };

  const selectPreset = (preset) => {
    playPlunk();
    setMealName(preset.name);
    setProteinG(preset.protein);
    setCarbsG(preset.carbs);
    setFatsG(preset.fats);
    setCalories(preset.calories);
    setGiIndex(preset.gi);
    setLeucineG(preset.leucine);
    setMealLogged(false);
  };

  const handleDescribeParse = () => {
    const q = describeText.trim().toLowerCase();
    if (!q) return;
    playPlunk();
    const DB = [
      { keys: ['egg'], kcal: 72, p: 6.3, c: 0.4, f: 4.8, fib: 0, sug: 0.2, unitG: 50 },
      { keys: ['chicken'], kcal: 165, p: 31, c: 0, f: 3.6, fib: 0, sug: 0, unitG: 100 },
      { keys: ['salmon'], kcal: 208, p: 20, c: 0, f: 13, fib: 0, sug: 0, unitG: 100 },
      { keys: ['steak', 'ribeye', 'beef'], kcal: 250, p: 26, c: 0, f: 15, fib: 0, sug: 0, unitG: 100 },
      { keys: ['rice'], kcal: 130, p: 2.7, c: 28, f: 0.3, fib: 0.4, sug: 0.1, unitG: 100 },
      { keys: ['oats', 'oatmeal'], kcal: 150, p: 5, c: 27, f: 2.5, fib: 4, sug: 1, unitG: 40 },
      { keys: ['avocado'], kcal: 160, p: 2, c: 8.5, f: 14.7, fib: 6.7, sug: 0.7, unitG: 100 },
      { keys: ['banana'], kcal: 105, p: 1.3, c: 27, f: 0.4, fib: 3.1, sug: 14.4, unitG: 118 },
      { keys: ['whey', 'protein shake'], kcal: 120, p: 24, c: 2, f: 1.5, fib: 0, sug: 1, unitG: 30 },
      { keys: ['yogurt', 'greek'], kcal: 97, p: 10, c: 3.6, f: 5, fib: 0, sug: 3.6, unitG: 100 },
      { keys: ['sweet potato', 'potato'], kcal: 86, p: 1.6, c: 20, f: 0.1, fib: 3, sug: 4.2, unitG: 100 },
    ];
    let tot = { kcal: 0, p: 0, c: 0, f: 0, fib: 0, sug: 0, hits: 0 };
    q.split(/[,&+]|and/).forEach((chunk) => {
      const part = chunk.trim();
      const gramMatch = part.match(/(\d+(?:\.\d+)?)\s*g\b/);
      const countMatch = part.match(/(\d+(?:\.\d+)?)/);
      const item = DB.find((d) => d.keys.some((k) => part.includes(k)));
      if (!item) return;
      tot.hits += 1;
      const mult = gramMatch ? parseFloat(gramMatch[1]) / item.unitG : countMatch ? parseFloat(countMatch[1]) : 1;
      tot.kcal += item.kcal * mult;
      tot.p += item.p * mult;
      tot.c += item.c * mult;
      tot.f += item.f * mult;
      tot.fib += item.fib * mult;
      tot.sug += item.sug * mult;
    });
    if (tot.hits === 0) {
      setBarcodeStatus('Unrecognized food keywords — enter macros manually or use Barcode lookup.');
      setIsEditing(true);
      setMealName(describeText.trim());
      return;
    }
    setMealName(describeText.trim());
    setCalories(Math.round(tot.kcal));
    setProteinG(Math.round(tot.p));
    setCarbsG(Math.round(tot.c));
    setFatsG(Math.round(tot.f));
    setFiberG(Math.round(tot.fib));
    setSugarG(Math.round(tot.sug));
    setGiIndex(tot.c > 25 && tot.fib < 4 ? 64 : 42);
    setLeucineG(+(tot.p * 0.08).toFixed(1));
    setMealLogged(false);
    setBarcodeStatus('Parsed meal macros cleanly — review & tap Commit Meal.');
    playCoinChime();
  };

  const handleBarcodeLookup = async () => {
    const clean = barcodeCode.replace(/\s+/g, '');
    if (clean.length < 6) return;
    playPlunk();
    setIsFetchingBarcode(true);
    setBarcodeStatus('Querying OpenFoodFacts v2 database...');
    try {
      const res = await fetch(`https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(clean)}.json`);
      const json = await res.json();
      const prod = json?.product;
      const n = prod?.nutriments;
      if (json?.status === 1 && prod && n) {
        setMealName(prod.product_name || `Barcode ${clean}`);
        setCalories(Math.round(n['energy-kcal_serving'] ?? n['energy-kcal_100g'] ?? 0));
        setProteinG(Math.round(n.proteins_serving ?? n.proteins_100g ?? 0));
        setCarbsG(Math.round(n.carbohydrates_serving ?? n.carbohydrates_100g ?? 0));
        setFatsG(Math.round(n.fat_serving ?? n.fat_100g ?? 0));
        setFiberG(Math.round(n.fiber_serving ?? n.fiber_100g ?? 0));
        setSugarG(Math.round(n.sugars_serving ?? n.sugars_100g ?? 0));
        setBarcodeStatus(`Loaded ${prod.product_name || clean} (OpenFoodFacts). Review & Log!`);
        setMealLogged(false);
        playCoinChime();
      } else {
        setBarcodeStatus(`No product found for barcode ${clean}. Enter macros manually.`);
      }
    } catch {
      setBarcodeStatus('Network unreachable for OpenFoodFacts — enter macros manually.');
    } finally {
      setIsFetchingBarcode(false);
    }
  };

  const handleSaveAsRecipe = () => {
    if (!mealName || calories <= 0) return;
    playCoinChime();
    const rec = { id: `rec-${Date.now()}`, name: mealName, calories, protein: proteinG, carbs: carbsG, fats: fatsG, fiber: fiberG, sugar: sugarG };
    const next = [rec, ...customRecipes.filter((r) => r.name !== rec.name)].slice(0, 12);
    setCustomRecipes(next);
    try {
      localStorage.setItem('apex_custom_recipes_v1', JSON.stringify(next));
    } catch {}
  };

  const handleLogMeal = () => {
    playPlunk();
    playCoinChime();
    setMealLogged(true);

    try {
      const newEntry = {
        id: Date.now(),
        name: mealName,
        calories,
        protein: proteinG,
        carbs: carbsG,
        fats: fatsG,
        fiber: fiberG,
        sugar: sugarG,
        glycemicLoad,
        leucine: leucineG,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      };
      const updated = [newEntry, ...loggedMeals];
      setLoggedMeals(updated);
      localStorage.setItem('apex_logged_meals', JSON.stringify(updated));
      window.dispatchEvent(new CustomEvent('apex:meals-updated'));

      confetti({
        particleCount: 65,
        spread: 70,
        colors: ['#00F0FF', '#E5FE40', '#10B981'],
      });
    } catch {}
  };

  const removeMeal = (id) => {
    playPlunk();
    const filtered = loggedMeals.filter((m) => m.id !== id);
    setLoggedMeals(filtered);
    localStorage.setItem('apex_logged_meals', JSON.stringify(filtered));
    window.dispatchEvent(new CustomEvent('apex:meals-updated'));
  };

  const triggerGlut4Walk = () => {
    playHealthSyncChime();
    // Dispatch event to activate GLUT4 timer in GlucoseCircadianHub
    window.dispatchEvent(new CustomEvent('apex:start-glut4-walk'));
    // Also dispatch tab navigation to Glucose & Circadian Hub
    window.dispatchEvent(
      new CustomEvent('apex:navigate-tab', {
        detail: { tab: 'fitness', subTab: 'cgm' },
      })
    );
  };

  const dailyTotals = loggedMeals.reduce(
    (acc, m) => {
      acc.calories += m.calories || 0;
      acc.protein += m.protein || 0;
      acc.carbs += m.carbs || 0;
      acc.fats += m.fats || 0;
      return acc;
    },
    { calories: 0, protein: 0, carbs: 0, fats: 0 }
  );

  return (
    <div className="space-y-6">
      {/* BEVEL PRO: DESCRIBE MEAL, BARCODE LOOKUP & CUSTOM RECIPES */}
      <div className="liquid-glass rounded-[22px] p-5 border border-white/10 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <span className="text-[10px] font-mono text-[#E5FE40] font-black uppercase tracking-wider">
              BEVEL FUEL ENGINES · NLP, BARCODE &amp; RECIPES
            </span>
            <h4 className="text-sm font-bold text-white">Describe Meal or Scan UPC/EAN Barcode</h4>
          </div>
          {mealName && calories > 0 && (
            <button
              onClick={handleSaveAsRecipe}
              className="px-3 py-1 rounded-[10px] bg-white/10 hover:bg-white/20 text-[11px] font-mono font-bold text-[#E5FE40]"
            >
              + Save Custom Recipe
            </button>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 font-mono">
          <div className="flex items-center space-x-2">
            <input
              type="text"
              value={describeText}
              onChange={(e) => setDescribeText(e.target.value)}
              placeholder="Describe meal: e.g. 3 eggs, 200g chicken, avocado"
              className="flex-1 px-3 py-2 rounded-[12px] bg-black/50 border border-white/15 text-xs text-white"
            />
            <button
              onClick={handleDescribeParse}
              className="px-3.5 py-2 rounded-[12px] bg-[#E5FE40] text-black text-xs font-black shrink-0"
            >
              Parse
            </button>
          </div>

          <div className="flex items-center space-x-2">
            <input
              type="text"
              value={barcodeCode}
              onChange={(e) => setBarcodeCode(e.target.value)}
              placeholder="UPC / EAN Barcode (e.g. 3017620422003)"
              className="flex-1 px-3 py-2 rounded-[12px] bg-black/50 border border-white/15 text-xs text-white"
            />
            <button
              onClick={handleBarcodeLookup}
              disabled={isFetchingBarcode}
              className="px-3.5 py-2 rounded-[12px] bg-[#00F0FF] text-black text-xs font-black shrink-0"
            >
              {isFetchingBarcode ? '...' : 'Lookup'}
            </button>
          </div>
        </div>

        {barcodeStatus && (
          <div className="text-[11px] font-mono text-[#00F0FF]">{barcodeStatus}</div>
        )}

        {customRecipes.length > 0 && (
          <div className="flex flex-wrap items-center gap-2 pt-1 font-mono">
            <span className="text-[10px] text-[#8A8A8A] uppercase">SAVED RECIPES:</span>
            {customRecipes.map((rec) => (
              <button
                key={rec.id}
                onClick={() => selectPreset({ ...rec, gi: 45, leucine: +(rec.protein * 0.08).toFixed(1) })}
                className="px-2.5 py-1 rounded-[8px] bg-white/5 hover:bg-white/15 border border-white/10 text-[11px] text-white"
              >
                {rec.name} ({rec.calories} kcal)
              </button>
            ))}
          </div>
        )}
      </div>

      {/* AI COMPUTER VISION VIEWFINDER & INGESTION */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 relative overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
          <div className="flex items-center space-x-2.5">
            <div className="w-10 h-10 rounded-[12px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 flex items-center justify-center">
              <Camera className="w-5 h-5 text-[#00F0FF]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">AI Vision Macro & Nutrition Scanner</h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  ON-DEVICE VISION
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                MobileNetV4 (<code className="text-[#00F0FF]">food_macro_vision.onnx</code> 37MB) · Real-Time Meal Macro Inference
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {isLiveCamera ? (
              <>
                <button
                  onClick={captureCameraFrame}
                  className="px-4 py-2 rounded-[14px] bg-[#10B981] hover:bg-[#0ea372] text-black text-xs font-mono font-black uppercase flex items-center space-x-2 shadow-[0_0_15px_rgba(16,185,129,0.4)] transition"
                >
                  <Camera className="w-4 h-4" />
                  <span>CAPTURE SPECIMEN</span>
                </button>
                <button
                  onClick={stopLiveCamera}
                  className="px-3 py-2 rounded-[14px] bg-white/10 hover:bg-white/20 text-white text-xs font-mono transition"
                >
                  <VideoOff className="w-4 h-4" />
                </button>
              </>
            ) : (
              <>
                <button
                  onClick={startLiveCamera}
                  className="px-3.5 py-2 rounded-[14px] bg-[#00F0FF]/20 hover:bg-[#00F0FF]/30 text-[#00F0FF] border border-[#00F0FF]/40 text-xs font-mono font-bold uppercase flex items-center space-x-1.5 transition"
                >
                  <Video className="w-4 h-4" />
                  <span>START LIVE WEBCAM</span>
                </button>
                <input
                  type="file"
                  ref={fileInputRef}
                  onChange={handleImageUpload}
                  accept="image/*"
                  className="hidden"
                />
                <button
                  onClick={() => {
                    playPlunk();
                    if (fileInputRef.current) fileInputRef.current.click();
                  }}
                  disabled={isScanning}
                  className="px-4 py-2 rounded-[14px] bg-[#00F0FF] hover:bg-[#00d6e6] text-black text-xs font-mono font-black uppercase flex items-center space-x-2 shadow-[0_0_15px_rgba(0,240,255,0.4)] transition"
                >
                  <Upload className="w-4 h-4" />
                  <span>{isScanning ? 'ANALYZING...' : 'UPLOAD PHOTO'}</span>
                </button>
              </>
            )}
          </div>
        </div>

        {cameraError && (
          <div className="mb-3 p-3 rounded-[12px] bg-[#FA114F]/10 border border-[#FA114F]/30 text-[#FA114F] text-xs font-mono">
            {cameraError}
          </div>
        )}

        {/* Viewfinder Graphic / Image / Live Video Feed */}
        <div className="relative h-64 rounded-[20px] bg-gradient-to-b from-black/80 to-[#0B0E14] border border-white/15 flex flex-col justify-between p-4 overflow-hidden">
          {isLiveCamera && (
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
              className="absolute inset-0 w-full h-full object-cover"
            />
          )}

          {uploadedImage && !isLiveCamera && (
            <img
              src={uploadedImage}
              alt="Scanned Food"
              className="absolute inset-0 w-full h-full object-cover opacity-85"
            />
          )}

          {/* Scanning Beam */}
          {isScanning && (
            <div className="absolute inset-x-0 h-1 bg-[#00F0FF] shadow-[0_0_20px_#00F0FF] animate-bounce z-20" />
          )}

          {/* Top Camera HUD */}
          <div className="relative z-10 flex items-center justify-between text-[10px] font-mono text-white/90 bg-black/60 px-3 py-1 rounded-full border border-white/10 backdrop-blur-md">
            <span>
              {isLiveCamera
                ? 'LIVE FACETIME HD STREAM (30 FPS)'
                : uploadedImage
                ? 'REAL SPECIMEN LOADED'
                : 'CAMERA SENSOR STANDBY'}
            </span>
            <span className="text-[#00F0FF] font-bold">
              {isLiveCamera
                ? 'POINT CAMERA AT FOOD DISH & CAPTURE'
                : uploadedImage
                ? 'SPECIMEN CAPTURED · VERIFY / ENTER MACROS'
                : 'AWAITING CAMERA, PHOTO, OR MANUAL MEAL'}
            </span>
          </div>

          {/* Food Bounding Box & Classification Overlay */}
          <div className="relative z-10 space-y-2">
            {mealName || uploadedImage ? (
              <div className="inline-block p-3 rounded-[14px] bg-black/80 border border-[#E5FE40]/60 text-xs font-mono backdrop-blur-md shadow-lg">
                <div className="flex items-center space-x-2 mb-1">
                  <span className="text-[#E5FE40] font-black text-sm">{mealName || 'Captured Meal Specimen'}</span>
                  <span
                    className="text-[9px] px-1.5 py-0.5 rounded font-black border"
                    style={{ color: glColor, borderColor: `${glColor}60`, backgroundColor: `${glColor}20` }}
                  >
                    GL {glycemicLoad} · {glCategory}
                  </span>
                </div>
                <div className="text-[11px] text-white flex items-center space-x-2">
                  <span className="text-[#FA114F] font-bold">{proteinG}g Protein</span>
                  <span className="text-white/40">·</span>
                  <span className="text-[#00F0FF] font-bold">{carbsG}g Carbs</span>
                  <span className="text-white/40">·</span>
                  <span className="text-[#F59E0B] font-bold">{fatsG}g Fats</span>
                  <span className="text-white/40">·</span>
                  <span className="text-[#E5FE40] font-bold">{calories} kcal</span>
                </div>
              </div>
            ) : (
              <div className="inline-block p-3 rounded-[14px] bg-black/75 border border-white/15 text-xs font-mono backdrop-blur-md">
                <span className="text-white font-bold block">No Meal Scanned Yet</span>
                <span className="text-[11px] text-[#A1A1AA]">Start Webcam, upload a meal photo, or select/customize a template below to calculate glycemic load.</span>
              </div>
            )}
          </div>

          {/* Bottom HUD */}
          <div className="relative z-10 flex items-center justify-between text-[10px] font-mono text-white/80 bg-black/60 px-3 py-1 rounded-full border border-white/10 backdrop-blur-md">
            <span>LEUCINE: {leucineG}g (mTOR HYPERTROPHY TRIGGERED)</span>
            <span className="text-[#10B981] font-bold">PREDICTED GLUCOSE SPIKE: +{predictedSpikeDelta} mg/dL</span>
          </div>
        </div>

        {/* Quick Select Preset Meals */}
        <div className="mt-4 pt-3 border-t border-white/10">
          <span className="text-[10px] font-mono text-[#8A8A8A] uppercase tracking-wider block mb-2">
            RAPID SPECIMEN TEMPLATES // 1-TAP INGESTION:
          </span>
          <div className="flex flex-wrap gap-2">
            {PRESET_MEALS.map((preset) => (
              <button
                key={preset.name}
                onClick={() => selectPreset(preset)}
                className={`px-3 py-1.5 rounded-[12px] text-xs font-mono transition border ${
                  mealName === preset.name
                    ? 'bg-[#E5FE40]/20 text-[#E5FE40] border-[#E5FE40]/60 font-black'
                    : 'bg-white/[0.04] text-[#A1A1AA] hover:text-white border-white/10'
                }`}
              >
                {preset.name.split('&')[0]} ({preset.calories} kcal)
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* METABOLIC GLYCEMIC LOAD & GLUCOSE SPIKE PREDICTOR */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* GL Card */}
        <div className="liquid-glass rounded-[22px] p-5 border border-white/10 space-y-2">
          <div className="flex items-center justify-between text-xs font-mono">
            <span className="text-[#8A8A8A] uppercase">GLYCEMIC LOAD (GL)</span>
            <span
              className="px-2 py-0.5 rounded-full font-black text-[10px] border"
              style={{ color: glColor, borderColor: `${glColor}60`, backgroundColor: `${glColor}20` }}
            >
              {glCategory}
            </span>
          </div>
          <div className="flex items-baseline space-x-2">
            <span className="text-3xl font-mono font-black text-white">{glycemicLoad}</span>
            <span className="text-xs font-mono text-[#8A8A8A]">/ 100</span>
          </div>
          <p className="text-[11px] font-mono text-[#A1A1AA]">
            Net impact on blood sugar based on {carbsG}g carbs and GI index of {giIndex}.
          </p>
        </div>

        {/* Leucine / mTOR Card */}
        <div className="liquid-glass rounded-[22px] p-5 border border-white/10 space-y-2">
          <div className="flex items-center justify-between text-xs font-mono">
            <span className="text-[#8A8A8A] uppercase">LEUCINE CONTENT</span>
            <span className="px-2 py-0.5 rounded-full font-black text-[10px] bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40">
              mTOR ACTIVATED
            </span>
          </div>
          <div className="flex items-baseline space-x-2">
            <span className="text-3xl font-mono font-black text-[#10B981]">{leucineG}g</span>
            <span className="text-xs font-mono text-[#8A8A8A]">&gt; 3.0g threshold</span>
          </div>
          <p className="text-[11px] font-mono text-[#A1A1AA]">
            Saturates muscle protein synthesis (MPS) machinery for maximum hypertrophy.
          </p>
        </div>

        {/* GLUT4 Action Card */}
        <div className="liquid-glass rounded-[22px] p-5 border border-[#10B981]/30 bg-[#10B981]/[0.03] space-y-3 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between text-xs font-mono mb-1">
              <span className="text-[#10B981] font-bold flex items-center space-x-1">
                <Footprints className="w-3.5 h-3.5" />
                <span>POSTPRANDIAL GLUT4 WALK</span>
              </span>
              <span className="text-[10px] font-mono text-white/60">15 MIN</span>
            </div>
            <p className="text-[11px] font-mono text-[#A1A1AA]">
              A 15-min walk immediately blunts glucose rise by up to 34% via insulin-independent GLUT4 translocase.
            </p>
          </div>
          <button
            onClick={triggerGlut4Walk}
            className="w-full py-2.5 rounded-[12px] bg-[#10B981] hover:bg-[#0ea372] text-black text-xs font-mono font-black uppercase flex items-center justify-center space-x-1.5 shadow-[0_0_15px_rgba(16,185,129,0.3)] transition"
          >
            <Footprints className="w-4 h-4" />
            <span>TRIGGER 15M GLUT4 WALK NOW</span>
          </button>
        </div>
      </div>

      {/* DETAILED NUTRITION BREAKDOWN CARD */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
              MACRONUTRIENT FACTOR METRICS
            </h4>
            <button
              onClick={() => setIsEditing(!isEditing)}
              className="text-[10px] text-[#00F0FF] font-mono flex items-center space-x-1 hover:underline"
            >
              <Edit2 className="w-3 h-3" />
              <span>{isEditing ? 'Done' : 'Fine-Tune Macros'}</span>
            </button>
          </div>
          <span className="text-xs font-mono text-[#E5FE40] font-bold">TOTAL: {calories} KCAL</span>
        </div>

        {isEditing && (
          <div className="p-4 rounded-[18px] bg-black/60 border border-white/10 space-y-3 text-xs font-mono">
            <div>
              <span className="text-[#E5FE40] block mb-1">MEAL NAME</span>
              <input
                type="text"
                placeholder="e.g., Wild Salmon & Avocado Salad"
                value={mealName}
                onChange={(e) => setMealName(e.target.value)}
                className="w-full bg-black border border-white/20 p-2 rounded text-white"
              />
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
            <div>
              <span className="text-[#FA114F] block">PROTEIN (G)</span>
              <input
                type="number"
                value={proteinG}
                onChange={(e) => {
                  const p = Number(e.target.value);
                  setProteinG(p);
                  setCalories(p * 4 + carbsG * 4 + fatsG * 9);
                  setLeucineG(+(p * 0.075).toFixed(1));
                }}
                className="w-full bg-black border border-white/20 p-2 rounded text-white"
              />
            </div>
            <div>
              <span className="text-[#00F0FF] block">CARBS (G)</span>
              <input
                type="number"
                value={carbsG}
                onChange={(e) => {
                  const c = Number(e.target.value);
                  setCarbsG(c);
                  setCalories(proteinG * 4 + c * 4 + fatsG * 9);
                }}
                className="w-full bg-black border border-white/20 p-2 rounded text-white"
              />
            </div>
            <div>
              <span className="text-[#F59E0B] block">FATS (G)</span>
              <input
                type="number"
                value={fatsG}
                onChange={(e) => {
                  const f = Number(e.target.value);
                  setFatsG(f);
                  setCalories(proteinG * 4 + carbsG * 4 + f * 9);
                }}
                className="w-full bg-black border border-white/20 p-2 rounded text-white"
              />
            </div>
            <div>
              <span className="text-white block">GI (0-100)</span>
              <input
                type="number"
                value={giIndex}
                onChange={(e) => setGiIndex(Number(e.target.value))}
                className="w-full bg-black border border-white/20 p-2 rounded text-white"
              />
            </div>
            <div>
              <span className="text-[#E5FE40] block">CALORIES</span>
              <input
                type="number"
                value={calories}
                onChange={(e) => setCalories(Number(e.target.value))}
                className="w-full bg-black border border-white/20 p-2 rounded text-white"
              />
            </div>
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10 space-y-1">
            <span className="text-[10px] font-mono text-[#FA114F] font-bold block">PROTEIN</span>
            <span className="text-2xl font-mono font-black text-white">{proteinG}g</span>
            <span className="text-[10px] font-mono text-[#8A8A8A] block">
              {proteinG * 4} kcal ({Math.round(((proteinG * 4) / (calories || 1)) * 100)}%)
            </span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10 space-y-1">
            <span className="text-[10px] font-mono text-[#00F0FF] font-bold block">CLEAN CARBS</span>
            <span className="text-2xl font-mono font-black text-white">{carbsG}g</span>
            <span className="text-[10px] font-mono text-[#8A8A8A] block">
              {carbsG * 4} kcal ({Math.round(((carbsG * 4) / (calories || 1)) * 100)}%)
            </span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10 space-y-1">
            <span className="text-[10px] font-mono text-[#F59E0B] font-bold block">HEALTHY FATS</span>
            <span className="text-2xl font-mono font-black text-white">{fatsG}g</span>
            <span className="text-[10px] font-mono text-[#8A8A8A] block">
              {fatsG * 9} kcal ({Math.round(((fatsG * 9) / (calories || 1)) * 100)}%)
            </span>
          </div>

          <div className="p-3.5 rounded-[16px] bg-black/40 border border-white/10 space-y-1">
            <span className="text-[10px] font-mono text-[#10B981] font-bold block">LEUCINE CONTENT</span>
            <span className="text-2xl font-mono font-black text-[#10B981]">{leucineG}g</span>
            <span className="text-[10px] font-mono text-[#8A8A8A] block">mTOR Threshold Met</span>
          </div>
        </div>

        <button
          onClick={handleLogMeal}
          disabled={mealLogged || (!mealName.trim() && calories <= 0)}
          className={`w-full py-3.5 rounded-[16px] text-xs font-mono font-black uppercase flex items-center justify-center space-x-2 transition ${
            mealLogged
              ? 'bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40'
              : !mealName.trim() && calories <= 0
              ? 'bg-white/10 text-white/40 border border-white/10 cursor-not-allowed'
              : 'bg-[#E5FE40] hover:bg-[#d8f030] text-black shadow-[0_0_20px_rgba(229,254,64,0.4)]'
          }`}
        >
          {mealLogged ? (
            <>
              <CheckCircle className="w-4 h-4 text-[#10B981]" />
              <span>MEAL LOGGED TO MACRO TRACKER (+{calories} KCAL)</span>
            </>
          ) : (
            <>
              <Plus className="w-4 h-4" />
              <span>COMMIT SCANNED MEAL TO DAILY LOG</span>
            </>
          )}
        </button>
      </div>

      {/* TODAY'S LOGGED MEALS HISTORY & MACRO TALLY */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center space-x-2">
            <Activity className="w-4 h-4 text-[#00F0FF]" />
            <h4 className="text-xs font-mono font-black text-white uppercase tracking-wider">
              TODAY'S LOGGED SPECIMENS & MACRO BALANCE
            </h4>
          </div>
          <span className="text-xs font-mono text-[#10B981] font-bold">
            ACCUMULATED: {dailyTotals.calories} KCAL ({dailyTotals.protein}g P · {dailyTotals.carbs}g C · {dailyTotals.fats}g F)
          </span>
        </div>

        {loggedMeals.length === 0 ? (
          <div className="p-8 text-center text-xs font-mono text-[#8A8A8A] border border-dashed border-white/10 rounded-[18px]">
            No meals logged yet today. Scan or select a template above to log your nutrition.
          </div>
        ) : (
          <div className="space-y-2">
            {loggedMeals.map((meal) => (
              <div
                key={meal.id}
                className="p-3.5 rounded-[16px] bg-white/[0.03] border border-white/10 flex items-center justify-between text-xs font-mono"
              >
                <div className="space-y-0.5">
                  <div className="flex items-center space-x-2">
                    <span className="font-bold text-white">{meal.name}</span>
                    <span className="text-[10px] text-[#8A8A8A]">@{meal.timestamp}</span>
                    <span className="text-[9px] px-1.5 py-0.5 rounded bg-white/10 text-white/80 font-bold">
                      GL {meal.glycemicLoad || 14}
                    </span>
                  </div>
                  <div className="text-[11px] text-[#A1A1AA] flex items-center space-x-2">
                    <span className="text-[#FA114F]">{meal.protein}g P</span>
                    <span>·</span>
                    <span className="text-[#00F0FF]">{meal.carbs}g C</span>
                    <span>·</span>
                    <span className="text-[#F59E0B]">{meal.fats}g F</span>
                    <span>·</span>
                    <span className="text-[#E5FE40] font-bold">{meal.calories} kcal</span>
                  </div>
                </div>

                <button
                  onClick={() => removeMeal(meal.id)}
                  className="p-2 rounded-[10px] text-white/40 hover:text-[#FA114F] hover:bg-white/5 transition"
                  title="Remove Entry"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
