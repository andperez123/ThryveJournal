import Vision
import UIKit

class HandwritingRecognizer {
    static func recognizeHandwriting(from image: UIImage, completion: @escaping (String?) -> Void) {
        // Don't crop here, assume image is already padded
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage from image")
            completion(nil)
            return
        }

        print("Starting handwriting recognition on image size: \(image.size)")
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("Failed to recognize text: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("No text observations found")
                completion(nil)
                return
            }

            print("Found \(observations.count) text observations")
            var recognizedStrings: [String] = []
            
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    print("Confidence: \(candidate.confidence), String: \(candidate.string)")
                    recognizedStrings.append(candidate.string)
                }
            }
            
            let recognizedText = recognizedStrings.joined(separator: " ")
            print("Final recognized text: '\(recognizedText)'")
            completion(recognizedText.isEmpty ? nil : recognizedText)
        }

        // Configure the recognition level
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.05 // Slightly larger minimum text height
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform recognition: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // Removed cropToContent function
} 