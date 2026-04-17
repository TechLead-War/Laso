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
    @State private var activeQueryID = UUID()
    @Environment(\.dismiss) private var dismiss

    private let suggestedQuestions = Copy.Home.AskYourData.suggestedQuestions

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // AI assistant orb
                AskDataOrbView(size: 200)

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
        .accessibilityIdentifier("screen.askYourData")
        .navigationTitle(Copy.Home.AskYourData.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.home, metadata: ["subscreen": "ask_your_data"])
        }
        .onDisappear {
            activeQueryID = UUID()
            isSearching = false
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(Copy.Home.AskYourData.placeholder, text: $query)
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
            Text(Copy.Home.AskYourData.tryAsking)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button {
                        query = question
                        AppAnalytics.shared.trackBlockTap(title: "Suggested Question", type: .smartAction, screen: .home, metadata: ["source": "ask_your_data_suggestion", "query_length": question.count])
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

            // Confidence + feedback
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal")
                    .font(.caption2)
                Text(Copy.Home.AskYourData.confidence(Int(result.confidence * 100)))
                    .font(.caption2)

                Spacer()

                Button {
                    AppAnalytics.shared.trackQueryFeedback(
                        helpful: true,
                        confidence: Int(result.confidence * 100),
                        queryLength: query.count
                    )
                } label: {
                    Image(systemName: "hand.thumbsup")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button {
                    AppAnalytics.shared.trackQueryFeedback(
                        helpful: false,
                        confidence: Int(result.confidence * 100),
                        queryLength: query.count
                    )
                } label: {
                    Image(systemName: "hand.thumbsdown")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)

            // Related questions
            if !result.relatedQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.Home.AskYourData.related)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(result.relatedQuestions, id: \.self) { q in
                        Button {
                            query = q
                            AppAnalytics.shared.trackBlockTap(title: "Related Question", type: .smartAction, screen: .home, metadata: ["source": "ask_your_data_related", "query_length": q.count])
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
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return }
        isSearching = true
        let requestID = UUID()
        activeQueryID = requestID

        AppAnalytics.shared.trackCoreAction(.askedHealthQuery, screen: .home)
        AppAnalytics.shared.trackBlockTap(title: "Query Submitted", type: .smartAction, screen: .home, metadata: ["source": "ask_your_data", "query_length": query.count])

        Task {
            let queryResult = await viewModel.executeHealthQuery(normalizedQuery)
            guard activeQueryID == requestID else { return }
            withAnimation(.snappy(duration: 0.3)) {
                result = queryResult
                isSearching = false
            }
            AppAnalytics.shared.trackBlockTap(title: "Query Result Viewed", type: .smartAction, screen: .home, metadata: ["source": "ask_your_data", "confidence": Int(queryResult.confidence * 100), "data_points_count": queryResult.dataPoints.count, "related_questions_count": queryResult.relatedQuestions.count])
        }
    }
}
