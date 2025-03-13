//
//  LetterTileView.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import SwiftUI

struct LetterTileView: View {
    let letter: String
    let state: TileState

    var body: some View {
        Text(letter)
            .font(.system(size: 24, weight: .bold))
            .frame(width: 50, height: 50)
            .background(state.backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
    }
}

enum TileState {
    case empty
    case correct
    case misplaced
    case incorrect

    var backgroundColor: Color {
        switch self {
        case .empty: return .gray
        case .correct: return .green
        case .misplaced: return .yellow
        case .incorrect: return .gray.opacity(0.5)
        }
    }
}

#Preview {
    LetterTileView(letter: "", state: .empty)
}
