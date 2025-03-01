//
//  WordleGridView.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import SwiftUI

struct WordleGridView: View {
    let grid: [[(letter: String, state: TileState)]]
    @Binding var shake: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0 ..< grid.count, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0 ..< grid[row].count, id: \.self) { column in
                        LetterTileView(
                            letter: grid[row][column].letter,
                            state: grid[row][column].state
                        )
                    }
                }
            }
        }
        .padding()
        .modifier(ShakeEffect(animatableData: shake ? 1 : 0))
        .animation(.default, value: shake)
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakesPerUnit),
            y: 0
        ))
    }
}

#Preview {
    WordleGridView(grid: [[(letter: "", state: .empty)]], shake: .constant(false))
}
