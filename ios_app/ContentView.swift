import SwiftUI

public struct ContentView: View {
    @StateObject private var health = HealthKitManager.shared
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.025, blue: 0.035)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // TOP STATUS & DYNAMIC ISLAND
                HStack {
                    HStack(spacing: 8) {
                        Text("▲")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.black)
                            .padding(6)
                            .background(Color(red: 0.90, green: 1.0, blue: 0.25))
                            .cornerRadius(8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("APEX // OS")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text("APPLE HEALTHKIT LIVE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                        }
                    }

                    Spacer()

                    // Mac Sync Status Pill
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.06, green: 0.73, blue: 0.51))
                            .frame(width: 7, height: 7)
                        Text("LIVE MAC SYNC")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.15))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // MAIN CONTENT SCROLL
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. HEALTHKIT AUTHORIZATION CARD
                        if !health.isAuthorized {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Color(red: 0.98, green: 0.07, blue: 0.31))
                                    Text("Apple HealthKit Permission")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                Text("Connect to read real-time Apple Watch heart rates, active calories, and activity rings.")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)

                                Button(action: {
                                    health.requestAuthorization()
                                }) {
                                    HStack {
                                        Text("AUTHORIZE REAL-TIME HEALTHKIT")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.90, green: 1.0, blue: 0.25))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)
                        }

                        // 2. CONCENTRIC ACTIVITY RINGS HERO
                        VStack(spacing: 16) {
                            HStack {
                                Text("TODAY'S ACTIVITY")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(health.statusMessage)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                            }

                            HStack(spacing: 24) {
                                ActivityRingsView(
                                    moveCurrent: health.moveCalories,
                                    moveTarget: health.moveTarget,
                                    exerciseCurrent: health.exerciseMinutes,
                                    exerciseTarget: health.exerciseTarget,
                                    standCurrent: health.standHours,
                                    standTarget: health.standTarget,
                                    size: 140
                                )

                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Circle().fill(Color(red: 0.98, green: 0.07, blue: 0.31)).frame(width: 8, height: 8)
                                            Text("MOVE")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .foregroundColor(.gray)
                                        }
                                        Text("\(Int(health.moveCalories)) / \(Int(health.moveTarget)) KCAL")
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Circle().fill(Color(red: 0.57, green: 0.91, blue: 0.16)).frame(width: 8, height: 8)
                                            Text("EXERCISE")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .foregroundColor(.gray)
                                        }
                                        Text("\(Int(health.exerciseMinutes)) / \(Int(health.exerciseTarget)) MIN")
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Circle().fill(Color(red: 0.0, green: 0.94, blue: 1.0)).frame(width: 8, height: 8)
                                            Text("STAND")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .foregroundColor(.gray)
                                        }
                                        Text("\(Int(health.standHours)) / \(Int(health.standTarget)) HRS")
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(24)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .padding(.horizontal)

                        // 3. REAL-TIME VITALS TELEMETRY GRID
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCard(
                                title: "RESTING HR",
                                value: "\(Int(health.restingHeartRate)) BPM",
                                subtitle: "Apple Watch Optical",
                                color: Color(red: 0.06, green: 0.73, blue: 0.51),
                                icon: "heart.fill"
                            )

                            MetricCard(
                                title: "HRV (SDNN)",
                                value: "\(Int(health.heartRateVariability)) MS",
                                subtitle: "Autonomic Recovery",
                                color: Color(red: 0.0, green: 0.94, blue: 1.0),
                                icon: "waveform.path.ecg"
                            )

                            MetricCard(
                                title: "CARDIO VO2",
                                value: String(format: "%.1f", health.vo2Max),
                                subtitle: "Top 1% Longevity",
                                color: Color(red: 0.90, green: 1.0, blue: 0.25),
                                icon: "flame.fill"
                            )

                            MetricCard(
                                title: "SLEEP TOTAL",
                                value: String(format: "%.1fh", health.sleepTotalHours),
                                subtitle: "2.2h Deep REM",
                                color: Color(red: 0.58, green: 0.36, blue: 0.96),
                                icon: "moon.fill"
                            )
                        }
                        .padding(.horizontal)

                        // 4. EMBEDDED CAMERA WORKOUT TRACKER
                        CameraWorkoutView()

                        // 5. MANUAL BROADCAST TRIGGER TO MAC
                        Button(action: {
                            health.broadcastToMac()
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("FORCE SYNC TO MAC APP (127.0.0.1:\(health.macServerPort))")
                            }
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

// Reusable Metric Telemetry Card
struct MetricCard: View {
    var title: String
    var value: String
    var subtitle: String
    var color: Color
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(color.opacity(0.9))
        }
        .padding(14)
        .background(Color.black.opacity(0.5))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
