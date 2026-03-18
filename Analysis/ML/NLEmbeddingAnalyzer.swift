import Foundation
import NaturalLanguage

/// Native NLP Semantic Analyzer leveraging Apple's NaturalLanguage framework.
/// 
/// We use `NLEmbedding` to ensure that generated language dynamically matches
/// the context and sentiment of the user's data without relying on string concatenation.
final class NLEmbeddingAnalyzer {
    
    enum SentimentTier {
        case positive   // "Peak", "Momentum", "Recovery"
        case neutral    // "Optimization", "Pattern"
        case negative   // "Stressed", "Fatigued", "Warning"
    }
    
    /// Loads the word embedding model provided by iOS
    private lazy var wordEmbedding: NLEmbedding? = {
        return NLEmbedding.wordEmbedding(for: .english)
    }()
    
    /// Sentence embedding (supported on iOS 14+)
    private lazy var sentenceEmbedding: NLEmbedding? = {
        if #available(iOS 14.0, macOS 11.0, *) {
            return NLEmbedding.sentenceEmbedding(for: .english)
        }
        return nil
    }()
    
    // MARK: - Core NLP Functions
    
    /// Determines the optimal semantic variation of a word based on a target sentiment 
    func contextualizeWord(_ word: String, targetSentiment: SentimentTier) -> String {
        guard let embedding = wordEmbedding else { return word }
        
        let anchorWords: [String]
        switch targetSentiment {
        case .positive:
            anchorWords = ["excellent", "thriving", "momentum", "strong"]
        case .neutral:
            anchorWords = ["consistent", "steady", "observing"]
        case .negative:
            anchorWords = ["struggling", "fatigue", "decline", "warning"]
        }
        
        // Find neighbors for the input word
        let neighbors = embedding.neighbors(for: word, maximumCount: 10)
        
        // Find the neighbor that is closest (minimizes distance) to our anchor words
        var bestMatch = word
        var minDistance = Double.infinity
        
        for neighbor in neighbors {
            let nWord = neighbor.0
            for anchor in anchorWords {
                let dist = embedding.distance(between: nWord, and: anchor)
                if dist < minDistance {
                    minDistance = dist
                    bestMatch = nWord
                }
            }
        }
        
        return minDistance < 1.0 ? bestMatch : word
    }
    
    /// Computes the semantic similarity between two sentences.
    /// Used to ensure we don't present two adjacent insights that mean the same thing.
    func computeSemanticDistance(sentenceA: String, sentenceB: String) -> Double {
        if #available(iOS 14.0, macOS 11.0, *) {
            if let emb = sentenceEmbedding {
                return emb.distance(between: sentenceA, and: sentenceB)
            }
        }
        
        // Fallback: Bag-of-words distance approximation
        let wordsA = Set(sentenceA.lowercased().split(separator: " "))
        let wordsB = Set(sentenceB.lowercased().split(separator: " "))
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        
        return 1.0 - (Double(intersection) / Double(union))
    }
}
