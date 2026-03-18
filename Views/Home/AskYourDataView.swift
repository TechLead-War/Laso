import SwiftUI

// MARK: - Ask Your Data View

/// Natural language query interface for personal health data.
/// Based on Google's PHIA research (Nature Communications 2025):
/// lets users ask questions about their health in plain language.
struct AskYourDataView: View {
    let viewModel: DashboardViewModel
    @State private var query = ""
    @State private var result: HealthDataQueryEngine.QueryResult?
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss

    private let suggestedQuestions = [
        "How is my HRV trending?",
        "Does sleep affect my resting heart rate?",
        "What was my best sleep this month?",
        "Anything unusual in my data?",
        "How are my steps this week vs last week?",
        "Predict my HRV for tomorrow",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Search bar
                    searchBar

                    // Results
                    if let result {
                        resultCard(result)
                    } else {
                        suggestionsGrid
                    }
                }
                .padding()
            }
            .navigationTitle("Ask Your Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Ask about your health data...", text: $query)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .submitLabel(.search)
                .onSubmit { runQuery() }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !query.isEmpty {
                Button {
                    query = ""
                    result = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    // MARK: - Suggestions

    private var suggestionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try asking")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button {
                        query = question
                        runQuery()
                    } label: {
                        Text(question)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Result Card

    private func resultCard(_ result: HealthDataQueryEngine.QueryResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Answer
            Text(result.answer)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Data points
            if !result.dataPoints.isEmpty {
                VStack(spacing: 6) {
                    ForEach(result.dataPoints.indices, id: \.self) { i in
                        let dp = result.dataPoints[i]
                        HStack {
                            Text(dp.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(dp.value, specifier: dp.value >= 100 ? "%.0f" : "%.1f") \(dp.unit)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }

            // Confidence
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal")
                    .font(.caption2)
                Text("Confidence: \(Int(result.confidence * 100))%")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            // Related questions
            if !result.relatedQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Related")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(result.relatedQuestions, id: \.self) { q in
                        Button {
                            query = q
                            runQuery()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption2)
                                Text(q)
                                    .font(.caption)
                            }
                            .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    // MARK: - Query Execution

    private func runQuery() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true

        // Run on background to avoid blocking UI
        let q = query
        DispatchQueue.global(qos: .userInitiated).async {
            let queryResult = viewModel.queryHealthData(q)
            DispatchQueue.main.async {
                withAnimation(.snappy(duration: 0.3)) {
                    result = queryResult
                    isSearching = false
                }
            }
        }
    }
}
