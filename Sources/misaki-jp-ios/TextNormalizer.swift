//
//  TextNormalizer.swift
//  MisakiJP
//
//  Port of misaki.cutlet._normalize_text() to Swift
//  Handles text normalization for Japanese G2P
//

import Foundation

/// Text normalization for Japanese input
/// Port of Python misaki's text preprocessing logic
public class TextNormalizer {
    
    /// Normalize Japanese text for G2P processing
    /// Matches Python: unicodedata.normalize('NFKC') + mojimoji + num2kana
    ///
    /// - Parameters:
    ///   - text: Input Japanese text
    ///   - toHiragana: If true, converts numbers to Hiragana (for Stub Mode). 
    ///                 If false, converts to Kanji with Python-parity spacing (for OpenJTalk).
    /// - Returns: Normalized text ready for G2P
    public static func normalize(_ text: String, toHiragana: Bool = false) -> String {
        var result = text
        
        // 0. Apply Ruby Readings (User Override)
        // Converts "掃除[そうじ]" -> "そうじ" (Prioritize explicit reading)
        result = applyRubyReadings(result)
        
        // 1. Collapse spaces between Japanese characters
        // Fixes "掃 除" -> "掃除" to ensure correct word segmentation
        result = collapseJapaneseSpaces(result)
        
        // 1. Wave dash before numbers → から (from)
        // Matches: re.sub(r'[〜～](?=\d)', 'から', text)
        result = result.replacingOccurrences(
            of: #"[〜～](?=\d)"#,
            with: "から",
            options: .regularExpression
        )
        
        // 2. Unicode NFKC normalization
        // Matches: unicodedata.normalize('NFKC', text)
        result = result.precomposedStringWithCompatibilityMapping
        
        // 3. Full-width → Half-width (except kana)
        // Matches: mojimoji.zen_to_han(text, kana=False)
        result = zenToHan(result, kana: false)
        
        // 4. Half-width kana → Full-width kana
        // Matches: mojimoji.han_to_zen(text, digit=False, ascii=False)
        result = hanToZen(result, digit: false, ascii: false)
        
        // 5. Convert numbers
        if toHiragana {
            // Stub Mode: Convert directly to Hiragana using context-aware regexes
            // Do NOT insert spaces as it breaks counter detection
            result = Num2Kana.convertToHiragana(result)
        } else {
            // Full Mode: Convert to Kanji with spacing overlap (Python Parity)
            // Matches: ''.join([(' '+Convert(t)) if t.isdigit() else t for t in re.findall(r'\d+|\D+', text)])
            result = processNumbersWithSpacing(result)
        }
        
        return result
    }
    
    private static func processNumbersWithSpacing(_ text: String) -> String {
        // Regex to find digit sequences
        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        
        let nsText = text as NSString
        var parts: [String] = []
        var lastEnd = 0
        
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            // Append non-digit part
            if match.range.location > lastEnd {
                let nonDigitParams = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                parts.append(nsText.substring(with: nonDigitParams))
            }
            
            // Append converted digit part with space prefix
            let digitStr = nsText.substring(with: match.range)
            // Note: Num2Kana now handles context, but here we are extracting raw digits.
            // Wait, Python misaki calls `Convert(t)` on the digit string `t`.
            // But `Convert` also handles "2024年". If we split strictly by `\d+`, we break "2024年" into "2024" and "年".
            // Python's `re.findall(r'\d+|\D+', text)` DOES split "2024年" into ["2024", "年"].
            // So `Convert("2024")` is called.
            // Does `Convert` handle raw "2024" as "ni sen ni juu yon"? Yes.
            // Then "ni sen ni juu yon" + "nen".
            // Correct.
            // The `Num2Kana` logic I wrote in `Num2Kana.swift` handles "2024年" by regex lookahead/context. 
            // IF I split strictly by digits, I lose the context for `Num2Kana.convert`.
            // Python misaki's `Convert` function must handle raw digits based on *internal* heuristics or it just converts blindly?
            // Actually, `num2kana` library in Python usually converts "2024" to "二千二十四".
            // So "2024年" becomes "二千二十四" + "年" -> "二千二十四年".
            // This is valid.
            // BUT, `Num2Kana.swift` I wrote earlier relies on `processYear` matching `(\d{4})年` inside the full string.
            // If I split it, `processYear` inside `Num2Kana` won't find `2024年`.
            // CRITICAL DISCREPANCY.
            // If `TextNormalizer` splits first, `Num2Kana` receives isolated numbers.
            // So `Num2Kana` must be context-free OR `TextNormalizer` should rely on `Num2Kana` doing the replacement in-place (preserving context).
            
            // Re-reading Python: `text = ''.join([(' '+Convert(t)) if t.isdigit() else t for t in re.findall(r'\d+|\D+', text)])`
            // This implies `Convert` IS called on isolated digit strings.
            // So `Convert` in Python `num2kana` does NOT handle "2024年" context? 
            // Does it? `num2kana` usually just converts numbers.
            // The "Year/Month/Day" logic might be inside `Convert` *if* `Convert` takes context? No, it takes `t`.
            // So Misaki Python actually converts "2024年" to "二千二十四年" by converting "2024" to "二千二十四".
            // It relies on G2P (MeCab/OpenJTalk) to parse "二千二十四" + "年" correctly later? 
            // OR `Convert` is smarter?
            // Most likely: Misaki `num2kana` just converts numbers to Kanji numbers.
            // Then "2024年" (Context) is handled by OpenJTalk/MeCab G2P engine which knows how to read "二千二十四年".
            // YES. OpenJTalk handles "2024年" -> "nisen..."
            // So `Num2Kana` ONLY needs to convert digits to Kanji digits (with place values).
            // My previous `Num2Kana.swift` implementation of `processYear`, `processDate` etc. was *over-engineering* / doing G2P's job?
            // Misaki's goal is to feed Kanji to OpenJTalk.
            // OpenJTalk expects Kanji.
            // So `Num2Kana` just turns `123` -> `百二十三`.
            // `123円` -> `百二十三円`.
            // OpenJTalk reads `百二十三円` correctly.
            // So I should simplify `Num2Kana` to just separate number conversion, AND adopt the space insertion.
            
            let converted = Num2Kana.convert(digitStr) 
            parts.append(" " + converted)
            
            lastEnd = match.range.location + match.range.length
        }
        
        if lastEnd < nsText.length {
            parts.append(nsText.substring(from: lastEnd))
        }
        
        return parts.joined()
    }
    
    // MARK: - Private Helpers (mojimoji equivalents)
    
    /// Convert full-width characters to half-width
    /// Port of mojimoji.zen_to_han()
    private static func zenToHan(_ text: String, kana: Bool) -> String {
        if kana {
            // Convert everything including kana
            return text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        } else {
            // Convert only alphanumeric, preserve kana
            var result = ""
            for scalar in text.unicodeScalars {
                let value = scalar.value
                // Full-width ASCII range: U+FF01-FF5E
                // Convert to half-width: U+0021-007E
                if value >= 0xFF01 && value <= 0xFF5E {
                    let halfWidth = UnicodeScalar(value - 0xFEE0)!
                    result.append(String(halfWidth))
                } else {
                    result.append(String(scalar))
                }
            }
            return result
        }
    }
    
    /// Convert half-width characters to full-width
    /// Port of mojimoji.han_to_zen()
    private static func hanToZen(_ text: String, digit: Bool, ascii: Bool) -> String {
        if digit && ascii {
            // Convert everything
            return text.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? text
        }
        
        // Selective conversion
        var result = ""
        for scalar in text.unicodeScalars {
            let value = scalar.value
            
            var shouldConvert = false
            
            // Half-width katakana: U+FF61-FF9F
            if value >= 0xFF61 && value <= 0xFF9F {
                // Always convert half-width kana to full-width
                shouldConvert = true
            }
            // Half-width digits: 0-9
            else if value >= 0x30 && value <= 0x39 && digit {
                shouldConvert = true
            }
            // Half-width ASCII: A-Z, a-z
            else if ((value >= 0x41 && value <= 0x5A) || (value >= 0x61 && value <= 0x7A)) && ascii {
                shouldConvert = true
            }
            
            if shouldConvert && value >= 0x21 && value <= 0x7E {
                // Convert to full-width
                let fullWidth = UnicodeScalar(value + 0xFEE0)!
                result.append(String(fullWidth))
            } else {
                result.append(String(scalar))
            }
        }
        
        return result
    }
    
    /// Collapse spaces between non-ASCII (Japanese) characters
    /// Ensures "掃 除" becomes "掃除" for correct dictionary lookup
    private static func collapseJapaneseSpaces(_ text: String) -> String {
        // Regex: Lookbehind Non-ASCII + Space(s) + Lookahead Non-ASCII
        return text.replacingOccurrences(
            of: "(?<=[^\\x00-\\x7F])\\s+(?=[^\\x00-\\x7F])",
            with: "",
            options: .regularExpression
        )
    }
    /// Apply Ruby readings in format Kanji[Reading]
    /// Example: "掃除[そうじ]" -> "そうじ"
    /// Supports both Hiragana and Katakana readings inside brackets.
    /// Targets preceding Kanji block.
    private static func applyRubyReadings(_ text: String) -> String {
        // Pattern: (Kanji)\s*\[(Kana)\]
        // Matches: "掃除[そうじ]", "今[いま]"
        // Does NOT match: "test[test]" (No Kanji)
        // Capture group 1: Kanji block
        // Capture group 2: Reading
        
        // Using \p{Han} for Kanji.
        // Swift Regex for Unicode properties requires careful handling.
        // We generally use [\\u4e00-\\u9faf] for common Kanji to be safe in NSRegularExpression strings.
        
        let pattern = "([\\u4E00-\\u9FAF]+)\\[([^\\]]+)\\]"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        
        var result = text
        
        // Iterate reversed to preserve ranges
        for match in matches.reversed() {
            // We want to replace the WHOLE match (Kanji[Reading]) with just the Reading (Group 2)
            let readingRange = match.range(at: 2)
            let reading = nsText.substring(with: readingRange)
            
            result = (result as NSString).replacingCharacters(in: match.range, with: reading)
        }
        
        return result
    }
}
