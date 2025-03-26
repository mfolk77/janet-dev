//
//  SimpleTokenizer.swift
//  Janet
//
//  Created by Michael folk on 2/25/25.
//

import Foundation
import os

/// A simple fallback tokenizer that doesn't rely on external files
public class SimpleTokenizer {
    // Constants for special token IDs
    private let BOS_TOKEN_ID = 1
    private let EOS_TOKEN_ID = 2
    private let PAD_TOKEN_ID = 0
    private let UNK_TOKEN_ID = 3
    
    // Properties for special tokens
    public private(set) var bosToken: Int?
    public private(set) var eosToken: Int?
    public private(set) var padToken: Int?
    public private(set) var unkToken: Int?
    
    // Vocabulary mapping from token to ID
    public private(set) var vocabulary: [String: Int] = [:]
    
    // Reverse mapping from ID to token
    public private(set) var idToToken: [Int: String] = [:]
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "SimpleTokenizer")
    
    /// Initialize with a basic vocabulary
    public init() {
        logger.info("Initializing SimpleTokenizer")
        
        // Set special token IDs
        self.bosToken = BOS_TOKEN_ID
        self.eosToken = EOS_TOKEN_ID
        self.padToken = PAD_TOKEN_ID
        self.unkToken = UNK_TOKEN_ID
        
        // Add special tokens to vocabulary
        self.vocabulary["<pad>"] = PAD_TOKEN_ID
        self.vocabulary["<s>"] = BOS_TOKEN_ID
        self.vocabulary["</s>"] = EOS_TOKEN_ID
        self.vocabulary["<unk>"] = UNK_TOKEN_ID
        
        // Add to reverse mapping
        self.idToToken[PAD_TOKEN_ID] = "<pad>"
        self.idToToken[BOS_TOKEN_ID] = "<s>"
        self.idToToken[EOS_TOKEN_ID] = "</s>"
        self.idToToken[UNK_TOKEN_ID] = "<unk>"
        
        // Add basic ASCII characters
        var nextId = 4
        let chars: [String] = " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,;:!?'\"()-[]{}".map { String($0) }
        
        for char in chars {
            self.vocabulary[char] = nextId
            self.idToToken[nextId] = char
            nextId += 1
        }
        
        logger.info("Simple tokenizer initialized with \(self.vocabulary.count) tokens")
    }
    
    /// Convert text to token IDs
    public func encode(text: String) throws -> [Int] {
        logger.info("Encoding text of length \(text.count)")
        
        // Start with BOS token
        var tokens: [Int] = []
        if let bos = self.bosToken {
            tokens.append(bos)
        }
        
        // Tokenize character by character
        for char in text.map({ String($0) }) {
            if let id = self.vocabulary[char] {
                tokens.append(id)
            } else if let unk = self.unkToken {
                tokens.append(unk)
            } else {
                // Fallback if unkToken is somehow nil
                tokens.append(UNK_TOKEN_ID)
            }
        }
        
        // End with EOS token
        if let eos = self.eosToken {
            tokens.append(eos)
        }
        
        logger.info("Encoded text to \(tokens.count) tokens")
        return tokens
    }
    
    /// Convert token IDs back to text
    public func decode(tokens: [Int]) throws -> String {
        logger.info("Decoding \(tokens.count) tokens")
        
        var result = ""
        
        for token in tokens {
            // Skip special tokens
            if token == self.bosToken || token == self.eosToken || token == self.padToken {
                continue
            }
            
            if let char = self.idToToken[token] {
                result.append(char)
            }
        }
        
        logger.info("Decoded to text of length \(result.count)")
        return result
    }
} 

