import SwiftUI

// MARK: - Ask Your Data View

/// Natural language query interface for personal health data.
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
        HStack(spacing: DS.space2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColour.textSecondary)

            TextField(Copy.Home.AskYourData.placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(DS.Typography.body)
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
                        .foregroundStyle(AppColour.textTertiary)
                }
                .accessibilityLabel("Clear search")
                .accessibilityHint("Removes the current question and result")
            }
        }
        .padding(DS.space3)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(AppColour.borderMedium, lineWidth: 1)
        )
    }

    // MARK: - Suggestions

    private var suggestionsGrid: some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            Text(Copy.Home.AskYourData.tryAsking)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(AppColour.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.space2) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button {
                        query = question
                        AppAnalytics.shared.trackBlockTap(title: "Suggested Question", type: .smartAction, screen: .home, metadata: ["source": "ask_your_data_suggestion", "query_length": question.count])
                        runQuery()
                    } label: {
                        Text(question)
                            .font(DS.Typography.callout)
                            .foregroundStyle(AppColour.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.space2)
                            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.dsPress)
                }
            }
        }
    }

    // MARK: - Result Card

    private func resultCard(_ result: HealthDataQueryEngine.QueryResult) -> some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            // Answer
            Text(result.answer)
                .font(DS.Typography.body)
                .foregroundStyle(AppColour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Data points
            if !result.dataPoints.isEmpty {
                VStack(spacing: DS.space1) {
                    ForEach(result.dataPoints.indices, id: \.self) { i in
                        let dp = result.dataPoints[i]
                        HStack {
                            Text(dp.label)
                                .font(DS.Typography.callout)
                                .foregroundStyle(AppColour.textSecondary)
                            Spacer()
                            Text("\(dp.value, specifier: dp.value >= 100 ? "%.0f" : "%.1f") \(dp.unit)")
                                .font(DS.Typography.calloutSemibold)
                                .foregroundStyle(AppColour.textPrimary)
                        }
                    }
                }
                .padding(DS.space2)
                .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }

            // Confidence + feedback
            HStack(spacing: DS.space1) {
                Image(systemName: "checkmark.seal")
                    .font(DS.Typography.footnote)
                Text(Copy.Home.AskYourData.confidence(Int(result.confidence * 100)))
                    .font(DS.Typography.footnote)

                Spacer()

                Button {
                    AppAnalytics.shared.trackQueryFeedback(
                        helpful: true,
                        confidence: Int(result.confidence * 100),
                        queryLength: query.count
                    )
                } label: {
                    Image(systemName: "hand.thumbsup")
                        .font(DS.Typography.callout)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("This answer was helpful")
                .accessibilityHint("Sends positive feedback on this answer")

                Button {
                    AppAnalytics.shared.trackQueryFeedback(
                        helpful: false,
                        confidence: Int(result.confidence * 100),
                        queryLength: query.count
                    )
                } label: {
                    Image(systemName: "hand.thumbsdown")
                        .font(DS.Typography.callout)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("This answer was not helpful")
                .accessibilityHint("Sends negative feedback on this answer")
            }
            .foregroundStyle(AppColour.textSecondary)

            // Related questions
            if !result.relatedQuestions.isEmpty {
                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(Copy.Home.AskYourData.related)
                        .font(DS.Typography.calloutSemibold)
                        .foregroundStyle(AppColour.textSecondary)

                    ForEach(result.relatedQuestions, id: \.self) { q in
                        Button {
                            query = q
                            AppAnalytics.shared.trackBlockTap(title: "Related Question", type: .smartAction, screen: .home, metadata: ["source": "ask_your_data_related", "query_length": q.count])
                            runQuery()
                        } label: {
                            HStack(spacing: DS.space1) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(DS.Typography.footnote)
                                Text(q)
                                    .font(DS.Typography.callout)
                            }
                            .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .padding(DS.space4)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(AppColour.borderLow, lineWidth: 0.5)
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
