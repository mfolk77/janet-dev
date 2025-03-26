import Foundation
import SQLite

// MARK: - SQLite Extensions for Vector Operations
extension Connection {
    /// Create a function for calculating cosine similarity between two vectors
    func createCosineSimilarityFunction() {
        let name = "cosine_similarity"
        let deterministic: UInt = 1  // 1 for true, 0 for false
        let argumentCount: Int32 = 2
        
        self.createFunction(name, argumentCount: deterministic, deterministic: (argumentCount != 0)) { values -> Double? in
            guard values.count == 2,
                  let vector1String = values[0] as? String,
                  let vector2String = values[1] as? String else {
                return nil
            }
            
            // Parse JSON strings into arrays
            guard let vector1Data = vector1String.data(using: .utf8),
                  let vector2Data = vector2String.data(using: .utf8),
                  let vector1 = try? JSONDecoder().decode([Double].self, from: vector1Data),
                  let vector2 = try? JSONDecoder().decode([Double].self, from: vector2Data) else {
                return nil
            }
            
            // Vectors must be of the same length
            guard vector1.count == vector2.count else {
                return nil
            }
            
            // Calculate dot product
            var dotProduct: Double = 0
            var magnitude1: Double = 0
            var magnitude2: Double = 0
            
            for i in 0..<vector1.count {
                dotProduct += vector1[i] * vector2[i]
                magnitude1 += vector1[i] * vector1[i]
                magnitude2 += vector2[i] * vector2[i]
            }
            
            magnitude1 = sqrt(magnitude1)
            magnitude2 = sqrt(magnitude2)
            
            // Avoid division by zero
            guard magnitude1 > 0 && magnitude2 > 0 else {
                return 0.0
            }
            
            return dotProduct / (magnitude1 * magnitude2)
        }
    }
}

// MARK: - Vector Math Utilities
struct VectorMath {
    /// Calculate cosine similarity between two vectors
    static func cosineSimilarity(vector1: [Double], vector2: [Double]) -> Double {
        // Vectors must be of the same length
        guard vector1.count == vector2.count, !vector1.isEmpty else {
            return 0.0
        }
        
        // Calculate dot product
        var dotProduct: Double = 0
        var magnitude1: Double = 0
        var magnitude2: Double = 0
        
        for i in 0..<vector1.count {
            dotProduct += vector1[i] * vector2[i]
            magnitude1 += vector1[i] * vector1[i]
            magnitude2 += vector2[i] * vector2[i]
        }
        
        magnitude1 = sqrt(magnitude1)
        magnitude2 = sqrt(magnitude2)
        
        // Avoid division by zero
        guard magnitude1 > 0 && magnitude2 > 0 else {
            return 0.0
        }
        
        return dotProduct / (magnitude1 * magnitude2)
    }
    
    /// Generate a simple hash-based embedding for text
    /// This is a placeholder until a proper embedding model is integrated
    static func generateSimpleEmbedding(for text: String, dimensions: Int = 128) -> [Double] {
        let normalizedText = text.lowercased()
        var embedding = [Double](repeating: 0.0, count: dimensions)
        
        // Use a simple hash function to generate pseudo-random but deterministic values
        for (i, char) in normalizedText.enumerated() {
            let charValue = Double(char.asciiValue ?? 0)
            let position = i % dimensions
            
            // Add a weighted value based on character and position
            embedding[position] += charValue / 100.0
            
            // Add some cross-dimensional influence for better distribution
            let crossPosition = (position + 7) % dimensions
            embedding[crossPosition] += charValue / 200.0
        }
        
        // Normalize the embedding vector
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            for i in 0..<embedding.count {
                embedding[i] /= magnitude
            }
        }
        
        return embedding
    }
} 
