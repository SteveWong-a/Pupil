//
//  ProgressiveHeaderBlur.swift
//  Pupil
//
//  A progressive backdrop blur behind the transparent Settings window header,
//  fading smoothly from strongest at the top edge to zero at the bottom.
//

import SwiftUI

public struct ProgressiveHeaderBlur: View {
    public var height: CGFloat

    private static let materials: [Material] = [
        .ultraThinMaterial, .thinMaterial, .regularMaterial
    ]

    public init(height: CGFloat) {
        self.height = height
    }

    public var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(Self.materials.enumerated()), id: \.offset) { index, material in
                let fadeEnd = 1 - CGFloat(index) / CGFloat(Self.materials.count)
                Rectangle()
                    .fill(material)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .clear, location: fadeEnd)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}
