//
//  WordValidationService.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-26.
//

import Foundation

class WordValidationService {
    static let shared = WordValidationService()
    private let baseURL = "https://api.dictionaryapi.dev/api/v2/entries/en/"

    func isValidWord(_ word: String, completion: @escaping (Bool) -> Void) {
        let urlString = baseURL + word
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        let request = URLRequest(url: url)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Validation Error: \(error)")
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }

            completion(httpResponse.statusCode == 200)
        }.resume()
    }
}
