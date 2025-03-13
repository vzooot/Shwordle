//
//  KeyboardView.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import SwiftUI

struct KeyboardView: View {
    let letters: [[String]]
    let onKeyTap: (String) -> Void
    let keyStates: [String: TileState]
    let isDisabled: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(letters, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { letter in
                        Button(action: { onKeyTap(letter) }) {
                            Text(letter)
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 30, height: 40)
                                .background(keyStates[letter]?.backgroundColor ?? Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(isDisabled)
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: { onKeyTap("DELETE") }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 60, height: 50)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isDisabled)
            }
        }
        .padding()
    }
}

#Preview {
    KeyboardView(letters: [[""]], onKeyTap: { _ in }, keyStates: ["A": .incorrect], isDisabled: false)
}
