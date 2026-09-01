import SwiftUI
import Charts

/// Per-lift progression: a chart over time plus short- and long-term change.
/// Generic and lift-focused — no personal goals or targets.
struct TrendsView: View {
    @EnvironmentObject var store: Store

    @State private var exercise = ""
    @State private var metric: Analytics.Metric = .topSet

    private var exercises: [String] { store.knownExercises.sorted() }

    private var availableMetrics: [Analytics.Metric] {
        Analytics.availableMetrics(exercise, in: store.sessions)
    }

    private var series: [TrendPoint] {
        Analytics.series(exercise, metric: metric, in: store.sessions)
    }

    private var recent: TrendChange? { Analytics.change(series, sinceDays: 21) }
    private var allTime: TrendChange? { Analytics.change(series) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if exercises.isEmpty {
                    ContentUnavailableView("No data yet", systemImage: "chart.line.uptrend.xyaxis",
                                           description: Text("Log some workouts to see trends."))
                        .padding(.top, 80)
                } else {
                    VStack(spacing: 16) {
                        exercisePicker
                        if availableMetrics.count > 1 { metricPicker }
                        chartCard
                        statsRow
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trends")
            .refreshable { await store.load() }
            .onAppear(perform: ensureSelection)
            .onChange(of: exercise) { _, _ in clampMetric() }
        }
    }

    // MARK: - Controls

    private var exercisePicker: some View {
        Menu {
            Picker("Exercise", selection: $exercise) {
                ForEach(exercises, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            HStack {
                Text(exercise.isEmpty ? "Choose exercise" : exercise)
                    .font(.title3.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down").font(.footnote)
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var metricPicker: some View {
        Picker("Metric", selection: $metric) {
            ForEach(availableMetrics) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Chart

    private var chartCard: some View {
        CardBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(metric.rawValue.uppercased() + " OVER TIME")
                    .font(.caption).foregroundStyle(.secondary)

                if series.count >= 2 {
                    Chart(series) { point in
                        LineMark(x: .value("Date", point.date),
                                 y: .value(metric.rawValue, point.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.tint)
                        PointMark(x: .value("Date", point.date),
                                  y: .value(metric.rawValue, point.value))
                            .foregroundStyle(.tint)
                            .symbolSize(28)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .frame(height: 240)
                } else {
                    Text("Need at least two sessions of this lift to chart a trend.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(height: 240, alignment: .center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(title: "Short-term", subtitle: "last 3 weeks", change: recent)
            statTile(title: "Long-term", subtitle: "all time", change: allTime)
        }
    }

    private func statTile(title: String, subtitle: String, change: TrendChange?) -> some View {
        CardBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased()).font(.caption).foregroundStyle(.secondary)
                if let c = change {
                    HStack(spacing: 4) {
                        Image(systemName: c.isUp ? "arrow.up.right" : "arrow.down.right")
                        Text(formatted(c.delta) + " \(metric.unit)")
                    }
                    .font(.title3.weight(.bold))
                    .foregroundStyle(c.isUp ? .green : .red)
                    Text(String(format: "%+.0f%%", c.percent))
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("—").font(.title3.weight(.bold)).foregroundStyle(.secondary)
                    Text("not enough data").font(.footnote).foregroundStyle(.secondary)
                }
                Text(subtitle).font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func formatted(_ v: Double) -> String {
        let rounded = (v * 10).rounded() / 10
        let s = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        return v >= 0 ? "+\(s)" : s
    }

    private func ensureSelection() {
        if exercise.isEmpty { exercise = exercises.first ?? "" }
        clampMetric()
    }

    private func clampMetric() {
        if !availableMetrics.contains(metric) { metric = availableMetrics.first ?? .topSet }
    }
}

/// Reusable rounded card container.
private struct CardBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))
    }
}
