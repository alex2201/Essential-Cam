//
//  CompositionGuide.swift
//  Essential Cam
//
//  Created by Alexander López.
//

import Foundation

enum CompositionGuide: String, CaseIterable, Sendable {
    case thirds, center, grid4x4, goldenRatio, diagonals

    var lineSegments: [GuideLineSegment] {
        switch self {
        case .thirds: Self.grid(at: [1.0 / 3, 2.0 / 3])
        case .grid4x4: Self.grid(at: [0.25, 0.5, 0.75])
        case .goldenRatio: Self.grid(at: [1 / pow((1 + sqrt(5)) / 2, 2), 1 / ((1 + sqrt(5)) / 2)])
        case .center: [GuideLineSegment(x1: 0.46, y1: 0.5, x2: 0.54, y2: 0.5),
                       GuideLineSegment(x1: 0.5, y1: 0.46, x2: 0.5, y2: 0.54)]
        case .diagonals: [GuideLineSegment(x1: 0, y1: 0, x2: 1, y2: 1),
                          GuideLineSegment(x1: 1, y1: 0, x2: 0, y2: 1)]
        }
    }

    private static func grid(at positions: [Double]) -> [GuideLineSegment] {
        positions.flatMap { position in
            [GuideLineSegment(x1: position, y1: 0, x2: position, y2: 1),
             GuideLineSegment(x1: 0, y1: position, x2: 1, y2: position)]
        }
    }
}

struct GuideLineSegment: Equatable, Sendable {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
}

struct GuideColor: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    static let yellow = GuideColor(red: 1, green: 1, blue: 0)

    var isValid: Bool {
        [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}
