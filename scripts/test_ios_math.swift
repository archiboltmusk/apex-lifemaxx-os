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

        print("ALL_SWIFT_BIOMETRIC_MATH_TESTS_PASSED")
    }
}
