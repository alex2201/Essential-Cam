//
//  CameraValueDial.swift
//  Essential Cam
//

import SwiftUI
import UIKit

struct CameraValueDial: View {
    @Binding var value: Double

    let range: ClosedRange<Double>
    let step: Double
    let title: String

    @State private var dragOriginValue: Double?
    @State private var lastHapticTime: TimeInterval = 0
    @State private var feedbackGenerator = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(spacing: 8) {
            Text("\(title) \(formattedValue)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()

            GeometryReader { _ in
                Canvas { context, size in
                    drawScale(in: context, size: size)
                }
                .overlay {
                    Rectangle()
                        .fill(.yellow)
                        .frame(width: 2, height: 34)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
            }
            .frame(height: 38)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.55))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(formattedValue)
        .onAppear {
            feedbackGenerator.prepare()
        }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                updateValue(value + step)
            case .decrement:
                updateValue(value - step)
            @unknown default:
                break
            }
        }
    }

    private var formattedValue: String {
        value.formatted(
            .number
                .precision(.fractionLength(1))
                .sign(strategy: .always())
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let initialValue = dragOriginValue ?? value
                dragOriginValue = initialValue

                let stepOffset = Double(gesture.translation.width / Metrics.pointsPerStep)
                updateValue(initialValue - stepOffset * step)
            }
            .onEnded { _ in
                dragOriginValue = nil
            }
    }

    private func drawScale(in context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let visibleTickCount = Int(ceil(size.width / Metrics.pointsPerStep)) + 2
        let centerTickIndex = tickIndex(for: value)
        let firstTickIndex = centerTickIndex - visibleTickCount / 2
        let lastTickIndex = centerTickIndex + visibleTickCount / 2

        for tickIndex in firstTickIndex...lastTickIndex {
            let tickValue = range.lowerBound + Double(tickIndex) * step
            guard range.contains(tickValue) else { continue }

            let x = centerX
                + CGFloat((tickValue - value) / step) * Metrics.pointsPerStep
            let appearance = tickAppearance(for: tickIndex)

            var path = Path()
            path.move(to: CGPoint(x: x, y: size.height - appearance.height))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(
                path,
                with: .color(.white.opacity(appearance.opacity)),
                lineWidth: 1
            )
        }
    }

    private func updateValue(_ proposedValue: Double) {
        let clampedValue = proposedValue.clamped(to: range)
        let stepCount = ((clampedValue - range.lowerBound) / step).rounded()
        let steppedValue = range.lowerBound + stepCount * step
        let newValue = steppedValue.clamped(to: range)

        guard newValue != value else { return }

        value = newValue
        triggerHapticFeedbackIfNeeded()
    }

    private func triggerHapticFeedbackIfNeeded() {
        let currentTime = ProcessInfo.processInfo.systemUptime

        guard currentTime - lastHapticTime >= Metrics.minimumHapticInterval else {
            return
        }

        lastHapticTime = currentTime
        feedbackGenerator.selectionChanged()
        feedbackGenerator.prepare()
    }

    private func tickIndex(for value: Double) -> Int {
        Int(((value - range.lowerBound) / step).rounded())
    }

    private func tickAppearance(for index: Int) -> TickAppearance {
        if index.isMultiple(of: 10) {
            return TickAppearance(height: 26, opacity: 1)
        }

        if index.isMultiple(of: 5) {
            return TickAppearance(height: 18, opacity: 0.85)
        }

        return TickAppearance(height: 10, opacity: 0.6)
    }
}

private extension CameraValueDial {
    enum Metrics {
        static let pointsPerStep: CGFloat = 12
        static let minimumHapticInterval: TimeInterval = 1 / 25
    }

    struct TickAppearance {
        let height: CGFloat
        let opacity: Double
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    @Previewable @State var value = 0.0

    CameraValueDial(
        value: $value,
        range: -3...3,
        step: 0.1,
        title: "EV"
    )
    .padding()
    .background(.gray)
}
