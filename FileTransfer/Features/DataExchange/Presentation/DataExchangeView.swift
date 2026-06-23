import SwiftUI

struct DataExchangeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            Button("Close") { dismiss() }
        }
    }
}

#Preview {
    DataExchangeView()
}
