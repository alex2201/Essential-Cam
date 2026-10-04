import SwiftUI

struct ApplicationLoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Essential Cam")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel("Essential Cam is loading")
    }
}
