//
//  CameraValueDial.swift
//  Essential Cam
//
//  Created by Alexander López on 17/09/26.
//

import SwiftUI
import UIKit

struct CameraValueDial: View {
    enum Orientation {
        case horizontal
        case vertical
    }

    @Binding var value: Double

    let range: ClosedRange<Double>
    let step: Double
    let title: String
    var orientation: Orientation = .horizontal
    var neutralValue: Double? = nil
    var valueFormatter: (Double) -> String = { value in
        value.formatted(
            .number
                .precision(.fractionLength(1))
                .sign(strategy: .always())
        )
    }
    var showsBackground = true

    @State private var dragOriginValue: Double?
    @State private var lastHapticTime: TimeInterval = 0
    @State private var feedbackGenerator = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(spacing: 12) {
            valueLabel
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .cameraControlContentRotation()

            GeometryReader { _ in
                Canvas { context, size in
                    drawScale(in: context, size: size)
                }
                .overlay {
                    selectionIndicator
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
            }
            .frame(height: orientation == .horizontal ? 38 : nil)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .background {
            if showsBackground {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.55))
            }
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

    @ViewBuilder
    private var valueLabel: some View {
        switch orientation {
        case .horizontal:
            Text("\(title) \(formattedValue)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
        case .vertical:
            VStack(spacing: 2) {
                Text(title)
                Text(formattedValue)
                    .monospacedDigit()
            }
            .font(.system(size: 11.0, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var formattedValue: String {
        valueFormatter(value)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let initialValue = dragOriginValue ?? value
                dragOriginValue = initialValue

                let translation = switch orientation {
                case .horizontal:
                    gesture.translation.width
                case .vertical:
                    gesture.translation.height
                }
                let stepOffset = Double(translation / Metrics.pointsPerStep)
                updateValue(initialValue - stepOffset * step)
            }
            .onEnded { _ in
                dragOriginValue = nil
            }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        switch orientation {
        case .horizontal:
            Rectangle()
                .fill(.yellow)
                .frame(width: 2, height: 34)
                .frame(maxHeight: .infinity, alignment: .bottom)
        case .vertical:
            Rectangle()
                .fill(.yellow)
                .frame(width: 36, height: 2)
        }
    }

    private func drawScale(in context: GraphicsContext, size: CGSize) {
        let availableLength = switch orientation {
        case .horizontal:
            size.width
        case .vertical:
            size.height
        }
        let center = availableLength / 2
        let visibleTickCount = Int(ceil(availableLength / Metrics.pointsPerStep)) + 2
        let centerTickIndex = tickIndex(for: value)
        let firstTickIndex = centerTickIndex - visibleTickCount / 2
        let lastTickIndex = centerTickIndex + visibleTickCount / 2

        for tickIndex in firstTickIndex...lastTickIndex {
            let tickValue = tickAnchor + Double(tickIndex) * step
            guard range.contains(tickValue) else { continue }

            let position = center
                + CGFloat((tickValue - value) / step) * Metrics.pointsPerStep
            let appearance = tickAppearance(
                for: tickIndex,
                value: tickValue
            )

            var path = Path()

            switch orientation {
            case .horizontal:
                path.move(
                    to: CGPoint(x: position, y: size.height - appearance.height)
                )
                path.addLine(to: CGPoint(x: position, y: size.height))
            case .vertical:
                let centerX = size.width / 2
                path.move(
                    to: CGPoint(
                        x: centerX - appearance.height / 2,
                        y: position
                    )
                )
                path.addLine(
                    to: CGPoint(
                        x: centerX + appearance.height / 2,
                        y: position
                    )
                )
            }

            context.stroke(
                path,
                with: .color(appearance.color.opacity(appearance.opacity)),
                lineWidth: appearance.lineWidth
            )
        }
    }

    private func updateValue(_ proposedValue: Double) {
        let clampedValue = proposedValue.clamped(to: range)
        let stepCount = ((clampedValue - tickAnchor) / step).rounded()
        let steppedValue = tickAnchor + stepCount * step
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
        Int(((value - tickAnchor) / step).rounded())
    }

    private var tickAnchor: Double {
        neutralValue ?? range.lowerBound
    }

    private func tickAppearance(
        for index: Int,
        value: Double
    ) -> TickAppearance {
        if let neutralValue,
           abs(value - neutralValue) < step / 2 {
            return TickAppearance(
                height: 20,
                opacity: 1,
                lineWidth: 2,
                color: Metrics.neutralColor
            )
        }

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
        static let neutralColor = Color(red: 1, green: 0.3, blue: 0.12)
    }

    struct TickAppearance {
        let height: CGFloat
        let opacity: Double
        var lineWidth: CGFloat = 1
        var color: Color = .white
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
