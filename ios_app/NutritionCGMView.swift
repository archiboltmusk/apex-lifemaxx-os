import SwiftUI
import AVFoundation
import Vision
import PhotosUI
import Charts

// MARK: - Bevel Nutrition, Barcode / Label OCR, Recipes & CGM Engine Models
public struct LoggedFoodEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var calories: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double
    public var sugarG: Double
    public var sodiumMg: Double
    public var sourceEngine: String
    public var date: Date

    public init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double = 0,
        sugarG: Double = 0,
        sodiumMg: Double = 0,
        sourceEngine: String,
        date: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
        self.sourceEngine = sourceEngine
        self.date = date
    }
}

public struct CustomRecipe: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var calories: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double
    public var sugarG: Double
}

@MainActor
public final class NutritionLogStore: ObservableObject {
    public static let shared = NutritionLogStore()

    @Published public var meals: [LoggedFoodEntry] = []
    @Published public var recipes: [CustomRecipe] = []
    @Published public var waterMlToday: Double = 0
    @Published public var caffeineMgToday: Double = 0

    @AppStorage("apex_calorie_target") public var calorieTarget: Double = 2400
    @AppStorage("apex_protein_target") public var proteinTargetG: Double = 175
    @AppStorage("apex_fiber_target") public var fiberTargetG: Double = 32

    private let mealsKey = "apex_ios_logged_meals_v1"
    private let recipesKey = "apex_ios_custom_recipes_v1"
    private let dailyMetaKey = "apex_ios_hydration_caffeine_v1"

    private init() {
        load()
    }

    public var todaysMeals: [LoggedFoodEntry] {
        let cal = Calendar.current
        return meals.filter { cal.isDateInToday($0.date) }
    }

    public var todayCalories: Double { todaysMeals.reduce(0) { $0 + $1.calories } }
    public var todayProtein: Double { todaysMeals.reduce(0) { $0 + $1.proteinG } }
    public var todayCarbs: Double { todaysMeals.reduce(0) { $0 + $1.carbsG } }
    public var todayFat: Double { todaysMeals.reduce(0) { $0 + $1.fatG } }
    public var todayFiber: Double { todaysMeals.reduce(0) { $0 + $1.fiberG } }
    public var todaySugar: Double { todaysMeals.reduce(0) { $0 + $1.sugarG } }

    // Bevel Nutrition Quality Score (0–100) computed strictly from logged meals today
    public var nutritionQualityScore: Int? {
        guard !todaysMeals.isEmpty else { return nil }
        let calRatio = calorieTarget > 0 ? min(1.2, todayCalories / calorieTarget) : 1.0
        let proteinRatio = min(1.0, todayProtein / max(60.0, proteinTargetG))
        let fiberRatio = min(1.0, todayFiber / max(15.0, fiberTargetG))
        let sugarPenalty = max(0.0, (todaySugar - 38.0) * 0.45)
        let wholeFoodCount = todaysMeals.filter {
            $0.sourceEngine.contains("Describe") || $0.sourceEngine.contains("Recipe") || ($0.fiberG >= 3 && $0.sugarG < 12)
        }.count
        let wholeFoodRatio = Double(wholeFoodCount) / Double(todaysMeals.count)

        let raw = 28.0
            + proteinRatio * 34.0
            + fiberRatio * 18.0
            + wholeFoodRatio * 15.0
            + (calRatio >= 0.7 && calRatio <= 1.15 ? 5.0 : 0.0)
            - sugarPenalty
        return Int(max(12, min(100, raw.rounded())))
    }

    public func logMeal(_ entry: LoggedFoodEntry, health: HealthKitManager) {
        meals.insert(entry, at: 0)
        persistMeals()
        syncToMac(health: health, addedMeal: entry)
        Task {
            await health.logNutritionToHealth(
                calories: entry.calories,
                proteinG: entry.proteinG,
                carbsG: entry.carbsG,
                fatG: entry.fatG,
                fiberG: entry.fiberG,
                sugarG: entry.sugarG,
                date: entry.date
            )
        }
    }

    public func addWater(ml: Double, health: HealthKitManager) {
        waterMlToday += ml
        persistMeta()
        syncToMac(health: health)
        Task {
            await health.logNutritionToHealth(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, waterMl: ml)
        }
    }

    public func addCaffeine(mg: Double, health: HealthKitManager) {
        caffeineMgToday += mg
        persistMeta()
        syncToMac(health: health)
        Task {
            await health.logNutritionToHealth(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, caffeineMg: mg)
        }
    }

    public func saveRecipe(_ recipe: CustomRecipe) {
        recipes.insert(recipe, at: 0)
        if let d = try? JSONEncoder().encode(recipes) {
            UserDefaults.standard.set(d, forKey: recipesKey)
        }
    }

    public func deleteMeal(_ id: UUID, health: HealthKitManager) {
        meals.removeAll { $0.id == id }
        persistMeals()
        syncToMac(health: health)
    }

    private func syncToMac(health: HealthKitManager, addedMeal: LoggedFoodEntry? = nil) {
        var extra: [String: Any] = [
            "nutritionSummary": [
                "calories": Int(todayCalories),
                "protein": Int(todayProtein),
                "carbs": Int(todayCarbs),
                "fat": Int(todayFat),
                "fiber": Int(todayFiber),
                "sugar": Int(todaySugar),
                "waterL": (waterMlToday / 1000.0 * 10).rounded() / 10,
                "caffeineMg": Int(caffeineMgToday),
                "qualityScore": nutritionQualityScore ?? 0,
                "mealCount": todaysMeals.count
            ]
        ]
        if let meal = addedMeal {
            extra["mealEntry"] = [
                "id": meal.id.uuidString,
                "name": meal.name,
                "calories": Int(meal.calories),
                "protein": Int(meal.proteinG),
                "carbs": Int(meal.carbsG),
                "fat": Int(meal.fatG),
                "fiber": Int(meal.fiberG),
                "sugar": Int(meal.sugarG),
                "source": meal.sourceEngine,
                "date": ISO8601DateFormatter().string(from: meal.date)
            ]
        }
        health.syncEventToMac(extraPayload: extra)
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: mealsKey),
           let dec = try? JSONDecoder().decode([LoggedFoodEntry].self, from: d) {
            meals = dec
        }
        if let d = UserDefaults.standard.data(forKey: recipesKey),
           let dec = try? JSONDecoder().decode([CustomRecipe].self, from: d) {
            recipes = dec
        }
        if let dict = UserDefaults.standard.dictionary(forKey: dailyMetaKey),
           let dayStr = dict["day"] as? String,
           dayStr == Self.todayDayKey() {
            waterMlToday = dict["waterMl"] as? Double ?? 0
            caffeineMgToday = dict["caffeineMg"] as? Double ?? 0
        }
    }

    private func persistMeals() {
        if let d = try? JSONEncoder().encode(Array(meals.prefix(80))) {
            UserDefaults.standard.set(d, forKey: mealsKey)
        }
    }

    private func persistMeta() {
        UserDefaults.standard.set([
            "day": Self.todayDayKey(),
            "waterMl": waterMlToday,
            "caffeineMg": caffeineMgToday
        ], forKey: dailyMetaKey)
    }

    private static func todayDayKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
}

// MARK: - Deterministic Describe-Meal & Label OCR Engines
public enum DescribeMealParser {
    private struct FoodRef {
        let aliases: [String]
        let label: String
        let per100gCal: Double
        let per100gPro: Double
        let per100gCarb: Double
        let per100gFat: Double
        let per100gFiber: Double
        let per100gSugar: Double
        let defaultServingGrams: Double
    }

    private static let table: [FoodRef] = [
        FoodRef(aliases: ["chicken breast", "chicken"], label: "Chicken Breast", per100gCal: 165, per100gPro: 31, per100gCarb: 0, per100gFat: 3.6, per100gFiber: 0, per100gSugar: 0, defaultServingGrams: 170),
        FoodRef(aliases: ["salmon"], label: "Wild Salmon", per100gCal: 208, per100gPro: 20.4, per100gCarb: 0, per100gFat: 13.4, per100gFiber: 0, per100gSugar: 0, defaultServingGrams: 170),
        FoodRef(aliases: ["ribeye", "steak", "beef"], label: "Lean Steak / Beef", per100gCal: 250, per100gPro: 26, per100gCarb: 0, per100gFat: 15, per100gFiber: 0, per100gSugar: 0, defaultServingGrams: 180),
        FoodRef(aliases: ["egg", "eggs"], label: "Whole Eggs", per100gCal: 143, per100gPro: 12.6, per100gCarb: 0.7, per100gFat: 9.5, per100gFiber: 0, per100gSugar: 0.4, defaultServingGrams: 50),
        FoodRef(aliases: ["egg white", "egg whites"], label: "Egg Whites", per100gCal: 52, per100gPro: 11, per100gCarb: 0.7, per100gFat: 0.2, per100gFiber: 0, per100gSugar: 0.7, defaultServingGrams: 100),
        FoodRef(aliases: ["white rice", "rice"], label: "Cooked White Rice", per100gCal: 130, per100gPro: 2.7, per100gCarb: 28.2, per100gFat: 0.3, per100gFiber: 0.4, per100gSugar: 0.1, defaultServingGrams: 160),
        FoodRef(aliases: ["oats", "oatmeal"], label: "Rolled Oats (Dry)", per100gCal: 389, per100gPro: 16.9, per100gCarb: 66.3, per100gFat: 6.9, per100gFiber: 10.6, per100gSugar: 0.9, defaultServingGrams: 60),
        FoodRef(aliases: ["greek yogurt", "yogurt"], label: "Nonfat Greek Yogurt", per100gCal: 59, per100gPro: 10.2, per100gCarb: 3.6, per100gFat: 0.4, per100gFiber: 0, per100gSugar: 3.2, defaultServingGrams: 170),
        FoodRef(aliases: ["whey", "protein shake", "protein powder"], label: "Whey Protein Isolate", per100gCal: 370, per100gPro: 83, per100gCarb: 3, per100gFat: 1.5, per100gFiber: 0, per100gSugar: 1.5, defaultServingGrams: 30),
        FoodRef(aliases: ["avocado"], label: "Avocado", per100gCal: 160, per100gPro: 2, per100gCarb: 8.5, per100gFat: 14.7, per100gFiber: 6.7, per100gSugar: 0.7, defaultServingGrams: 100),
        FoodRef(aliases: ["banana"], label: "Banana", per100gCal: 89, per100gPro: 1.1, per100gCarb: 22.8, per100gFat: 0.3, per100gFiber: 2.6, per100gSugar: 12.2, defaultServingGrams: 118),
        FoodRef(aliases: ["blueberries", "berries"], label: "Blueberries", per100gCal: 57, per100gPro: 0.7, per100gCarb: 14.5, per100gFat: 0.3, per100gFiber: 2.4, per100gSugar: 10, defaultServingGrams: 100),
        FoodRef(aliases: ["sweet potato"], label: "Baked Sweet Potato", per100gCal: 90, per100gPro: 2, per100gCarb: 20.7, per100gFat: 0.2, per100gFiber: 3.3, per100gSugar: 6.5, defaultServingGrams: 150),
        FoodRef(aliases: ["broccoli", "spinach", "greens", "salad"], label: "Broccoli / Greens", per100gCal: 34, per100gPro: 2.8, per100gCarb: 6.6, per100gFat: 0.4, per100gFiber: 2.6, per100gSugar: 1.7, defaultServingGrams: 120),
        FoodRef(aliases: ["olive oil", "butter"], label: "Extra Virgin Olive Oil", per100gCal: 884, per100gPro: 0, per100gCarb: 0, per100gFat: 100, per100gFiber: 0, per100gSugar: 0, defaultServingGrams: 14),
        FoodRef(aliases: ["almonds", "nuts", "walnuts"], label: "Mixed Nuts / Almonds", per100gCal: 579, per100gPro: 21.2, per100gCarb: 21.6, per100gFat: 49.9, per100gFiber: 12.5, per100gSugar: 4.4, defaultServingGrams: 28),
        FoodRef(aliases: ["bread", "sourdough", "toast"], label: "Sourdough Bread", per100gCal: 266, per100gPro: 9, per100gCarb: 52, per100gFat: 1.8, per100gFiber: 2.7, per100gSugar: 2.5, defaultServingGrams: 60),
        FoodRef(aliases: ["paneer", "tofu"], label: "Paneer / Cottage Cheese", per100gCal: 265, per100gPro: 18, per100gCarb: 3, per100gFat: 20, per100gFiber: 0, per100gSugar: 2, defaultServingGrams: 100)
    ]

    public static func parse(_ text: String) -> (matchedItems: [String], calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, sugar: Double) {
        let lower = text.lowercased()
        var matched: [String] = []
        var cal = 0.0, pro = 0.0, carb = 0.0, fat = 0.0, fib = 0.0, sug = 0.0

        for item in table {
            guard let hitAlias = item.aliases.first(where: { lower.contains($0) }) else { continue }
            var grams = item.defaultServingGrams

            // Detect preceding "<num>g <alias>" or "<num> <alias>" (count multiplier for pieces like "3 eggs")
            if let range = lower.range(of: "(\\d+(?:\\.\\d+)?)\\s*(g|gram|grams|oz|tbsp|cup|scoop)?\\s*\(NSRegularExpression.escapedPattern(for: hitAlias))", options: .regularExpression) {
                let snippet = String(lower[range])
                let numStr = snippet.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
                if let qty = Double(numStr), qty > 0 {
                    if snippet.contains("g") { grams = qty }
                    else if snippet.contains("oz") { grams = qty * 28.35 }
                    else if snippet.contains("tbsp") { grams = qty * 14.0 }
                    else if snippet.contains("scoop") { grams = qty * 30.0 }
                    else if snippet.contains("cup") { grams = qty * 160.0 }
                    else { grams = qty * item.defaultServingGrams }
                }
            }

            let factor = grams / 100.0
            cal += item.per100gCal * factor
            pro += item.per100gPro * factor
            carb += item.per100gCarb * factor
            fat += item.per100gFat * factor
            fib += item.per100gFiber * factor
            sug += item.per100gSugar * factor
            matched.append("\(Int(grams.rounded()))g \(item.label)")
        }

        return (matched, cal.rounded(), (pro * 10).rounded() / 10, (carb * 10).rounded() / 10, (fat * 10).rounded() / 10, (fib * 10).rounded() / 10, (sug * 10).rounded() / 10)
    }
}

public enum NutritionLabelOCREngine {
    public static func recognizeLabel(from image: UIImage) async -> LoggedFoodEntry? {
        guard let cgImage = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let req = VNRecognizeTextRequest { request, _ in
                let obs = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = obs.compactMap { $0.topCandidates(1).first?.string }
                let fullText = lines.joined(separator: "\n")
                let parsed = parseNutritionText(fullText)
                continuation.resume(returning: parsed)
            }
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([req])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func parseNutritionText(_ text: String) -> LoggedFoodEntry? {
        func extractNumber(near pattern: String) -> Double? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[r])
        }

        let cal = extractNumber(near: "calories\\D{0,12}(\\d{2,4})") ?? 0
        let pro = extractNumber(near: "protein\\D{0,12}(\\d{1,3}(?:\\.\\d+)?)") ?? 0
        let carb = extractNumber(near: "(?:total\\s+carb(?:ohydrate)?s?|carbs?)\\D{0,12}(\\d{1,3}(?:\\.\\d+)?)") ?? 0
        let fat = extractNumber(near: "(?:total\\s+)?fat\\D{0,12}(\\d{1,3}(?:\\.\\d+)?)") ?? 0
        let fiber = extractNumber(near: "dietary\\s+fiber\\D{0,12}(\\d{1,2}(?:\\.\\d+)?)") ?? 0
        let sugar = extractNumber(near: "(?:total\\s+)?sugars?\\D{0,12}(\\d{1,3}(?:\\.\\d+)?)") ?? 0
        let sodium = extractNumber(near: "sodium\\D{0,12}(\\d{1,4})") ?? 0

        guard cal > 0 || pro > 0 || carb > 0 || fat > 0 else { return nil }
        let finalCal = cal > 0 ? cal : (pro * 4 + carb * 4 + fat * 9).rounded()
        return LoggedFoodEntry(
            name: "Scanned Nutrition Label",
            calories: finalCal,
            proteinG: pro,
            carbsG: carb,
            fatG: fat,
            fiberG: fiber,
            sugarG: sugar,
            sodiumMg: sodium,
            sourceEngine: "Vision Nutrition Label OCR"
        )
    }
}

// MARK: - Bevel Fuel / Nutrition & CGM Tab View
public struct NutritionCGMView: View {
    @ObservedObject private var store = NutritionLogStore.shared
    @ObservedObject private var health = HealthKitManager.shared

    @State private var showBarcodeSheet = false
    @State private var showDescribeSheet = false
    @State private var showRecipeSheet = false
    @State private var showGlucoseLogSheet = false
    @State private var selectedLabelPhoto: PhotosPickerItem? = nil
    @State private var scannedDraft: LoggedFoodEntry? = nil
    @State private var statusBanner: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let banner = statusBanner {
                        Text(banner)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ApexTheme.accentVolt)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    nutritionScoreHeroCard
                    captureActionsGrid
                    hydrationCaffeineBar
                    cgmGlucoseCard
                    todaysMealsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(ApexTheme.background)
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: selectedLabelPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data),
                       let parsed = await NutritionLabelOCREngine.recognizeLabel(from: img) {
                        scannedDraft = parsed
                    } else {
                        statusBanner = "Could not detect nutrition label rows — try Describe Meal or Manual Entry."
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { statusBanner = nil }
                    }
                    selectedLabelPhoto = nil
                }
            }
            .sheet(item: $scannedDraft) { draft in
                MealReviewEditSheet(entry: draft) { final in
                    store.logMeal(final, health: health)
                    Haptics.success()
                }
            }
            .sheet(isPresented: $showBarcodeSheet) {
                BarcodeScannerLookupSheet { found in
                    showBarcodeSheet = false
                    scannedDraft = found
                }
            }
            .sheet(isPresented: $showDescribeSheet) {
                DescribeMealSheet { parsed in
                    showDescribeSheet = false
                    scannedDraft = parsed
                }
            }
            .sheet(isPresented: $showRecipeSheet) {
                RecipeBuilderSheet()
            }
            .sheet(isPresented: $showGlucoseLogSheet) {
                LogGlucoseSheet()
            }
        }
    }

    private var nutritionScoreHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NUTRITION QUALITY SCORE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ApexTheme.exerciseLime)
                    Text(store.nutritionQualityScore.map { "\($0) / 100" } ?? "Awaiting First Meal")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(store.todayCalories)) kcal")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ApexTheme.accentVolt)
                    Text("/ \(Int(store.calorieTarget)) goal")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                macroPill("Protein", store.todayProtein, "g", store.proteinTargetG, ApexTheme.moveCrimson)
                macroPill("Carbs", store.todayCarbs, "g", nil, ApexTheme.standCyan)
                macroPill("Fat", store.todayFat, "g", nil, ApexTheme.accentAmber)
                macroPill("Fiber", store.todayFiber, "g", store.fiberTargetG, ApexTheme.accentEmerald)
            }

            if store.todaysMeals.isEmpty {
                Text("Log via Barcode Scan, Label OCR, Describe Meal, or Custom Recipe to compute today's nutrient quality & sugar restraint score.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Sugar today: \(Int(store.todaySugar.rounded()))g across \(store.todaysMeals.count) logged item(s)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(store.todaySugar > 45 ? ApexTheme.accentAmber : .secondary)
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private func macroPill(_ name: String, _ val: Double, _ unit: String, _ target: Double?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(Int(val.rounded()))\(unit)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            if let t = target {
                Text("/\(Int(t))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(ApexTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var captureActionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            Button {
                Haptics.tap(.medium)
                showBarcodeSheet = true
            } label: {
                captureTile(icon: "barcode.viewfinder", title: "Scan Barcode", sub: "UPC / OpenFoodFacts", tint: ApexTheme.accentVolt)
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $selectedLabelPhoto, matching: .images) {
                captureTile(icon: "text.viewfinder", title: "Label OCR", sub: "Scan Nutrition Facts", tint: ApexTheme.standCyan)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap(.medium)
                showDescribeSheet = true
            } label: {
                captureTile(icon: "text.bubble.fill", title: "Describe Meal", sub: "Natural gram parser", tint: ApexTheme.exerciseLime)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap(.medium)
                showRecipeSheet = true
            } label: {
                captureTile(icon: "book.closed.fill", title: "Recipes", sub: "\(store.recipes.count) saved", tint: ApexTheme.accentAmber)
            }
            .buttonStyle(.plain)
        }
    }

    private func captureTile(icon: String, title: String, sub: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .appleCard(padding: 14, cornerRadius: 18)
    }

    private var hydrationCaffeineBar: some View {
        HStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Water")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f L", store.waterMlToday / 1000.0))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ApexTheme.standCyan)
                }
                Spacer()
                Button("+500ml") {
                    Haptics.tap()
                    store.addWater(ml: 500, health: health)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ApexTheme.standCyan)
                .clipShape(Capsule())
            }
            .appleCard(padding: 14, cornerRadius: 18)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Caffeine")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(Int(store.caffeineMgToday)) mg")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ApexTheme.accentAmber)
                }
                Spacer()
                Button("+100") {
                    Haptics.tap()
                    store.addCaffeine(mg: 100, health: health)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ApexTheme.accentAmber)
                .clipShape(Capsule())
            }
            .appleCard(padding: 14, cornerRadius: 18)
        }
    }

    private var cgmGlucoseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Glucose & Meal Spike")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    if let latest = health.glucoseSamples24h.last {
                        Text("Latest: \(Int(latest.value)) mg/dL · \(latest.label)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(latest.value > 140 ? ApexTheme.accentAmber : ApexTheme.accentEmerald)
                    } else {
                        Text("Reads Apple Health CGM or fingerstick readings")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Haptics.tap()
                    showGlucoseLogSheet = true
                } label: {
                    Text("Log mg/dL")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ApexTheme.accentVolt)
                        .clipShape(Capsule())
                }
            }

            if health.glucoseSamples24h.count >= 2 {
                Chart {
                    ForEach(health.glucoseSamples24h) { pt in
                        LineMark(
                            x: .value("Time", pt.date),
                            y: .value("mg/dL", pt.value)
                        )
                        .foregroundStyle(ApexTheme.accentIndigo)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        PointMark(
                            x: .value("Time", pt.date),
                            y: .value("mg/dL", pt.value)
                        )
                        .foregroundStyle(pt.value > 140 ? ApexTheme.accentAmber : ApexTheme.accentEmerald)
                    }
                    RuleMark(y: .value("Post-Meal Threshold", 140))
                        .foregroundStyle(ApexTheme.accentAmber.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .frame(height: 130)
            } else {
                Text("No blood glucose samples in Apple Health over the last 24h. Sync a Dexcom/Libre CGM to HealthKit or tap Log mg/dL to track post-meal excursion.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var todaysMealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Food Log")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    scannedDraft = LoggedFoodEntry(name: "", calories: 0, proteinG: 0, carbsG: 0, fatG: 0, sourceEngine: "Manual Entry")
                } label: {
                    Text("+ Manual")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ApexTheme.standCyan)
                }
            }

            if store.todaysMeals.isEmpty {
                Text("0 meals logged today.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .appleCard(padding: 16, cornerRadius: 18)
            } else {
                ForEach(store.todaysMeals) { meal in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(meal.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(Int(meal.proteinG))g P · \(Int(meal.carbsG))g C · \(Int(meal.fatG))g F · \(meal.sourceEngine)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(Int(meal.calories)) kcal")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(ApexTheme.accentVolt)
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }
            }
        }
    }
}

// MARK: - Barcode Scanner & OpenFoodFacts Live Lookup
private struct BarcodeScannerLookupSheet: View {
    var onFound: (LoggedFoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var manualBarcode: String = ""
    @State private var isLoading = false
    @State private var errorMsg: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                BarcodeCameraView { code in
                    if !isLoading {
                        lookupBarcode(code)
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 10) {
                    TextField("Or enter UPC / EAN barcode...", text: $manualBarcode)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(ApexTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("Lookup") {
                        lookupBarcode(manualBarcode)
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(ApexTheme.accentVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(manualBarcode.trimmingCharacters(in: .whitespaces).count < 6 || isLoading)
                }

                if isLoading {
                    ProgressView("Querying OpenFoodFacts database...")
                }
                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(ApexTheme.accentAmber)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(16)
            .background(ApexTheme.background)
            .navigationTitle("Barcode Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
        }
    }

    private func lookupBarcode(_ code: String) {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(clean).json") else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 6.0
                let (data, _) = try await URLSession.shared.data(for: req)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let product = json["product"] as? [String: Any],
                   let nut = product["nutriments"] as? [String: Any] {
                    let name = (product["product_name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Barcode \(clean)"
                    let kcal = (nut["energy-kcal_serving"] as? Double) ?? (nut["energy-kcal_100g"] as? Double) ?? 0
                    let pro = (nut["proteins_serving"] as? Double) ?? (nut["proteins_100g"] as? Double) ?? 0
                    let carb = (nut["carbohydrates_serving"] as? Double) ?? (nut["carbohydrates_100g"] as? Double) ?? 0
                    let fat = (nut["fat_serving"] as? Double) ?? (nut["fat_100g"] as? Double) ?? 0
                    let fiber = (nut["fiber_serving"] as? Double) ?? (nut["fiber_100g"] as? Double) ?? 0
                    let sugar = (nut["sugars_serving"] as? Double) ?? (nut["sugars_100g"] as? Double) ?? 0
                    await MainActor.run {
                        isLoading = false
                        onFound(LoggedFoodEntry(name: name, calories: kcal.rounded(), proteinG: pro, carbsG: carb, fatG: fat, fiberG: fiber, sugarG: sugar, sourceEngine: "Barcode · OpenFoodFacts"))
                    }
                    return
                }
                await MainActor.run {
                    isLoading = false
                    errorMsg = "Barcode \(clean) not found — enter manually or scan the Nutrition Facts label."
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMsg = "Network unavailable for barcode lookup. Use Label OCR or Describe Meal offline."
                }
            }
        }
    }
}

private struct BarcodeCameraView: UIViewControllerRepresentable {
    var onCodeDetected: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        let vc = BarcodeScannerVC()
        vc.onDetect = onCodeDetected
        return vc
    }
    func updateUIViewController(_ uiViewController: BarcodeScannerVC, context: Context) {}
}

private final class BarcodeScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onDetect: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.1, alpha: 1)
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            let lbl = UILabel()
            lbl.text = "Point iPhone camera at barcode\n(or type UPC below on Simulator)"
            lbl.numberOfLines = 2
            lbl.textAlignment = .center
            lbl.textColor = .secondaryLabel
            lbl.font = .systemFont(ofSize: 13, weight: .medium)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                lbl.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                lbl.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
                lbl.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
            ])
            return
        }
        session.addInput(input)
        let meta = AVCaptureMetadataOutput()
        if session.canAddOutput(meta) {
            session.addOutput(meta)
            meta.setMetadataObjectsDelegate(self, queue: .main)
            meta.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]
        }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        self.previewLayer = layer
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didEmit, let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let str = obj.stringValue else { return }
        didEmit = true
        Haptics.success()
        onDetect?(str)
    }
}

// MARK: - Describe Meal Sheet
private struct DescribeMealSheet: View {
    var onParsed: (LoggedFoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var preview: (matchedItems: [String], calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, sugar: Double) {
        DescribeMealParser.parse(text)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Type your ingredients & weights (e.g. \"200g chicken breast 160g white rice 1 tbsp olive oil 1 avocado\")")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .frame(height: 110)
                    .padding(10)
                    .background(ApexTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if !preview.matchedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Matched: \(preview.matchedItems.joined(separator: ", "))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ApexTheme.standCyan)
                        Text("\(Int(preview.calories)) kcal · \(Int(preview.protein))g P · \(Int(preview.carbs))g C · \(Int(preview.fat))g F · \(Int(preview.fiber))g Fiber")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }

                Button {
                    let p = preview
                    onParsed(LoggedFoodEntry(
                        name: text.trimmingCharacters(in: .whitespacesAndNewlines),
                        calories: p.calories,
                        proteinG: p.protein,
                        carbsG: p.carbs,
                        fatG: p.fat,
                        fiberG: p.fiber,
                        sugarG: p.sugar,
                        sourceEngine: "Describe Meal Parser"
                    ))
                } label: {
                    Text("Review & Log Meal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApexTheme.exerciseLime)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding(16)
            .background(ApexTheme.background)
            .navigationTitle("Describe Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

// MARK: - Custom Recipe Builder Sheet
private struct RecipeBuilderSheet: View {
    @ObservedObject private var store = NutritionLogStore.shared
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var cal: Double = 0
    @State private var pro: Double = 0
    @State private var carb: Double = 0
    @State private var fat: Double = 0
    @State private var fiber: Double = 0

    var body: some View {
        NavigationStack {
            List {
                Section("New Custom Recipe") {
                    TextField("Recipe Name (e.g. Protein Oats Bowl)", text: $name)
                    HStack { Text("Calories"); Spacer(); TextField("0", value: $cal, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Protein (g)"); Spacer(); TextField("0", value: $pro, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Carbs (g)"); Spacer(); TextField("0", value: $carb, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Fat (g)"); Spacer(); TextField("0", value: $fat, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Fiber (g)"); Spacer(); TextField("0", value: $fiber, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Button("Save Recipe") {
                        store.saveRecipe(CustomRecipe(id: UUID(), name: name, calories: cal, proteinG: pro, carbsG: carb, fatG: fat, fiberG: fiber, sugarG: 0))
                        name = ""; cal = 0; pro = 0; carb = 0; fat = 0; fiber = 0
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !store.recipes.isEmpty {
                    Section("Saved Recipes (Tap to Log Today)") {
                        ForEach(store.recipes) { rec in
                            Button {
                                store.logMeal(LoggedFoodEntry(
                                    name: rec.name,
                                    calories: rec.calories,
                                    proteinG: rec.proteinG,
                                    carbsG: rec.carbsG,
                                    fatG: rec.fatG,
                                    fiberG: rec.fiberG,
                                    sugarG: rec.sugarG,
                                    sourceEngine: "Saved Recipe"
                                ), health: health)
                                Haptics.success()
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(rec.name).foregroundStyle(.white)
                                        Text("\(Int(rec.proteinG))g P · \(Int(rec.carbsG))g C · \(Int(rec.fatG))g F").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(rec.calories)) kcal").foregroundStyle(ApexTheme.accentVolt)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Custom Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Review & Log Editable Meal Sheet & Manual Glucose Sheet
private struct MealReviewEditSheet: View {
    @State var entry: LoggedFoodEntry
    var onSave: (LoggedFoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Food Details (\(entry.sourceEngine))") {
                    TextField("Meal Name", text: $entry.name)
                    HStack { Text("Calories"); Spacer(); TextField("0", value: $entry.calories, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Protein (g)"); Spacer(); TextField("0", value: $entry.proteinG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Carbs (g)"); Spacer(); TextField("0", value: $entry.carbsG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Fat (g)"); Spacer(); TextField("0", value: $entry.fatG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Fiber (g)"); Spacer(); TextField("0", value: $entry.fiberG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Sugars (g)"); Spacer(); TextField("0", value: $entry.sugarG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Section {
                    Button("Save to Food Log & Apple Health") {
                        if entry.name.trimmingCharacters(in: .whitespaces).isEmpty {
                            entry.name = "Logged Meal"
                        }
                        onSave(entry)
                        dismiss()
                    }
                    .foregroundStyle(ApexTheme.accentVolt)
                }
            }
            .navigationTitle("Confirm Macros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct LogGlucoseSheet: View {
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mgDl: Double = 95

    var body: some View {
        NavigationStack {
            Form {
                Section("Blood Glucose Reading (mg/dL)") {
                    TextField("mg/dL", value: $mgDl, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Button("Save to Apple Health") {
                        Task {
                            await health.logGlucoseToHealth(mgPerDl: mgDl)
                            Haptics.success()
                            dismiss()
                        }
                    }
                    .foregroundStyle(ApexTheme.accentVolt)
                }
            }
            .navigationTitle("Log Glucose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
