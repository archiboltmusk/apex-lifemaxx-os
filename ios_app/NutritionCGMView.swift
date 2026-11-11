import SwiftUI
import AVFoundation
@preconcurrency import Vision
import PhotosUI
import Charts
import Combine

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
    public var photoData: Data?
    public var photoFileName: String? = nil

    public var estimatedLeucineG: Double {
        ((proteinG * 0.088) * 10).rounded() / 10
    }

    public var estimatedGlycemicLoad: Double {
        let netCarbs = max(0, carbsG - fiberG)
        let weight = sugarG > 10 ? 0.65 : (fiberG >= 5 ? 0.42 : 0.52)
        return (netCarbs * weight).rounded()
    }

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
        date: Date = Date(),
        photoData: Data? = nil,
        photoFileName: String? = nil
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
        self.photoData = photoData
        self.photoFileName = photoFileName
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

public struct DailySupplement: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var doseLabel: String
    public var timing: String
    public var takenDayKeys: [String]
}

public struct CaffeineIntakeEvent: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let mg: Double
}

public struct HydrationCaffeineDay: Identifiable, Codable {
    public var id: String { day }
    public let day: String
    public var waterMl: Double
    public var caffeineMg: Double
}

@MainActor
public final class NutritionLogStore: ObservableObject {
    public static let shared = NutritionLogStore()

    @Published public var meals: [LoggedFoodEntry] = []
    @Published public var recipes: [CustomRecipe] = []
    @Published public var waterMlToday: Double = 0
    @Published public var caffeineMgToday: Double = 0
    @Published public var caffeineEvents: [CaffeineIntakeEvent] = []
    @Published public var hydrationHistory: [HydrationCaffeineDay] = []
    @Published public var supplements: [DailySupplement] = []
    @Published public var glut4SecondsRemaining: Int = 0
    @Published public var isGlut4TimerRunning: Bool = false

    @AppStorage("apex_calorie_target") public var calorieTarget: Double = 2400
    @AppStorage("apex_protein_target") public var proteinTargetG: Double = 175
    @AppStorage("apex_fiber_target") public var fiberTargetG: Double = 32
    @AppStorage("apex_water_target_ml") public var waterTargetMl: Double = 3000

    private let mealsKey = "apex_ios_logged_meals_v1"
    private let recipesKey = "apex_ios_custom_recipes_v1"
    private let dailyMetaKey = "apex_ios_hydration_caffeine_v1"
    private let caffeineEventsKey = "apex_caffeine_events_v1"
    private let hydrationHistKey = "apex_hydration_caffeine_history_v1"
    private let supplementsKey = "apex_supplements_v1"
    private var glut4Cancellable: AnyCancellable?

    private init() {
        load()
        glut4Cancellable = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self, self.isGlut4TimerRunning else { return }
            if self.glut4SecondsRemaining > 1 {
                self.glut4SecondsRemaining -= 1
            } else {
                self.glut4SecondsRemaining = 0
                self.isGlut4TimerRunning = false
                Haptics.success()
            }
        }
    }

    public func ensureDayIsCurrent() {
        let today = Self.todayDayKey()
        if let storedDay = UserDefaults.standard.string(forKey: "apex_ios_hydration_day_v1"), storedDay != today {
            waterMlToday = 0
            caffeineMgToday = 0
            persistMeta()
        }
    }

    public var todaysMeals: [LoggedFoodEntry] {
        let cal = Calendar.current
        return meals.filter { cal.isDateInToday($0.date) }
    }

    public var recentMeals7Days: [LoggedFoodEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return meals.filter { $0.date >= cutoff }
    }

    public var todayCalories: Double { todaysMeals.reduce(0) { $0 + $1.calories } }
    public var todayProtein: Double { todaysMeals.reduce(0) { $0 + $1.proteinG } }
    public var todayCarbs: Double { todaysMeals.reduce(0) { $0 + $1.carbsG } }
    public var todayFat: Double { todaysMeals.reduce(0) { $0 + $1.fatG } }
    public var todayFiber: Double { todaysMeals.reduce(0) { $0 + $1.fiberG } }
    public var todaySugar: Double { todaysMeals.reduce(0) { $0 + $1.sugarG } }
    public var todaySodiumMg: Double { todaysMeals.reduce(0) { $0 + $1.sodiumMg } }

    /// Real 5.7h half-life pharmacokinetics summed across recent caffeine doses.
    public var activeCaffeineRemainingMg: Double {
        let now = Date()
        let cutoff = now.addingTimeInterval(-36 * 3600)
        return caffeineEvents
            .filter { $0.timestamp >= cutoff && $0.timestamp <= now }
            .reduce(0.0) { total, ev in
                let elapsedHrs = now.timeIntervalSince(ev.timestamp) / 3600.0
                return total + ApexBiometricMath.caffeineRemainingMg(intakeMg: ev.mg, hoursElapsed: elapsedHrs)
            }
    }

    public func caffeineAtHourOffset(_ hoursFromNow: Double) -> Double {
        let targetDate = Date().addingTimeInterval(hoursFromNow * 3600.0)
        let cutoff = targetDate.addingTimeInterval(-36 * 3600)
        return caffeineEvents
            .filter { $0.timestamp >= cutoff && $0.timestamp <= targetDate }
            .reduce(0.0) { total, ev in
                let elapsedHrs = targetDate.timeIntervalSince(ev.timestamp) / 3600.0
                return total + ApexBiometricMath.caffeineRemainingMg(intakeMg: ev.mg, hoursElapsed: elapsedHrs)
            }
    }

    // Bevel Nutrition Quality Score (0–100) computed strictly from logged meals today
    public var nutritionQualityScore: Int? {
        guard !todaysMeals.isEmpty else { return nil }
        let wholeFoodCount = todaysMeals.filter {
            $0.sourceEngine.contains("Describe") || $0.sourceEngine.contains("Recipe") || ($0.fiberG >= 3 && $0.sugarG < 12)
        }.count
        let wholeFoodRatio = Double(wholeFoodCount) / Double(todaysMeals.count)
        return ApexBiometricMath.nutritionQualityScore(
            calories: todayCalories,
            calorieTarget: calorieTarget,
            proteinG: todayProtein,
            proteinTargetG: proteinTargetG,
            fiberG: todayFiber,
            fiberTargetG: fiberTargetG,
            sugarG: todaySugar,
            wholeFoodRatio: wholeFoodRatio,
            mealCount: todaysMeals.count
        )
    }

    public func startPostprandialGlut4Walk() {
        glut4SecondsRemaining = 15 * 60
        isGlut4TimerRunning = true
        Haptics.tap(.medium)
    }

    public func stopPostprandialGlut4Walk() {
        isGlut4TimerRunning = false
        glut4SecondsRemaining = 0
    }

    public func isSupplementTakenToday(_ sup: DailySupplement) -> Bool {
        sup.takenDayKeys.contains(Self.todayDayKey())
    }

    public func toggleSupplement(_ id: UUID) {
        let today = Self.todayDayKey()
        guard let idx = supplements.firstIndex(where: { $0.id == id }) else { return }
        if let pos = supplements[idx].takenDayKeys.firstIndex(of: today) {
            supplements[idx].takenDayKeys.remove(at: pos)
        } else {
            supplements[idx].takenDayKeys.append(today)
            supplements[idx].takenDayKeys = Array(supplements[idx].takenDayKeys.suffix(30))
        }
        persistSupplements()
    }

    public func addSupplement(name: String, dose: String, timing: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        supplements.append(DailySupplement(id: UUID(), name: clean, doseLabel: dose.isEmpty ? "1 serving" : dose, timing: timing.isEmpty ? "Daily" : timing, takenDayKeys: []))
        persistSupplements()
    }

    public func deleteSupplement(_ id: UUID) {
        supplements.removeAll { $0.id == id }
        persistSupplements()
    }

    public func logMeal(_ entry: LoggedFoodEntry, health: HealthKitManager) {
        var cleanEntry = entry
        if let rawData = entry.photoData, entry.photoFileName == nil {
            cleanEntry.photoFileName = savePhotoToDisk(rawData, id: entry.id)
            cleanEntry.photoData = nil
        }
        meals.insert(cleanEntry, at: 0)
        persistMeals()
        syncToMac(health: health, addedMeal: cleanEntry)
        Task {
            await health.logNutritionToHealth(
                calories: cleanEntry.calories,
                proteinG: cleanEntry.proteinG,
                carbsG: cleanEntry.carbsG,
                fatG: cleanEntry.fatG,
                fiberG: cleanEntry.fiberG,
                sugarG: cleanEntry.sugarG,
                sodiumMg: cleanEntry.sodiumMg,
                date: cleanEntry.date
            )
        }
    }

    public func loadMealImage(for entry: LoggedFoodEntry) -> UIImage? {
        if let file = entry.photoFileName,
           let url = photosDirectory()?.appendingPathComponent(file),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        if let data = entry.photoData, let img = UIImage(data: data) {
            return img
        }
        return nil
    }

    public func addWater(ml: Double, health: HealthKitManager) {
        ensureDayIsCurrent()
        waterMlToday = max(0, waterMlToday + ml)
        persistMeta()
        syncToMac(health: health)
        if ml > 0 {
            Task {
                await health.logNutritionToHealth(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, waterMl: ml)
            }
        }
    }

    public func addCaffeine(mg: Double, health: HealthKitManager) {
        ensureDayIsCurrent()
        if mg < 0 {
            caffeineMgToday = max(0, caffeineMgToday + mg)
            if !caffeineEvents.isEmpty {
                caffeineEvents.removeFirst()
                persistCaffeineEvents()
            }
            persistMeta()
            syncToMac(health: health)
            return
        }
        caffeineMgToday += mg
        caffeineEvents.insert(CaffeineIntakeEvent(id: UUID(), timestamp: Date(), mg: mg), at: 0)
        persistCaffeineEvents()
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
        if let existing = meals.first(where: { $0.id == id }),
           let file = existing.photoFileName,
           let url = photosDirectory()?.appendingPathComponent(file) {
            try? FileManager.default.removeItem(at: url)
        }
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
                "sodiumMg": Int(todaySodiumMg),
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
                "sodiumMg": Int(meal.sodiumMg),
                "source": meal.sourceEngine,
                "date": ISO8601DateFormatter().string(from: meal.date)
            ]
        }
        health.syncEventToMac(extraPayload: extra)
    }

    public func reloadFromDisk() {
        load()
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: mealsKey),
           let dec = try? JSONDecoder().decode([LoggedFoodEntry].self, from: d) {
            meals = dec.map { item in
                if let rawData = item.photoData, item.photoFileName == nil {
                    var migrated = item
                    migrated.photoFileName = savePhotoToDisk(rawData, id: item.id)
                    migrated.photoData = nil
                    return migrated
                }
                return item
            }
        }
        if let d = UserDefaults.standard.data(forKey: recipesKey),
           let dec = try? JSONDecoder().decode([CustomRecipe].self, from: d) {
            recipes = dec
        }
        if let d = UserDefaults.standard.data(forKey: caffeineEventsKey),
           let dec = try? JSONDecoder().decode([CaffeineIntakeEvent].self, from: d) {
            caffeineEvents = dec
        }
        if let d = UserDefaults.standard.data(forKey: hydrationHistKey),
           let dec = try? JSONDecoder().decode([HydrationCaffeineDay].self, from: d) {
            hydrationHistory = dec
        }
        if let d = UserDefaults.standard.data(forKey: supplementsKey),
           let dec = try? JSONDecoder().decode([DailySupplement].self, from: d) {
            supplements = dec
        } else {
            supplements = [
                DailySupplement(id: UUID(), name: "Creatine Monohydrate", doseLabel: "5 g", timing: "Morning / Post-Workout", takenDayKeys: []),
                DailySupplement(id: UUID(), name: "Omega-3 EPA/DHA", doseLabel: "2,000 mg", timing: "With Meal", takenDayKeys: []),
                DailySupplement(id: UUID(), name: "Vitamin D3 + K2", doseLabel: "4,000 IU", timing: "Morning w/ Fat", takenDayKeys: []),
                DailySupplement(id: UUID(), name: "Magnesium Glycinate", doseLabel: "300 mg", timing: "Evening Wind-Down", takenDayKeys: [])
            ]
            persistSupplements()
        }

        let today = Self.todayDayKey()
        if let dict = UserDefaults.standard.dictionary(forKey: dailyMetaKey),
           let dayStr = dict["day"] as? String,
           dayStr == today {
            waterMlToday = dict["waterMl"] as? Double ?? 0
            caffeineMgToday = dict["caffeineMg"] as? Double ?? 0
            UserDefaults.standard.set(today, forKey: "apex_ios_hydration_day_v1")
            UserDefaults.standard.set(waterMlToday, forKey: "apex_ios_water_today_v1")
            UserDefaults.standard.set(caffeineMgToday, forKey: "apex_ios_caffeine_today_v1")
        } else {
            waterMlToday = 0
            caffeineMgToday = 0
            UserDefaults.standard.set(today, forKey: "apex_ios_hydration_day_v1")
            UserDefaults.standard.set(0.0, forKey: "apex_ios_water_today_v1")
            UserDefaults.standard.set(0.0, forKey: "apex_ios_caffeine_today_v1")
        }
    }

    private func photosDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("apex_meal_photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func savePhotoToDisk(_ data: Data, id: UUID) -> String? {
        let name = "\(id.uuidString).jpg"
        guard let url = photosDirectory()?.appendingPathComponent(name) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    private func persistMeals() {
        let stripped = meals.prefix(80).map { entry -> LoggedFoodEntry in
            var copy = entry
            copy.photoData = nil
            return copy
        }
        if let d = try? JSONEncoder().encode(stripped) {
            UserDefaults.standard.set(d, forKey: mealsKey)
        }
    }

    private func persistCaffeineEvents() {
        let cutoff = Date().addingTimeInterval(-72 * 3600)
        let recent = Array(caffeineEvents.filter { $0.timestamp >= cutoff }.prefix(40))
        if let d = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(d, forKey: caffeineEventsKey)
        }
    }

    private func persistSupplements() {
        if let d = try? JSONEncoder().encode(supplements) {
            UserDefaults.standard.set(d, forKey: supplementsKey)
        }
    }

    private func persistMeta() {
        let today = Self.todayDayKey()
        UserDefaults.standard.set([
            "day": today,
            "waterMl": waterMlToday,
            "caffeineMg": caffeineMgToday
        ], forKey: dailyMetaKey)
        UserDefaults.standard.set(today, forKey: "apex_ios_hydration_day_v1")
        UserDefaults.standard.set(waterMlToday, forKey: "apex_ios_water_today_v1")
        UserDefaults.standard.set(caffeineMgToday, forKey: "apex_ios_caffeine_today_v1")

        if let idx = hydrationHistory.firstIndex(where: { $0.day == today }) {
            hydrationHistory[idx].waterMl = waterMlToday
            hydrationHistory[idx].caffeineMg = caffeineMgToday
        } else {
            hydrationHistory.insert(HydrationCaffeineDay(day: today, waterMl: waterMlToday, caffeineMg: caffeineMgToday), at: 0)
        }
        hydrationHistory = Array(hydrationHistory.prefix(14))
        if let d = try? JSONEncoder().encode(hydrationHistory) {
            UserDefaults.standard.set(d, forKey: hydrationHistKey)
        }
    }

    private static func todayDayKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
}

// MARK: - Deterministic Describe-Meal & Label OCR Engines
// `DescribeMealParser` lives in `ApexSharedTypes.swift` for shared app + automated test coverage.

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

// MARK: - On-Device Vision Plate Macro Recognizer & Meal Thumbnail Compression
public enum MealPlateVisionEstimator {
    private struct PlatePreset {
        let keywords: [String]
        let label: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
        let sugar: Double
    }

    private static let catalog: [PlatePreset] = [
        PlatePreset(keywords: ["salad", "caesar", "greens", "vegetable"], label: "Mixed Salad Bowl", calories: 380, protein: 24, carbs: 22, fat: 22, fiber: 7, sugar: 6),
        PlatePreset(keywords: ["steak", "meat", "beef", "roast"], label: "Grilled Steak Plate", calories: 560, protein: 48, carbs: 8, fat: 36, fiber: 2, sugar: 1),
        PlatePreset(keywords: ["salmon", "fish", "seafood", "sushi"], label: "Salmon / Seafood Plate", calories: 470, protein: 38, carbs: 26, fat: 22, fiber: 3, sugar: 3),
        PlatePreset(keywords: ["chicken", "poultry", "turkey"], label: "Grilled Chicken Meal", calories: 440, protein: 46, carbs: 24, fat: 14, fiber: 3, sugar: 2),
        PlatePreset(keywords: ["egg", "omelette", "omelet", "breakfast"], label: "Egg Breakfast Plate", calories: 350, protein: 24, carbs: 14, fat: 22, fiber: 2, sugar: 2),
        PlatePreset(keywords: ["rice", "grain", "bowl", "burrito"], label: "Protein Grain Bowl", calories: 580, protein: 34, carbs: 64, fat: 18, fiber: 8, sugar: 4),
        PlatePreset(keywords: ["oatmeal", "porridge", "cereal", "yogurt"], label: "Oats / Yogurt Bowl", calories: 360, protein: 22, carbs: 46, fat: 9, fiber: 7, sugar: 12),
        PlatePreset(keywords: ["pasta", "spaghetti", "noodle", "ramen"], label: "Pasta / Noodle Bowl", calories: 610, protein: 24, carbs: 84, fat: 18, fiber: 5, sugar: 6),
        PlatePreset(keywords: ["sandwich", "burger", "taco", "wrap"], label: "Sandwich / Wrap Plate", calories: 540, protein: 28, carbs: 46, fat: 26, fiber: 4, sugar: 6),
        PlatePreset(keywords: ["pizza", "flatbread"], label: "Pizza / Flatbread", calories: 640, protein: 26, carbs: 72, fat: 28, fiber: 4, sugar: 7),
        PlatePreset(keywords: ["fruit", "berry", "banana", "apple"], label: "Fresh Fruit Plate", calories: 165, protein: 2, carbs: 40, fat: 0.5, fiber: 6, sugar: 24),
        PlatePreset(keywords: ["soup", "stew", "broth"], label: "Hearty Soup Bowl", calories: 320, protein: 20, carbs: 34, fat: 11, fiber: 5, sugar: 4)
    ]

    public static func makeThumbnailData(from image: UIImage) -> Data? {
        let maxDim: CGFloat = 220
        let scale = min(1.0, maxDim / max(image.size.width, image.size.height, 1))
        let newSize = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.65)
    }

    public static func recognizePlate(from image: UIImage) async -> (entry: LoggedFoodEntry, didMatchFood: Bool, detectedTag: String?) {
        let thumbData = makeThumbnailData(from: image)
        guard let cg = image.cgImage else {
            return (LoggedFoodEntry(name: "", calories: 0, proteinG: 0, carbsG: 0, fatG: 0, sourceEngine: "Plate Photo · Enter Macros", photoData: thumbData), false, nil)
        }

        let observations: [VNClassificationObservation] = await withCheckedContinuation { continuation in
            let req = VNClassifyImageRequest { request, _ in
                let results = (request.results as? [VNClassificationObservation]) ?? []
                continuation.resume(returning: Array(results.prefix(12)))
            }
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([req])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }

        let confident = observations.filter { $0.confidence >= 0.20 }
        for obs in confident {
            let ident = obs.identifier.lowercased()
            if let preset = catalog.first(where: { entry in entry.keywords.contains(where: { ident.contains($0) }) }) {
                let entry = LoggedFoodEntry(
                    name: preset.label,
                    calories: preset.calories,
                    proteinG: preset.protein,
                    carbsG: preset.carbs,
                    fatG: preset.fat,
                    fiberG: preset.fiber,
                    sugarG: preset.sugar,
                    sourceEngine: "Vision Plate AI · \(Int((obs.confidence * 100).rounded()))%",
                    photoData: thumbData
                )
                return (entry, true, obs.identifier)
            }
        }

        let topLabel = confident.first?.identifier.replacingOccurrences(of: "_", with: " ").capitalized
        let draft = LoggedFoodEntry(
            name: topLabel ?? "",
            calories: 0,
            proteinG: 0,
            carbsG: 0,
            fatG: 0,
            sourceEngine: "Plate Photo · Verify Macros",
            photoData: thumbData
        )
        return (draft, false, topLabel)
    }
}

// MARK: - Bevel Fuel / Nutrition & CGM Tab View
public struct NutritionCGMView: View {
    @ObservedObject private var store = NutritionLogStore.shared
    @ObservedObject private var health = HealthKitManager.shared
    @AppStorage(ApexUnitPreferences.unitKey) private var unitSystemRaw: String = ApexUnitSystem.metric.rawValue

    @State private var showBarcodeSheet = false
    @State private var showDescribeSheet = false
    @State private var showRecipeSheet = false
    @State private var showGlucoseLogSheet = false
    @State private var showPlateCameraSheet = false
    @State private var showLabelCameraSheet = false
    @State private var showLabelSourceDialog = false
    @State private var showLabelPhotosPicker = false
    @State private var showGoalsSheet = false
    @State private var showAddSupplementSheet = false
    @State private var showSevenDayMeals = false
    @State private var selectedLabelPhoto: PhotosPickerItem? = nil
    @State private var selectedPlatePhoto: PhotosPickerItem? = nil
    @State private var scannedDraft: LoggedFoodEntry? = nil
    @State private var statusBanner: String? = nil

    public init() {}

    public var body: some View {
        let _ = unitSystemRaw
        return NavigationStack {
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
                    if store.activeCaffeineRemainingMg >= 1.0 || store.caffeineMgToday > 0 {
                        caffeineHalfLifeCard
                    }
                    cgmGlucoseCard
                    supplementsCard
                    todaysMealsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(ApexTheme.background)
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                store.ensureDayIsCurrent()
            }
            .photosPicker(isPresented: $showLabelPhotosPicker, selection: $selectedLabelPhoto, matching: .images)
            .confirmationDialog("Scan Nutrition Label", isPresented: $showLabelSourceDialog) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Label Photo") { showLabelCameraSheet = true }
                }
                Button("Choose from Photos") { showLabelPhotosPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: selectedLabelPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await handleLabelImage(img)
                    }
                    selectedLabelPhoto = nil
                }
            }
            .onChange(of: selectedPlatePhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await handlePlateImage(img)
                    }
                    selectedPlatePhoto = nil
                }
            }
            .sheet(item: $scannedDraft) { draft in
                MealReviewEditSheet(entry: draft) { final in
                    store.logMeal(final, health: health)
                    Haptics.success()
                }
            }
            .sheet(isPresented: $showPlateCameraSheet) {
                PlateCameraCaptureSheet(sourceType: .camera) { captured in
                    Task { await handlePlateImage(captured) }
                }
            }
            .sheet(isPresented: $showLabelCameraSheet) {
                PlateCameraCaptureSheet(sourceType: .camera) { captured in
                    Task { await handleLabelImage(captured) }
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
            .sheet(isPresented: $showGoalsSheet) {
                NutritionGoalsSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddSupplementSheet) {
                AddSupplementSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func handleLabelImage(_ image: UIImage) async {
        if let parsed = await NutritionLabelOCREngine.recognizeLabel(from: image) {
            scannedDraft = parsed
        } else {
            statusBanner = "Could not detect nutrition label rows — try Describe Meal or Manual Entry."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { statusBanner = nil }
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
                    Button {
                        Haptics.tap()
                        showGoalsSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("/ \(Int(store.calorieTarget)) goal")
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(ApexTheme.standCyan)
                    }
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
                Text("Sugar: \(Int(store.todaySugar.rounded()))g · Sodium: \(Int(store.todaySodiumMg.rounded()))mg across \(store.todaysMeals.count) item(s)")
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

    private func handlePlateImage(_ image: UIImage) async {
        let result = await MealPlateVisionEstimator.recognizePlate(from: image)
        if !result.didMatchFood {
            statusBanner = result.detectedTag.map {
                "Plate photo saved (\($0)). Enter exact macros before saving."
            } ?? "Plate photo saved. Enter meal name & macros before saving."
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { statusBanner = nil }
        }
        scannedDraft = result.entry
    }

    private var captureActionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            PhotosPicker(selection: $selectedPlatePhoto, matching: .images) {
                captureTile(icon: "camera.metering.center.weighted", title: "Plate AI Photo", sub: "Vision macro + thumb", tint: ApexTheme.accentVolt)
            }
            .buttonStyle(.plain)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    Haptics.tap(.medium)
                    showPlateCameraSheet = true
                } label: {
                    captureTile(icon: "camera.fill", title: "Snap Plate Cam", sub: "Live plate capture", tint: ApexTheme.exerciseLime)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Haptics.tap(.medium)
                    scannedDraft = LoggedFoodEntry(name: "", calories: 0, proteinG: 0, carbsG: 0, fatG: 0, sourceEngine: "Quick Manual Entry")
                } label: {
                    captureTile(icon: "plus.circle.fill", title: "Quick Log", sub: "Manual meal macros", tint: ApexTheme.exerciseLime)
                }
                .buttonStyle(.plain)
            }

            Button {
                Haptics.tap(.medium)
                showBarcodeSheet = true
            } label: {
                captureTile(icon: "barcode.viewfinder", title: "Scan Barcode", sub: "UPC / OpenFoodFacts", tint: ApexTheme.standCyan)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap(.medium)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showLabelSourceDialog = true
                } else {
                    showLabelPhotosPicker = true
                }
            } label: {
                captureTile(icon: "text.viewfinder", title: "Label OCR", sub: "Camera or photo scan", tint: ApexTheme.accentIndigo)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap(.medium)
                showDescribeSheet = true
            } label: {
                captureTile(icon: "text.bubble.fill", title: "Describe Meal", sub: "Natural gram parser", tint: ApexTheme.accentEmerald)
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
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Water")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("/ \(ApexUnitPreferences.formatVolume(ml: store.waterTargetMl))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Text(ApexUnitPreferences.formatVolume(ml: store.waterMlToday))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ApexTheme.standCyan)
                    HStack(spacing: 6) {
                        Button("-250") {
                            Haptics.tap()
                            store.addWater(ml: -250, health: health)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(ApexTheme.elevatedSurface)
                        .clipShape(Capsule())
                        .disabled(store.waterMlToday <= 0)

                        Button("+250") {
                            Haptics.tap()
                            store.addWater(ml: 250, health: health)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(ApexTheme.standCyan)
                        .clipShape(Capsule())

                        Button("+500") {
                            Haptics.tap()
                            store.addWater(ml: 500, health: health)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(ApexTheme.standCyan.opacity(0.85))
                        .clipShape(Capsule())
                    }
                }
                .appleCard(padding: 14, cornerRadius: 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Caffeine")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(Int(store.caffeineMgToday)) mg")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ApexTheme.accentAmber)
                    HStack(spacing: 6) {
                        Button("-50") {
                            Haptics.tap()
                            store.addCaffeine(mg: -50, health: health)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ApexTheme.elevatedSurface)
                        .clipShape(Capsule())
                        .disabled(store.caffeineMgToday <= 0)

                        Button("+100mg") {
                            Haptics.tap()
                            store.addCaffeine(mg: 100, health: health)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ApexTheme.accentAmber)
                        .clipShape(Capsule())
                    }
                }
                .appleCard(padding: 14, cornerRadius: 18)
            }
        }
    }

    private var caffeineHalfLifeCard: some View {
        let nowMg = store.activeCaffeineRemainingMg
        let sleepMg = store.caffeineAtHourOffset(10)
        let points: [(hour: Int, mg: Double)] = stride(from: 0, through: 12, by: 2).map { h in
            (h, store.caffeineAtHourOffset(Double(h)))
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("5.7h Caffeine Clearance Curve")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Active serum: \(Int(nowMg.rounded())) mg · In 10h: \(Int(sleepMg.rounded())) mg")
                        .font(.system(size: 12))
                        .foregroundStyle(sleepMg > 35 ? ApexTheme.accentAmber : ApexTheme.accentEmerald)
                }
                Spacer()
                Text(sleepMg > 35 ? "Avoid late caffeine" : "Clear for sleep")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sleepMg > 35 ? ApexTheme.accentAmber : ApexTheme.accentEmerald)
                    .clipShape(Capsule())
            }

            if points.contains(where: { $0.mg > 0 }) {
                Chart(points, id: \.hour) { pt in
                    AreaMark(
                        x: .value("Hours", pt.hour),
                        y: .value("mg", pt.mg)
                    )
                    .foregroundStyle(ApexTheme.accentAmber.opacity(0.22))
                    LineMark(
                        x: .value("Hours", pt.hour),
                        y: .value("mg", pt.mg)
                    )
                    .foregroundStyle(ApexTheme.accentAmber)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                .chartXAxisLabel("Hours from now")
                .frame(height: 82)
            }
        }
        .appleCard(padding: 16, cornerRadius: 20)
    }

    private var cgmGlucoseCard: some View {
        let unitLabel = ApexUnitPreferences.glucoseUnitLabel
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Glucose & Meal Spike")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    if let latest = health.glucoseSamples24h.last {
                        Text("Latest: \(ApexUnitPreferences.formatGlucose(mgDl: latest.value)) · \(latest.label)")
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
                    Text("Log \(unitLabel)")
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
                        let val = ApexUnitPreferences.glucoseValue(mgDl: pt.value)
                        LineMark(
                            x: .value("Time", pt.date),
                            y: .value(unitLabel, val)
                        )
                        .foregroundStyle(ApexTheme.accentIndigo)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        PointMark(
                            x: .value("Time", pt.date),
                            y: .value(unitLabel, val)
                        )
                        .foregroundStyle(pt.value > 140 ? ApexTheme.accentAmber : ApexTheme.accentEmerald)
                    }
                    RuleMark(y: .value("Post-Meal Threshold", ApexUnitPreferences.glucoseValue(mgDl: 140)))
                        .foregroundStyle(ApexTheme.accentAmber.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .frame(height: 130)
            } else {
                Text("No blood glucose samples in Apple Health over the last 24h. Sync a Dexcom/Libre CGM to HealthKit or tap Log \(unitLabel) to track post-meal excursion.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // 15-Minute Postprandial GLUT4 Walk Timer
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(ApexTheme.exerciseLime)
                if store.isGlut4TimerRunning {
                    let mins = store.glut4SecondsRemaining / 60
                    let secs = store.glut4SecondsRemaining % 60
                    Text(String(format: "GLUT4 Walk · %02d:%02d left", mins, secs))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Stop") {
                        store.stopPostprandialGlut4Walk()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ApexTheme.accentAmber)
                } else {
                    Text("15m Postprandial GLUT4 Walk")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Start 15:00") {
                        store.startPostprandialGlut4Walk()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ApexTheme.exerciseLime)
                    .clipShape(Capsule())
                }
            }
            .padding(10)
            .background(ApexTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var supplementsCard: some View {
        let takenCount = store.supplements.filter { store.isSupplementTakenToday($0) }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Supplement Dispensary")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(takenCount)/\(store.supplements.count) completed today")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Haptics.tap()
                    showAddSupplementSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ApexTheme.standCyan)
                        .clipShape(Capsule())
                }
            }

            ForEach(store.supplements) { sup in
                let isTaken = store.isSupplementTakenToday(sup)
                HStack {
                    Button {
                        Haptics.tap(.medium)
                        store.toggleSupplement(sup.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isTaken ? ApexTheme.exerciseLime : .secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sup.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(sup.doseLabel) · \(sup.timing)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.deleteSupplement(sup.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(ApexTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .appleCard(padding: 18, cornerRadius: 22)
    }

    private var todaysMealsSection: some View {
        let shownMeals = showSevenDayMeals ? store.recentMeals7Days : store.todaysMeals
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(showSevenDayMeals ? "7-Day Food History" : "Today's Food Log")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(showSevenDayMeals ? "Today Only" : "7D History") {
                    Haptics.selection()
                    showSevenDayMeals.toggle()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

                Button {
                    scannedDraft = LoggedFoodEntry(name: "", calories: 0, proteinG: 0, carbsG: 0, fatG: 0, sourceEngine: "Manual Entry")
                } label: {
                    Text("+ Manual")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ApexTheme.standCyan)
                }
            }

            if shownMeals.isEmpty {
                Text(showSevenDayMeals ? "0 meals logged in the past 7 days." : "0 meals logged today.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .appleCard(padding: 16, cornerRadius: 18)
            } else {
                ForEach(shownMeals) { meal in
                    HStack(spacing: 12) {
                        if let img = store.loadMealImage(for: meal) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(meal.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                if meal.estimatedLeucineG >= 2.5 {
                                    Text("mTOR \(String(format: "%.1f", meal.estimatedLeucineG))g Leu")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(ApexTheme.exerciseLime)
                                        .clipShape(Capsule())
                                }
                            }
                            let glText = meal.carbsG > 0 ? " · GL \(Int(meal.estimatedGlycemicLoad))" : ""
                            Text("\(Int(meal.proteinG))g P · \(Int(meal.carbsG))g C · \(Int(meal.fatG))g F\(glText) · \(meal.sourceEngine)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(meal.calories)) kcal")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(ApexTheme.accentVolt)
                            Button {
                                Haptics.tap()
                                store.deleteMeal(meal.id, health: health)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .appleCard(padding: 14, cornerRadius: 16)
                }
            }
        }
    }
}

private struct NutritionGoalsSheet: View {
    @ObservedObject private var store = NutritionLogStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Targets") {
                    Stepper("Calories: \(Int(store.calorieTarget)) kcal", value: $store.calorieTarget, in: 1200...5000, step: 50)
                    Stepper("Protein: \(Int(store.proteinTargetG)) g", value: $store.proteinTargetG, in: 60...320, step: 5)
                    Stepper("Fiber: \(Int(store.fiberTargetG)) g", value: $store.fiberTargetG, in: 15...80, step: 1)
                    Stepper("Hydration: \(ApexUnitPreferences.formatVolume(ml: store.waterTargetMl))", value: $store.waterTargetMl, in: 1500...6000, step: 250)
                }
            }
            .navigationTitle("Nutrition Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct AddSupplementSheet: View {
    @ObservedObject private var store = NutritionLogStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dose = ""
    @State private var timing = "Morning"

    var body: some View {
        NavigationStack {
            Form {
                Section("New Supplement") {
                    TextField("Name (e.g. L-Theanine)", text: $name)
                    TextField("Dose (e.g. 200 mg)", text: $dose)
                    Picker("Timing", selection: $timing) {
                        ForEach(["Morning", "Pre-Workout", "With Meal", "Evening Wind-Down"], id: \.self) { Text($0) }
                    }
                }
                Section {
                    Button("Save Supplement") {
                        store.addSupplement(name: name, dose: dose, timing: timing)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(ApexTheme.accentVolt)
                }
            }
            .navigationTitle("Add Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
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
                    let sodiumGrams = (nut["sodium_serving"] as? Double) ?? (nut["sodium_100g"] as? Double) ?? 0
                    let sodiumMg = (sodiumGrams * 1000.0).rounded()
                    await MainActor.run {
                        isLoading = false
                        onFound(LoggedFoodEntry(name: name, calories: kcal.rounded(), proteinG: pro, carbsG: carb, fatG: fat, fiberG: fiber, sugarG: sugar, sodiumMg: sodiumMg, sourceEngine: "Barcode · OpenFoodFacts"))
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
                } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No catalog ingredients matched yet — try weights like \"2 eggs 150g white rice\" or use Manual Entry.")
                        .font(.system(size: 12))
                        .foregroundStyle(ApexTheme.accentAmber)
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
                .disabled(preview.matchedItems.isEmpty)
                .opacity(preview.matchedItems.isEmpty ? 0.45 : 1.0)
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
                if let img = NutritionLogStore.shared.loadMealImage(for: entry) {
                    Section("Captured Meal Photo") {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                Section("Food Details (\(entry.sourceEngine))") {
                    TextField("Meal Name", text: $entry.name)
                    HStack { Text("Calories"); Spacer(); TextField("0", value: $entry.calories, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Protein (g)"); Spacer(); TextField("0", value: $entry.proteinG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Carbs (g)"); Spacer(); TextField("0", value: $entry.carbsG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Fat (g)"); Spacer(); TextField("0", value: $entry.fatG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Fiber (g)"); Spacer(); TextField("0", value: $entry.fiberG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Sugars (g)"); Spacer(); TextField("0", value: $entry.sugarG, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Sodium (mg)"); Spacer(); TextField("0", value: $entry.sodiumMg, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
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
    @AppStorage(ApexUnitPreferences.unitKey) private var unitRaw: String = ApexUnitSystem.metric.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var displayGlucose: Double = ApexUnitPreferences.glucoseValue(mgDl: 95)

    var body: some View {
        let _ = unitRaw
        let unitLabel = ApexUnitPreferences.glucoseUnitLabel
        return NavigationStack {
            Form {
                Section("Blood Glucose Reading (\(unitLabel))") {
                    TextField(unitLabel, value: $displayGlucose, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Button("Save to Apple Health") {
                        let mgDl = ApexUnitPreferences.mgDlFromGlucoseInput(displayGlucose)
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

private struct PlateCameraCaptureSheet: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .camera
    var onCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PlateCameraCaptureSheet
        init(parent: PlateCameraCaptureSheet) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onCaptured(img)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
