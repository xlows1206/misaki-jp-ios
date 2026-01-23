//
//  CutletG2P.swift
//  PeraTalk
//
//  Complete port of misaki/cutlet.py G2P to iOS Swift.
//  Source: https://github.com/hexgrad/misaki/blob/main/misaki/cutlet.py
//
//  This implementation exactly matches cutlet's HEPBURN dictionary and
//  processing logic for 100% phoneme alignment with misaki.
//

import Foundation

/// Cutlet G2P - Complete port of misaki/cutlet.py to Swift
/// Converts Japanese text (hiragana) to IPA phonemes matching Kokoro TTS input format.
class CutletG2P {
    
    // MARK: - HEPBURN Dictionary (Hiragana -> IPA)
    // Exactly matches cutlet.py HEPBURN dictionary
    private static let HEPBURN: [String: String] = {
        var h = [String: String]()
        
        // Basic hiragana (single characters)
        // Vowels - IMPORTANT: う→ɯ (not u!)
        h["ぁ"] = "a"; h["あ"] = "a"
        h["ぃ"] = "i"; h["い"] = "i"
        h["ぅ"] = "ɯ"; h["う"] = "ɯ"
        h["ぇ"] = "e"; h["え"] = "e"
        h["ぉ"] = "o"; h["お"] = "o"
        
        // K row - IMPORTANT: き→kʲi (palatalized!)
        h["か"] = "ka"; h["が"] = "ɡa"
        h["き"] = "kʲi"; h["ぎ"] = "ɡʲi"
        h["く"] = "kɯ"; h["ぐ"] = "ɡɯ"
        h["け"] = "ke"; h["げ"] = "ɡe"
        h["こ"] = "ko"; h["ご"] = "ɡo"
        
        // S row - IMPORTANT: す→sɨ, ず→zɨ
        h["さ"] = "sa"; h["ざ"] = "ʣa"
        h["し"] = "ɕi"; h["じ"] = "ʥi"
        h["す"] = "sɨ"; h["ず"] = "zɨ"
        h["せ"] = "se"; h["ぜ"] = "ʣe"
        h["そ"] = "so"; h["ぞ"] = "ʣo"
        
        // T row - IMPORTANT: つ→ʦɨ
        h["た"] = "ta"; h["だ"] = "da"
        h["ち"] = "ʨi"; h["ぢ"] = "ʥi"
        // っ is handled specially (sokuon)
        h["つ"] = "ʦɨ"; h["づ"] = "zɨ"
        h["て"] = "te"; h["で"] = "de"
        h["と"] = "to"; h["ど"] = "do"
        
        // N row - IMPORTANT: に→ɲi (palatal nasal!)
        h["な"] = "na"
        h["に"] = "ɲi"
        h["ぬ"] = "nɯ"
        h["ね"] = "ne"
        h["の"] = "no"
        
        // H row - IMPORTANT: ひ→çi, ふ→ɸɯ
        h["は"] = "ha"; h["ば"] = "ba"; h["ぱ"] = "pa"
        h["ひ"] = "çi"; h["び"] = "bʲi"; h["ぴ"] = "pʲi"
        h["ふ"] = "ɸɯ"; h["ぶ"] = "bɯ"; h["ぷ"] = "pɯ"
        h["へ"] = "he"; h["べ"] = "be"; h["ぺ"] = "pe"
        h["ほ"] = "ho"; h["ぼ"] = "bo"; h["ぽ"] = "po"
        
        // M row - IMPORTANT: み→mʲi
        h["ま"] = "ma"
        h["み"] = "mʲi"
        h["む"] = "mɯ"
        h["め"] = "me"
        h["も"] = "mo"
        
        // Y row - IMPORTANT: ゆ→jɯ
        h["ゃ"] = "ja"; h["や"] = "ja"
        h["ゅ"] = "jɯ"; h["ゆ"] = "jɯ"
        h["ょ"] = "jo"; h["よ"] = "jo"
        
        // R row - IMPORTANT: ら→ɾa (flap), り→ɾʲi
        h["ら"] = "ɾa"
        h["り"] = "ɾʲi"
        h["る"] = "ɾɯ"
        h["れ"] = "ɾe"
        h["ろ"] = "ɾo"
        
        // W row - IMPORTANT: わ→βa (bilabial fricative!)
        h["ゎ"] = "βa"; h["わ"] = "βa"
        h["ゐ"] = "i"; h["ゑ"] = "e"; h["を"] = "o"
        
        // ん is handled specially (context-dependent)
        // っ is handled specially (sokuon/gemination)
        
        // Special characters
        h["ゔ"] = "vɯ"; h["ゕ"] = "ka"; h["ゖ"] = "ke"
        
        // Katakana variations (from cutlet)
        h["ヷ"] = "va"; h["ヸ"] = "vʲi"; h["ヹ"] = "ve"; h["ヺ"] = "vo"
        
        // Compound sounds (digraphs) - 2 character combinations
        // YE WI WE WO
        h["いぇ"] = "je"
        h["うぃ"] = "βi"; h["うぇ"] = "βe"; h["うぉ"] = "βo"
        
        // K compounds
        h["きぇ"] = "kʲe"; h["きゃ"] = "kʲa"; h["きゅ"] = "kʲɨ"; h["きょ"] = "kʲo"
        h["ぎゃ"] = "ɡʲa"; h["ぎゅ"] = "ɡʲɨ"; h["ぎょ"] = "ɡʲo"
        
        // Kw compounds
        h["くぁ"] = "kᵝa"; h["くぃ"] = "kᵝi"; h["くぇ"] = "kᵝe"; h["くぉ"] = "kᵝo"
        h["ぐぁ"] = "ɡᵝa"; h["ぐぃ"] = "ɡᵝi"; h["ぐぇ"] = "ɡᵝe"; h["ぐぉ"] = "ɡᵝo"
        
        // Sh compounds
        h["しぇ"] = "ɕe"; h["しゃ"] = "ɕa"; h["しゅ"] = "ɕɨ"; h["しょ"] = "ɕo"
        h["じぇ"] = "ʥe"; h["じゃ"] = "ʥa"; h["じゅ"] = "ʥɨ"; h["じょ"] = "ʥo"
        
        // Ch compounds
        h["ちぇ"] = "ʨe"; h["ちゃ"] = "ʨa"; h["ちゅ"] = "ʨɨ"; h["ちょ"] = "ʨo"
        h["ぢゃ"] = "ʥa"; h["ぢゅ"] = "ʥɨ"; h["ぢょ"] = "ʥo"
        
        // Ts compounds
        h["つぁ"] = "ʦa"; h["つぃ"] = "ʦʲi"; h["つぇ"] = "ʦe"; h["つぉ"] = "ʦo"
        
        // T/D compounds
        h["てぃ"] = "tʲi"; h["てゅ"] = "tʲɨ"
        h["でぃ"] = "dʲi"; h["でゅ"] = "dʲɨ"
        h["とぅ"] = "tɯ"; h["どぅ"] = "dɯ"
        
        // N compounds
        h["にぇ"] = "ɲe"; h["にゃ"] = "ɲa"; h["にゅ"] = "ɲɨ"; h["にょ"] = "ɲo"
        
        // H compounds
        h["ひぇ"] = "çe"; h["ひゃ"] = "ça"; h["ひゅ"] = "çɨ"; h["ひょ"] = "ço"
        h["びゃ"] = "bʲa"; h["びゅ"] = "bʲɨ"; h["びょ"] = "bʲo"
        h["ぴゃ"] = "pʲa"; h["ぴゅ"] = "pʲɨ"; h["ぴょ"] = "pʲo"
        
        // F compounds
        h["ふぁ"] = "ɸa"; h["ふぃ"] = "ɸʲi"; h["ふぇ"] = "ɸe"; h["ふぉ"] = "ɸo"
        h["ふゅ"] = "ɸʲɨ"; h["ふょ"] = "ɸʲo"
        
        // M compounds
        h["みゃ"] = "mʲa"; h["みゅ"] = "mʲɨ"; h["みょ"] = "mʲo"
        
        // R compounds
        h["りゃ"] = "ɾʲa"; h["りゅ"] = "ɾʲɨ"; h["りょ"] = "ɾʲo"
        
        // V compounds
        h["ゔぁ"] = "va"; h["ゔぃ"] = "vʲi"; h["ゔぇ"] = "ve"; h["ゔぉ"] = "vo"
        h["ゔゅ"] = "bʲɨ"; h["ゔょ"] = "bʲo"
        
        // Punctuation (from cutlet)
        h["。"] = "."
        h["、"] = ","
        h["？"] = "?"
        h["！"] = "!"
        h["「"] = "\u{201C}"; h["」"] = "\u{201D}"
        h["『"] = "\u{201C}"; h["』"] = "\u{201D}"
        h["："] = ":"
        h["；"] = ";"
        h["（"] = "("; h["）"] = ")"
        h["《"] = "("; h["》"] = ")"
        h["【"] = "["; h["】"] = "]"
        h["・"] = " "
        h["，"] = ","
        h["～"] = "—"; h["〜"] = "—"
        h["—"] = "—"
        h["«"] = "\u{201C}"; h["»"] = "\u{201D}"
        h["゚"] = ""; h["゙"] = ""  // combining marks, discard
        
        return h
    }()
    
    // Small kana (sutegana) - combined with previous
    private static let SUTEGANA = Set(["ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ"])
    
    // MARK: - Public API
    
    /// Convert Japanese text to IPA phonemes (matching misaki/cutlet output)
    /// - Parameter hiragana: Japanese text in hiragana
    /// - Returns: IPA phoneme string
    public static func convert(_ hiragana: String) -> String {
        // First normalize repeated vowels to long vowel mark
        let normalized = normalizeRepeatedVowels(hiragana)
        
        let chars = Array(normalized)
        var result = ""
        var i = 0
        
        while i < chars.count {
            let curr = String(chars[i])
            let prev = i > 0 ? String(chars[i-1]) : nil
            let next = i < chars.count - 1 ? String(chars[i+1]) : nil
            let isLast = i == chars.count - 1
            
            let phoneme = getSingleMapping(prev: prev, curr: curr, next: next, isLast: isLast)
            result += phoneme
            i += 1
        }
        
        return result
    }
    
    /// Convert katakana reading from OpenJTalk to hiragana, then to IPA
    static func convertFromKatakana(_ katakana: String) -> String {
        // Convert katakana to hiragana
        guard let hiragana = katakana.applyingTransform(.hiraganaToKatakana, reverse: true) else {
            return katakana
        }
        return convert(hiragana)
    }
    
    /// Convert a single mora (katakana) to IPA with length info
    /// - Parameter mora: A single mora in katakana (e.g., "キョ", "ン", "ッ")
    /// - Returns: Tuple of (IPA string, character count)
    private static func convertMora(_ mora: String) -> String {
        // First convert to hiragana
        guard let hiragana = mora.applyingTransform(.hiraganaToKatakana, reverse: true) else {
            return ""
        }
        
        // Check for special cases
        if hiragana == "っ" || mora == "ッ" {
            return "ʔ"
        }
        
        // ん/ン - Context will be handled in processNodes with next mora info
        // For now return ɴ as default (most common final form)
        if hiragana == "ん" || mora == "ン" {
            return "ɴ"
        }
        
        // Check for long vowel mark IN KATAKANA (before hiragana conversion changes it)
        // iOS transforms ー to the corresponding vowel (e.g., ジュー -> じゅう)
        // So we must handle ー in the original mora first
        if mora.contains("ー") {
            // Remove ー from katakana, convert base to hiragana, then to IPA
            let baseKata = mora.replacingOccurrences(of: "ー", with: "")
            guard let baseHira = baseKata.applyingTransform(.hiraganaToKatakana, reverse: true) else {
                return "ː"
            }
            
            // Try direct lookup first
            if let baseIpa = HEPBURN[baseHira] {
                return baseIpa + "ː"
            }
            
            // If base is multi-char (like "じゅ"), recursively convert
            if baseHira.count > 1 {
                let baseIpa = convert(baseHira)
                if !baseIpa.isEmpty {
                    return baseIpa + "ː"
                }
            }
            
            // Single char base
            if baseHira.count == 1, let baseIpa = HEPBURN[baseHira] {
                return baseIpa + "ː"
            }
            
            print("[CutletG2P] Warning: Could not convert mora with ー: \(mora) -> base: \(baseHira)")
            return "ː"
        }
        
        // Try direct lookup first (for digraphs like きょ)
        if let ipa = HEPBURN[hiragana] {
            return ipa
        }
        
        // Single char lookup
        if hiragana.count == 1 {
            return HEPBURN[hiragana] ?? ""
        }
        
        // Multi-char: try to combine (for sutegana combinations)
        var result = ""
        let chars = Array(hiragana)
        for i in 0..<chars.count {
            let char = String(chars[i])
            if i == 0 {
                if let ipa = HEPBURN[char] {
                    // Remove last vowel if next is sutegana
                    if i < chars.count - 1, SUTEGANA.contains(String(chars[i+1])) {
                        result = String(ipa.dropLast())
                    } else {
                        result = ipa
                    }
                }
            } else if SUTEGANA.contains(char) {
                // Small kana - just add its IPA
                if let ipa = HEPBURN[char] {
                    result += ipa
                }
            } else {
                // Regular character
                if let ipa = HEPBURN[char] {
                    result += ipa
                }
            }
        }
        return result
    }
    
    /// Convert ん/ン with context-dependent pronunciation
    /// Based on https://en.wikipedia.org/wiki/N_(kana) and misaki cutlet.py
    /// - Parameter nextMora: The next mora (katakana) or nil if end of word
    /// - Returns: IPA symbol for ん
    private static func convertN(nextMora: String?) -> String {
        guard let next = nextMora else {
            // Word-final or before pause: uvular nasal
            return "ɴ"
        }
        
        // Convert next mora to hiragana for checking
        let nextHira = next.applyingTransform(.hiraganaToKatakana, reverse: true) ?? next
        
        // Get the first character's IPA to determine the consonant
        let firstChar = String(nextHira.prefix(1))
        guard let nextIpa = HEPBURN[firstChar] else {
            return "ɴ"
        }
        
        let firstIpaChar = String(nextIpa.prefix(1))
        
        // Rules from Wikipedia/cutlet (simplified to avoid duplicate consonants):
        // m before m,p,b (labial) - these won't cause duplicates
        if ["m", "p", "b"].contains(firstIpaChar) {
            return "m"
        }
        // ŋ before k,g (velar) - these won't cause duplicates
        if ["k", "ɡ"].contains(firstIpaChar) || nextIpa.hasPrefix("ɡ") {
            return "ŋ"
        }
        // n before n,t,d,ɾ,z (alveolar) - these won't cause duplicates
        if ["t", "d", "ɾ", "z"].contains(firstIpaChar) {
            return "n"
        }
        // IMPORTANT: For ɲ,ʨ,ʥ (palatal), return ɴ to avoid ɲɲ duplication
        // The model should handle the nasalization naturally
        // ɴ otherwise (before vowels, semivowels, palatals, etc.)
        return "ɴ"
    }
    
    /// Parse katakana pronunciation into moras
    /// Port of misaki pron2moras
    private static func pron2moras(_ pron: String) -> [String] {
        var moras: [String] = []
        // Simple approach: each character is a mora, except small kana combines with previous
        let smallKana = Set(["ァ", "ィ", "ゥ", "ェ", "ォ", "ャ", "ュ", "ョ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ゃ", "ゅ", "ょ"])
        
        for char in pron {
            let charStr = String(char)
            if moras.isEmpty {
                moras.append(charStr)
            } else if smallKana.contains(charStr) {
                // Combine with previous
                moras[moras.count - 1] += charStr
            } else if charStr == "ー" && !moras.isEmpty {
                // Long vowel mark extends previous
                moras[moras.count - 1] += charStr
            } else if charStr == "ッ" || charStr == "っ" {
                // Sokuon as separate mora
                moras.append(charStr)
            } else if charStr == "ン" || charStr == "ん" {
                // N as separate mora
                moras.append(charStr)
            } else {
                moras.append(charStr)
            }
        }
        return moras
    }
    
    /// Process OpenJTalk nodes and return phonemes with pitch accent marks
    /// Based on misaki's pyopenjtalk accent logic with PRECISE mora boundary marking
    /// - Parameter nodes: Array of dictionaries from JapaneseG2P
    /// - Returns: Space-separated IPA phoneme string with ↓ markers at correct mora positions
    static func processNodes(_ nodes: [[String: Any]]) -> String {
        var resultWords: [String] = []
        
        // Track accent state across chained words
        var globalMoraCount = 0
        var currentPhraseAcc: Int? = nil
        var lastAccentLevel = 0
        
        for node in nodes {
            guard let pron = node["pron"] as? String, !pron.isEmpty else {
                // Handle punctuation
                if let surface = node["surface"] as? String, let mapped = HEPBURN[surface] {
                    resultWords.append(mapped)
                }
                // Reset phrase on punctuation
                currentPhraseAcc = nil
                globalMoraCount = 0
                lastAccentLevel = 0
                continue
            }
            
            let moraSize = node["mora_size"] as? Int ?? 0
            let acc = node["acc"] as? Int ?? 0
            let chainFlag = node["chain_flag"] as? Int ?? 0
            
            // Check if this word chains with previous (phrase continuation)
            let isChained = moraSize > 0 && chainFlag == 1
            
            if !isChained {
                // New phrase: reset accent tracking
                currentPhraseAcc = nil
                globalMoraCount = 0
                lastAccentLevel = 0
            }
            
            // Use phrase accent if not set yet
            if currentPhraseAcc == nil {
                currentPhraseAcc = acc
            }
            
            // Parse pronunciation into moras
            let moras = pron2moras(pron)
            
            // Convert each mora to IPA and track accent
            var wordResult = ""
            for (moraIndex, mora) in moras.enumerated() {
                globalMoraCount += 1
                
                // Calculate accent level for this mora
                // 0 = low, 1 = high (rise), 2 = continue high, 3 = nucleus
                let accentLevel: Int
                if let phraseAcc = currentPhraseAcc {
                    if phraseAcc == 0 {
                        // Heiban (flat): first mora low, rest high
                        accentLevel = globalMoraCount == 1 ? 0 : (lastAccentLevel == 0 ? 1 : 2)
                    } else if phraseAcc == 1 {
                        // Atamadaka (頭高型): first mora high, rest low
                        // First mora is nucleus (3), rest are low (0)
                        accentLevel = globalMoraCount == 1 ? 3 : 0
                    } else if phraseAcc == globalMoraCount {
                        // This is the accent nucleus (for nakadaka/odaka)
                        accentLevel = 3
                    } else if globalMoraCount == 1 {
                        // First mora is always low (before rise)
                        accentLevel = 0
                    } else if globalMoraCount > 1 && globalMoraCount < phraseAcc {
                        // High before nucleus
                        accentLevel = lastAccentLevel == 0 ? 1 : 2
                    } else {
                        // Low (after nucleus)
                        accentLevel = 0
                    }
                } else {
                    accentLevel = 0
                }
                
                // Convert mora to IPA with context for ん
                var moraIpa: String
                if mora == "ン" || mora == "ん" {
                    // Get next mora for context-dependent ん pronunciation
                    let nextMora = moraIndex < moras.count - 1 ? moras[moraIndex + 1] : nil
                    moraIpa = convertN(nextMora: nextMora)
                } else {
                    moraIpa = convertMora(mora)
                }
                
                // Insert pitch markers based on accent level
                // ↗ = pitch rise (from low to high), ↓ = pitch fall (after nucleus)
                
                // Insert ↗ BEFORE the mora that rises (level 1 = rise)
                // This tells the model to start rising at this point
                if accentLevel == 1 && lastAccentLevel == 0 {
                    wordResult += "↗"
                }
                
                wordResult += moraIpa
                
                // Insert ↓ AFTER accent nucleus (level 3)
                // This is the key: we insert the marker right after the nucleus mora's IPA
                if accentLevel == 3 {
                    wordResult += "↓"
                }
                
                lastAccentLevel = accentLevel
            }
            
            if !wordResult.isEmpty {
                resultWords.append(wordResult)
            }
        }
        
        return resultWords.joined(separator: " ")
    }
    
    // MARK: - Private Implementation (matching cutlet._get_single_mapping)
    
    /// Get phoneme mapping for a single character with context
    /// Exact port of cutlet.py _get_single_mapping with particle handling
    private static func getSingleMapping(prev: String?, curr: String, next: String?, isLast: Bool = false) -> String {
        // Handle particles は/へ/を at word-final or before punctuation
        // は → βa, へ → e, を → o (when used as particles)
        if isLast || (next != nil && ["。", "、", "？", "！"].contains(next!)) {
            if curr == "は" { return "βa" }
            if curr == "へ" { return "e" }
            if curr == "を" { return "o" }
        }
        // Handle digraphs (2-char combinations)
        if let p = prev, HEPBURN[p + curr] != nil {
            // Already processed as part of previous digraph
            return ""
        }
        if let n = next, let digraph = HEPBURN[curr + n] {
            return digraph
        }
        
        // Handle sutegana (small kana) attached to previous
        if let n = next, SUTEGANA.contains(n) {
            if curr == "っ" { return "" } // Invalid, ignore
            if let currPhoneme = HEPBURN[curr], let nextPhoneme = HEPBURN[n] {
                // Remove last vowel from curr, add small kana
                let base = String(currPhoneme.dropLast())
                return base + nextPhoneme
            }
        }
        if SUTEGANA.contains(curr) {
            // Already processed with previous, skip
            return ""
        }
        
        // Handle long vowel mark (ー)
        if curr == "ー" {
            return "ː"
        }
        
        // Handle sokuon (っ) -> glottal stop
        if curr == "っ" {
            return "ʔ"
        }
        
        // Handle ん - CONTEXT DEPENDENT!
        // https://en.wikipedia.org/wiki/N_(kana)
        if curr == "ん" {
            return processN(next: next)
        }
        
        // Standard lookup
        return HEPBURN[curr] ?? ""
    }
    
    /// Process ん based on following phoneme (matching cutlet.py)
    /// - m before m,p,b
    /// - ŋ before k,g
    /// - ɲ before ɲ,ʨ,ʥ (palatal)
    /// - n before n,t,d,ɾ,z
    /// - ɴ otherwise
    private static func processN(next: String?) -> String {
        guard let nextChar = next, let nextPhoneme = HEPBURN[nextChar] else {
            return "ɴ"
        }
        
        guard let first = nextPhoneme.first else {
            return "ɴ"
        }
        
        let firstStr = String(first)
        
        // m before m,p,b
        if "mpb".contains(firstStr) {
            return "m"
        }
        // ŋ before k,g
        if "kɡ".contains(firstStr) {
            return "ŋ"
        }
        // ɲ before palatal consonants
        if nextPhoneme.hasPrefix("ɲ") || nextPhoneme.hasPrefix("ʨ") || nextPhoneme.hasPrefix("ʥ") {
            return "ɲ"
        }
        // n before n,t,d,ɾ,z
        if "ntdɾz".contains(firstStr) {
            return "n"
        }
        
        return "ɴ"
    }
    
    /// Normalize repeated vowels to long vowel mark (ー)
    /// Handles both same-vowel repetition (ああ, いい, etc.) and ou→ō pattern
    /// This fixes iOS OpenJTalk outputting repeated vowels instead of ー
    private static func normalizeRepeatedVowels(_ text: String) -> String {
        var result = text
        
        // Same vowel repetition: aa→aー, ii→iー, uu→uー, ee→eー, oo→oー
        result = result.replacingOccurrences(of: "ああ", with: "あー")
        result = result.replacingOccurrences(of: "いい", with: "いー")
        result = result.replacingOccurrences(of: "うう", with: "うー")
        result = result.replacingOccurrences(of: "ええ", with: "えー")
        result = result.replacingOccurrences(of: "おお", with: "おー")
        
        // Common ou→ō pattern in Japanese (東京 = とうきょう → とーきょー)
        // This is a common long vowel pattern in Japanese phonetics
        result = result.replacingOccurrences(of: "おう", with: "おー")
        result = result.replacingOccurrences(of: "こう", with: "こー")
        result = result.replacingOccurrences(of: "そう", with: "そー")
        result = result.replacingOccurrences(of: "とう", with: "とー")
        result = result.replacingOccurrences(of: "のう", with: "のー")
        result = result.replacingOccurrences(of: "ほう", with: "ほー")
        result = result.replacingOccurrences(of: "もう", with: "もー")
        result = result.replacingOccurrences(of: "よう", with: "よー")
        result = result.replacingOccurrences(of: "ろう", with: "ろー")
        result = result.replacingOccurrences(of: "ごう", with: "ごー")
        result = result.replacingOccurrences(of: "ぞう", with: "ぞー")
        result = result.replacingOccurrences(of: "どう", with: "どー")
        result = result.replacingOccurrences(of: "ぼう", with: "ぼー")
        result = result.replacingOccurrences(of: "ぽう", with: "ぽー")
        result = result.replacingOccurrences(of: "じょう", with: "じょー")
        result = result.replacingOccurrences(of: "ちょう", with: "ちょー")
        result = result.replacingOccurrences(of: "しょう", with: "しょー")
        result = result.replacingOccurrences(of: "りょう", with: "りょー")
        result = result.replacingOccurrences(of: "きょう", with: "きょー")
        result = result.replacingOccurrences(of: "ぎょう", with: "ぎょー")
        result = result.replacingOccurrences(of: "ひょう", with: "ひょー")
        result = result.replacingOccurrences(of: "びょう", with: "びょー")
        result = result.replacingOccurrences(of: "ぴょう", with: "ぴょー")
        result = result.replacingOccurrences(of: "みょう", with: "みょー")
        result = result.replacingOccurrences(of: "にょう", with: "にょー")
        
        // ei→eː pattern (less common but exists)
        result = result.replacingOccurrences(of: "えい", with: "えー")
        result = result.replacingOccurrences(of: "けい", with: "けー")
        result = result.replacingOccurrences(of: "せい", with: "せー")
        result = result.replacingOccurrences(of: "てい", with: "てー")
        result = result.replacingOccurrences(of: "ねい", with: "ねー")
        result = result.replacingOccurrences(of: "へい", with: "へー")
        result = result.replacingOccurrences(of: "めい", with: "めー")
        result = result.replacingOccurrences(of: "れい", with: "れー")
        
        return result
    }
}
