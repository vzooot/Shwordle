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

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error validating word: \(error)")
                completion(false)
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }
        task.resume()
    }
}
