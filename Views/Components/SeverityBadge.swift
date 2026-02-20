import SwiftUI

/// Badge indicating severity level of an insight
struct SeverityBadge: View {
    let severity: Severity

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: severity.systemImageName)
                .font(.caption2)

            Text(severity.displayName)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(severity.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(severity.color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    VStack(spacing: 10) {
        SeverityBadge(severity: .info)
        SeverityBadge(severity: .warning)
        SeverityBadge(severity: .critical)
    }
}
