import HirebarApplication
import SwiftUI

struct UpdateBanner: View {
    let update: UpdateInfo
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Color.blue)
            Text("Hay una versión nueva: \(update.version)")
                .font(.caption)
            Spacer()
            Button(String(localized: "Ver"), action: onOpen)
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.1)))
    }
}
