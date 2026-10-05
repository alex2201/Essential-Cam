//
//  CameraIconRotation.swift
//  Essential Cam
//
//  Created by Alexander López on 05/10/26.
//

import SwiftUI

private struct CameraIconRotationDegreesKey: EnvironmentKey {
    static let defaultValue: Double = 0
}

extension EnvironmentValues {
    var cameraIconRotationDegrees: Double {
        get { self[CameraIconRotationDegreesKey.self] }
        set { self[CameraIconRotationDegreesKey.self] = newValue }
    }
}

extension CaptureOrientation {
    /// Compensates physical device rotation in the fixed portrait interface.
    var controlRotationDegrees: Double {
        switch self {
        case .portrait: 0
        case .landscapeLeft: 90
        case .landscapeRight: -90
        case .portraitUpsideDown: 180
        }
    }
}

/// Keeps the original layout footprint while proposing swapped dimensions to
/// rotated label content, so text fits inside the same fixed control slot.
private struct CameraRotatedContentLayout: Layout {
    let isHorizontal: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(proposal) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let contentProposal = ProposedViewSize(
            width: isHorizontal ? bounds.height : bounds.width,
            height: isHorizontal ? bounds.width : bounds.height
        )
        subviews.first?.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: contentProposal
        )
    }
}

private struct CameraControlContentRotation: ViewModifier {
    @Environment(\.cameraIconRotationDegrees) private var degrees

    func body(content: Content) -> some View {
        CameraRotatedContentLayout(isHorizontal: abs(degrees) == 90) {
            content.rotationEffect(.degrees(degrees))
        }
    }
}

private struct CameraIconRotation: ViewModifier {
    @Environment(\.cameraIconRotationDegrees) private var degrees

    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(degrees))
    }
}

extension View {
    /// Apply once to the complete label, before its background and hit area.
    func cameraControlContentRotation() -> some View {
        modifier(CameraControlContentRotation())
    }

    /// Apply to the symbol before its fixed frame and hit area, never to its button.
    func cameraIconRotation() -> some View {
        modifier(CameraIconRotation())
    }
}
