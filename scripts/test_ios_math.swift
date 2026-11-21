import Foundation

func assertTrue(_ condition: Bool, _ msg: String) {
    if !condition {
        fputs("FAIL: \(msg)\n", stderr)
        exit(1)
    }
}

@main
struct ApexMathTestRunner {
    static func main() {
        // 1. Zero-input strict nil gates (no fake numbers when unrecorded)
        assertTrue(ApexBiometricMath.dailyStrain(moveKcal: 0, exerciseMinutes: 0) == nil, "Zero activity must yield nil strain")
        assertTrue(ApexBiometricMath.targetStrainRange(readiness: nil) == nil, "Nil readiness must yield nil target strain")
        assertTrue(ApexBiometricMath.energyBank(readiness: nil, strain: 12) == nil, "Nil readiness must yield nil energy bank")
        assertTrue(
            ApexBiometricMath.nutritionQualityScore(
                calories: 0, calorieTarget: 2400,
                proteinG: 0, proteinTargetG: 170,
                fiberG: 0, fiberTargetG: 30,
                sugarG: 0, wholeFoodRatio: 0, mealCount: 0
            ) == nil,
            "Zero meals must yield nil nutrition quality score"
        )

        // 2. Real Strain, Readiness Target Range & Energy Bank math
        let lowStrain = ApexBiometricMath.dailyStrain(moveKcal: 250, exerciseMinutes: 15)!
        let highStrain = ApexBiometricMath.dailyStrain(moveKcal: 950, exerciseMinutes: 75, strengthSetsBonus: 3)!
        assertTrue(lowStrain > 0 && lowStrain < highStrain && highStrain <= 21.0, "Strain should scale monotonically in 0...21")

        let lowReadyRange = ApexBiometricMath.targetStrainRange(readiness: 40)!
        let highReadyRange = ApexBiometricMath.targetStrainRange(readiness: 88)!
        assertTrue(highReadyRange.lowerBound > lowReadyRange.lowerBound, "Higher readiness must prescribe higher strain target")

        let bankNoNap = ApexBiometricMath.energyBank(readiness: 85, strain: 12.0, napHours: 0)!
        let bankWithNap = ApexBiometricMath.energyBank(readiness: 85, strain: 12.0, napHours: 0.5)!
        assertTrue(bankNoNap >= 5 && bankNoNap < 85 && bankWithNap > bankNoNap, "Energy bank drains with strain and recharges with naps")

        // 3. Brzycki 1RM & Nutrition Quality Score bounds
        let orm = ApexBiometricMath.brzycki1RM(weightKg: 100, reps: 5)
        assertTrue(abs(orm - 112.5) < 0.01, "100kg x 5 Brzycki 1RM should be 112.5")
        assertTrue(ApexBiometricMath.brzycki1RM(weightKg: 0, reps: 10) == 0, "Zero weight 1RM must be 0")

        let nScore = ApexBiometricMath.nutritionQualityScore(
            calories: 2250, calorieTarget: 2400,
            proteinG: 180, proteinTargetG: 175,
            fiberG: 34, fiberTargetG: 32,
            sugarG: 20, wholeFoodRatio: 1.0, mealCount: 3
        )!
        assertTrue(nScore >= 90 && nScore <= 100, "Optimal high-protein whole-food day should score 90..100")

        // 4. Metric vs Imperial Unit Preferences
        let prevUnit = ApexUnitPreferences.current
        ApexUnitPreferences.current = .metric
        assertTrue(ApexUnitPreferences.formatWeight(kg: 80.0) == "80.0 kg", "Metric weight formatting mismatch")
        assertTrue(ApexUnitPreferences.formatGlucose(mgDl: 95.0) == "95 mg/dL", "Metric glucose formatting mismatch")
        ApexUnitPreferences.current = .imperial
        assertTrue(ApexUnitPreferences.formatWeight(kg: 100.0).contains("lbs"), "Imperial weight formatting mismatch")
        assertTrue(ApexUnitPreferences.formatGlucose(mgDl: 90.091) == "5.0 mmol/L", "Imperial glucose mmol/L conversion mismatch")
        ApexUnitPreferences.current = prevUnit

        // 5. Widget Interactive App Group Queues (Drainable)
        _ = ApexSnapshotStore.consumePendingHydrationMl()
        _ = ApexSnapshotStore.consumePendingJournalTags()
        ApexSnapshotStore.queueHydrationIncrement(ml: 250)
        ApexSnapshotStore.queueHydrationIncrement(ml: 250)
        let drainedWater = ApexSnapshotStore.consumePendingHydrationMl()
        assertTrue(abs(drainedWater - 500.0) < 0.01, "Pending widget hydration queue should sum to 500 mL")
        assertTrue(ApexSnapshotStore.consumePendingHydrationMl() == 0, "Second consume should be empty")

        ApexSnapshotStore.queuePendingJournalTag("sunlight")
        ApexSnapshotStore.queuePendingJournalTag("sunlight")
        let tags = ApexSnapshotStore.consumePendingJournalTags()
        assertTrue(tags == ["sunlight"], "Duplicate widget tags same day should deduplicate")

        // 6. Pace of Aging & 5.7h Caffeine Pharmacokinetics
        assertTrue(
            ApexBiometricMath.paceOfAging(
                chronologicalAge: 32, biologicalAge: nil, clinicalPhenoAge: nil,
                hrv: nil, hrvBaseline: nil, rhr: nil, rhrBaseline: nil,
                vo2Max: nil, sleepEfficiencyPercent: nil
            ) == nil,
            "All-nil vitals must return nil pace of aging"
        )
        let youthfulPace = ApexBiometricMath.paceOfAging(
            chronologicalAge: 35, biologicalAge: 29, clinicalPhenoAge: 28,
            hrv: 78, hrvBaseline: 64, rhr: 48, rhrBaseline: 52,
            vo2Max: 56, sleepEfficiencyPercent: 93
        )!
        let fastPace = ApexBiometricMath.paceOfAging(
            chronologicalAge: 35, biologicalAge: 42, clinicalPhenoAge: 43,
            hrv: 32, hrvBaseline: 60, rhr: 66, rhrBaseline: 54,
            vo2Max: 35, sleepEfficiencyPercent: 76
        )!
        assertTrue(youthfulPace < 0.90 && fastPace > 1.05 && youthfulPace < fastPace, "Pace of aging must distinguish rejuvenated vs accelerated biomarkers")

        let halfLifeRem = ApexBiometricMath.caffeineRemainingMg(intakeMg: 200, hoursElapsed: 5.7)
        assertTrue(abs(halfLifeRem - 100.0) <= 0.2, "200mg caffeine after 5.7h half-life should be ~100mg (got \(halfLifeRem))")
        assertTrue(ApexBiometricMath.caffeineRemainingMg(intakeMg: 0, hoursElapsed: 2.0) == 0, "Zero intake yields 0 remaining")

        // 7. Round-trip Unit Conversions (Weight & Glucose)
        ApexUnitPreferences.current = .imperial
        assertTrue(ApexUnitPreferences.isImperial, "isImperial should reflect .imperial")
        let lbs = ApexUnitPreferences.weightValue(kg: 100.0)
        let kgBack = ApexUnitPreferences.kgFromWeightInput(lbs)
        assertTrue(abs(kgBack - 100.0) < 0.05, "Imperial weight round-trip mismatch")
        let mmol = ApexUnitPreferences.glucoseValue(mgDl: 108.0)
        let mgBack = ApexUnitPreferences.mgDlFromGlucoseInput(mmol)
        assertTrue(abs(mgBack - 108.0) < 0.1, "Imperial glucose round-trip mismatch")
        ApexUnitPreferences.current = prevUnit

        // 8. DescribeMealParser ("2 eggs" vs "2 egg whites" regex regression)
        let twoEggs = DescribeMealParser.parse("2 eggs")
        assertTrue(twoEggs.matchedItems == ["100g Whole Eggs"], "Expected '100g Whole Eggs', got \(twoEggs.matchedItems)")
        assertTrue(abs(twoEggs.calories - 143) <= 1, "2 eggs calorie mismatch")

        let twoWhites = DescribeMealParser.parse("2 egg whites and 150g chicken breast")
        assertTrue(
            twoWhites.matchedItems.contains("200g Egg Whites") && !twoWhites.matchedItems.contains { $0.contains("Whole Eggs") },
            "Egg whites must not double-match Whole Eggs: \(twoWhites.matchedItems)"
        )
        assertTrue(twoWhites.matchedItems.contains("150g Chicken Breast"), "150g chicken breast should parse as 150g")

        // 9. Lag-1 Next-Morning (D -> D+1) Causality Math
        let shifted = ApexBiometricMath.lag1ShiftedKeys(["2026-11-01", "2026-11-03"])
        assertTrue(shifted == ["2026-11-02", "2026-11-04"], "Lag-1 shifted keys mismatch: \(shifted)")
        let hrvMap = ["2026-11-02": 80.0, "2026-11-04": 88.0, "2026-11-05": 60.0, "2026-11-06": 60.0]
        let onVals = shifted.compactMap { hrvMap[$0] }
        let offVals = ["2026-11-05", "2026-11-06"].compactMap { hrvMap[$0] }
        let pctDelta = ApexBiometricMath.meanPercentDelta(onValues: onVals, offValues: offVals)!
        assertTrue(abs(pctDelta - 40.0) < 0.01, "Expected +40% Lag-1 HRV delta, got \(pctDelta)")
        let absDelta = ApexBiometricMath.meanAbsoluteDelta(onValues: [50.0, 52.0], offValues: [55.0, 57.0])!
        assertTrue(abs(absDelta - (-5.0)) < 0.01, "Expected -5.0 bpm RHR delta, got \(absDelta)")

        // 10. Acute:Chronic Workload Ratio (ACWR / Gabbett 2016 Model)
        let underAcwr = ApexBiometricMath.acwr(acute7dLoad: 7.0, chronic28dLoad: 12.0)
        assertTrue(underAcwr.ratio < 0.80 && underAcwr.zone == .underTraining, "ACWR < 0.8 must be .underTraining (got \(underAcwr.ratio))")
        let optimalAcwr = ApexBiometricMath.acwr(acute7dLoad: 11.5, chronic28dLoad: 11.0)
        assertTrue(optimalAcwr.ratio >= 0.80 && optimalAcwr.ratio <= 1.30 && optimalAcwr.zone == .optimal, "ACWR 0.8..1.3 must be .optimal (got \(optimalAcwr.ratio))")
        let overreachingAcwr = ApexBiometricMath.acwr(acute7dLoad: 15.0, chronic28dLoad: 10.5)
        assertTrue(overreachingAcwr.ratio > 1.30 && overreachingAcwr.ratio <= 1.50 && overreachingAcwr.zone == .overreaching, "ACWR 1.3..1.5 must be .overreaching (got \(overreachingAcwr.ratio))")
        let injuryAcwr = ApexBiometricMath.acwr(acute7dLoad: 18.0, chronic28dLoad: 10.0)
        assertTrue(injuryAcwr.ratio > 1.50 && injuryAcwr.zone == .injuryRisk, "ACWR > 1.50 must be .injuryRisk (got \(injuryAcwr.ratio))")

        // 11. Cardiovascular Age & Arterial Compliance Model
        let youthfulCardio = ApexBiometricMath.cardiovascularAge(chronologicalAge: 38, vo2Max: 54, rhr: 47, hrv: 82)
        assertTrue(youthfulCardio.cardiovascularAge < 38.0 && youthfulCardio.ageDelta <= -4.0 && youthfulCardio.elasticityStatus.contains("Youthful"), "Elite cardio markers must yield younger cardiovascular age (got \(youthfulCardio.cardiovascularAge))")
        let agedCardio = ApexBiometricMath.cardiovascularAge(chronologicalAge: 38, vo2Max: 32, rhr: 76, hrv: 28)
        assertTrue(agedCardio.cardiovascularAge > 38.0 && agedCardio.ageDelta > 1.0 && agedCardio.elasticityStatus.contains("Stiffness"), "Compromised cardio markers must yield older cardiovascular age (got \(agedCardio.cardiovascularAge))")

        // 12. Circadian Chronotype & Optimal Sleep Window
        let lark = ApexBiometricMath.circadianProfile(sleepMidpointHours: 2.5, regularityScore: 92)
        assertTrue(lark.chronotype == .earlyLark && lark.optimalBedtimeFormatted.contains("PM"), "Midpoint 2.5h should be Early Lark")
        let morning = ApexBiometricMath.circadianProfile(sleepMidpointHours: 3.25, regularityScore: 88)
        assertTrue(morning.chronotype == .morningType, "Midpoint 3.25h should be Morning Type")
        let owl = ApexBiometricMath.circadianProfile(sleepMidpointHours: 5.5, regularityScore: 75)
        assertTrue(owl.chronotype == .nightOwl && owl.optimalBedtimeFormatted.contains("AM"), "Midpoint 5.5h should be Night Owl")

        // 13. Adaptive Dynamic TDEE & Macro Coach (MacroFactor Model)
        let weightPts: [DailyMetricPoint] = [
            DailyMetricPoint(date: Date().addingTimeInterval(-86400 * 7), value: 80.0),
            DailyMetricPoint(date: Date().addingTimeInterval(-86400 * 6), value: 79.9),
            DailyMetricPoint(date: Date().addingTimeInterval(-86400 * 5), value: 79.7),
            DailyMetricPoint(date: Date().addingTimeInterval(-86400 * 1), value: 79.2),
            DailyMetricPoint(date: Date(), value: 79.0)
        ]
        let caloriePts: [DailyMetricPoint] = [
            DailyMetricPoint(date: Date().addingTimeInterval(-86400 * 7), value: 2100),
            DailyMetricPoint(date: Date().addingTimeInterval(-86400 * 6), value: 2050),
            DailyMetricPoint(date: Date().addingTimeInterval(-86400 * 5), value: 2150),
            DailyMetricPoint(date: Date().addingTimeInterval(-86400 * 1), value: 2000),
            DailyMetricPoint(date: Date(), value: 2100)
        ]
        let adaptive = ApexBiometricMath.adaptiveTDEE(
            weightHistory: weightPts,
            calorieHistory: caloriePts,
            fallbackBasalKcal: 1750,
            fallbackActiveKcal: 650,
            bodyWeightKg: 79.0
        )
        assertTrue(adaptive.calculatedTDEE >= 2400 && adaptive.calculatedTDEE <= 3600, "Adaptive TDEE with weight loss on 2100 kcal must detect deficit expenditure (got \(adaptive.calculatedTDEE))")
        assertTrue(adaptive.fatLossTargetKcal < adaptive.calculatedTDEE && adaptive.leanBulkTargetKcal > adaptive.calculatedTDEE, "Targets must scale around TDEE")
        assertTrue(adaptive.recommendedProteinG >= 150, "Protein recommendation must scale with body weight")

        // 14. Organ-by-Organ Longevity Scorecard (6 Pillars)
        let scorecard = ApexBiometricMath.organScorecard(
            chronologicalAge: 35,
            vo2Max: 52,
            rhr: 49,
            hrv: 76,
            fastingGlucoseMgDL: 82,
            hba1cPct: 5.1,
            activeKcal: 720,
            bodyFatPct: 14.5,
            deadHangSec: 105,
            spatialPostureScore: 92,
            crpMgL: 0.35,
            albuminGDL: 4.8,
            paceOfAging: 0.78,
            clinicalPhenoAge: 27.5
        )
        assertTrue(scorecard.pillars.count == 6, "Must compute all 6 organ longevity pillars")
        assertTrue(scorecard.compositeAge < 35.0, "Rejuvenated biometrics must yield composite age below chronological age (got \(scorecard.compositeAge))")
        for pillar in scorecard.pillars {
            assertTrue(!pillar.recommendation.isEmpty, "Every pillar must contain actionable recommendation")
        }

        print("ALL_SWIFT_BIOMETRIC_MATH_TESTS_PASSED")
    }
}
