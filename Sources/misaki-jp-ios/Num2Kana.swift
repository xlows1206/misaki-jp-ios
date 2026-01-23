//
//  Num2Kana.swift
//  MisakiJP
//
//  Port of Python num2kana library to Swift
//  Converts Arabic numerals to Japanese readings
//

import Foundation

/// Convert numbers to Japanese kana reading
/// Port of Python num2kana.Convert()
public class Num2Kana {
    
    // MARK: - Digit Names
    
    private static let digitNames: [Int: String] = [
        0: "零", 1: "一", 2: "二", 3: "三", 4: "四",
        5: "五", 6: "六", 7: "七", 8: "八", 9: "九"
    ]
    
    private static let units: [(value: Int, name: String)] = [
        (100000000, "億"),
        (10000, "万"),
        (1000, "千"),
        (100, "百"),
        (10, "十"),
        (1, "")
    ]
    
    // MARK: - Main API
    
    /// Convert numbers in text to Japanese reading
    /// - Parameter text: Input text with Arabic numerals
    /// - Returns: Text with numbers converted to Japanese
    public static func convert(_ text: String) -> String {
        var result = text
        
        // Process in order of specificity
        result = processYear(result)
        result = processMonth(result)
        result = processDay(result)
        result = processTime(result)
        result = processGeneralNumber(result)
        
        return result
    }
    
    // MARK: - Year Processing
    
    /// Process year patterns: 2024年 → 二千二十四年
    private static func processYear(_ text: String) -> String {
        let pattern = #"(\d{4})年"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        
        var result = text
        for match in matches.reversed() {
            let yearRange = match.range(at: 1)
            let yearStr = nsText.substring(with: yearRange)
            if let year = Int(yearStr) {
                let reading = numberToKanji(year) + "年"
                let fullRange = match.range
                result = (result as NSString).replacingCharacters(in: fullRange, with: reading)
            }
        }
        
        return result
    }
    
    // MARK: - Month Processing
    
    /// Process month patterns: 12月 → 十二月
    private static func processMonth(_ text: String) -> String {
        let pattern = #"(\d{1,2})月"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        
        var result = text
        for match in matches.reversed() {
            let monthRange = match.range(at: 1)
            let monthStr = nsText.substring(with: monthRange)
            if let month = Int(monthStr), month >= 1, month <= 12 {
                let reading = monthReading(month) + "月"
                let fullRange = match.range
                result = (result as NSString).replacingCharacters(in: fullRange, with: reading)
            }
        }
        
        return result
    }
    
    private static func monthReading(_ month: Int) -> String {
        // Special readings for certain months
        let specialReadings: [Int: String] = [
            4: "四",   // しがつ
            7: "七",   // しちがつ
            9: "九"    // くがつ
        ]
        
        if let special = specialReadings[month] {
            return special
        }
        
        return numberToKanji(month)
    }
    
    // MARK: - Day Processing
    
    /// Process day patterns: 25日 → 二十五日
    private static func processDay(_ text: String) -> String {
        let pattern = #"(\d{1,2})日"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        
        var result = text
        for match in matches.reversed() {
            let dayRange = match.range(at: 1)
            let dayStr = nsText.substring(with: dayRange)
            if let day = Int(dayStr), day >= 1, day <= 31 {
                let reading = dayReading(day) + "日"
                let fullRange = match.range
                result = (result as NSString).replacingCharacters(in: fullRange, with: reading)
            }
        }
        
        return result
    }
    
    private static func dayReading(_ day: Int) -> String {
        // Special readings for certain days (simplified)
        // Full implementation would have more special cases
        return numberToKanji(day)
    }
    
    // MARK: - Time Processing
    
    /// Process time patterns: 14時30分 → 十四時三十分
    private static func processTime(_ text: String) -> String {
        var result = text
        
        // Hours
        result = result.replacingOccurrences(
            of: #"(\d{1,2})時"#,
            with: { match -> String in
                guard let number = extractNumber(from: match) else { return match }
                return numberToKanji(number) + "時"
            },
            options: .regularExpression
        )
        
        // Minutes
        result = result.replacingOccurrences(
            of: #"(\d{1,2})分"#,
            with: { match -> String in
                guard let number = extractNumber(from: match) else { return match }
                return numberToKanji(number) + "分"
            },
            options: .regularExpression
        )
        
        return result
    }
    
    // MARK: - General Number Processing
    
    /// Process general numbers: 123 → 百二十三
    private static func processGeneralNumber(_ text: String) -> String {
        let pattern = #"\d+"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        
        var result = text
        for match in matches.reversed() {
            let numStr = nsText.substring(with: match.range)
            if let number = Int(numStr) {
                let reading = numberToKanji(number)
                result = (result as NSString).replacingCharacters(in: match.range, with: reading)
            }
        }
        
        return result
    }
    
    // MARK: - Core Conversion Logic
    
    /// Convert integer to Japanese kanji representation
    /// - Parameter number: Integer to convert
    /// - Returns: Japanese kanji string
    public static func numberToKanji(_ number: Int) -> String {
        if number == 0 {
            return "零"
        }
        
        if number < 0 {
            return "マイナス" + numberToKanji(-number)
        }
        
        var result = ""
        var remaining = number
        
        for (unitValue, unitName) in units {
            if remaining >= unitValue {
                let quotient = remaining / unitValue
                
                // Special handling for 10, 100, 1000
                if unitValue == 10 || unitValue == 100 || unitValue == 1000 {
                    if quotient == 1 {
                        // 一十 → 十, 一百 → 百, 一千 → 千
                        result += unitName
                    } else {
                        result += digitToKanji(quotient) + unitName
                    }
                } else {
                    // For 万 and 億, always include the number
                    if unitValue >= 10000 {
                        result += numberToKanji(quotient) + unitName
                    } else {
                        result += digitToKanji(quotient)
                    }
                }
                
                remaining %= unitValue
            }
        }
        
        // Remaining single digits
        if remaining > 0 {
            result += digitToKanji(remaining)
        }
        
        return result
    }
    
    private static func digitToKanji(_ digit: Int) -> String {
        return digitNames[digit] ?? String(digit)
    }
    
    // MARK: - Helper
    
    private static func extractNumber(from match: String) -> Int? {
        let digits = match.filter { $0.isNumber }
        return Int(digits)
    }
    
    // MARK: - Hiragana Support
    
    // MARK: - Advanced Processing
    
    /// Main convert function logic
    private static func convertNumberWithContext(_ text: String) -> String {
        // Since we are now called on isolated numeric strings by TextNormalizer (mostly), 
        // the regex context matching (e.g. "(\d{4})年") won't work if the input is just "2024".
        // HOWEVER, for `convertToHiragana` (Stub Mode), we might still pass full text?
        // Let's support both.
        
        // If input contains only digits, convert directly.
        if Int(text) != nil {
            return processGeneralNumber(text)
        }
        
        // If input contains mixed text, use the context processors.
        var result = text
        result = processYear(result)
        result = processMonth(result)
        result = processDay(result)
        result = processTime(result)
        result = processGeneralNumber(result)
        return result
    }
    
    // MARK: - Counter Support (For Hiragana Conversion)
    
    /// Dictionary of common counters and their phonetic changes (Euphony/音便)
    /// Key: Counter Kanji, Value: Reading type
    private enum CounterType {
        case h_group // は, ひ, ふ, へ, ほ (Changes to p/b: 一本/いっぽん, 三本/さんぼん)
        case k_group // か, き, く, け, こ (Changes to g: ?) No, K usually doubles: 一回/いっかい, 六回/ろっかい
        case s_group // さ, し, す, せ, そ (一歳/いっさい, 八歳/はっさい)
        case t_group // た, ち, つ, て, と (一通/いっつう, 八通/はっつう)
        case w_group // わ (一羽/いちわ -> いっぱ/さんば?)
        case n_normal // No special change usually
    }
    
    /// Simplified counter processor for direct Hiragana conversion
    /// Matches common patterns: 数字 + カウンター
    public static func convertToHiragana(_ text: String) -> String {
        // 1. Convert Kanji-Numbers first (simplified approach)
        // Actually, for counters, we need to know the number value to determine reading.
        // "一本" -> "いっぽん", "二本" -> "にほん"
        // Regex for Number + Common Counters
        
        var result = text
        
        // Define common counters and their readings map
        let counters: [String: [Int: String]] = [
            "人": [1: "ひとり", 2: "ふたり", -1: "にん"], // -1 is default suffix
            "つ": [1: "ひとつ", 2: "ふたつ", 3: "みっつ", 4: "よっつ", 5: "いつつ", 6: "むっつ", 7: "ななつ", 8: "やっつ", 9: "ここのつ", 10: "とお", -1: ""],
            "日": [1: "ついたち", 2: "ふつか", 3: "みっか", 4: "よっか", 5: "いつか", 6: "むいか", 7: "なのか", 8: "ようか", 9: "ここのか", 10: "とおか", 20: "はつか", -1: "にち"],
            // Specific Euphony Counters
            "本": [1: "いっぽん", 3: "さんぼん", 6: "ろっぽん", 8: "はっぽん", 10: "じゅっぽん", -1: "ほん"],
            "回": [1: "いっかい", 6: "ろっかい", 8: "はっかい", 10: "じゅっかい", -1: "かい"],
            "階": [1: "いっかい", 3: "さんがい", 6: "ろっかい", 8: "はっかい", 10: "じゅっかい", -1: "かい"],
            "個": [1: "いっこ", 6: "ろっこ", 8: "はっこ", 10: "じゅっこ", -1: "こ"],
            "匹": [1: "いっぴき", 3: "さんびき", 6: "ろっぴき", 8: "はっぴき", 10: "じゅっぴき", -1: "ひき"],
            "百": [3: "さんびゃく", 6: "ろっぴゃく", 8: "はっぴゃく", -1: "ひゃく"],
            "千": [3: "さんぜん", 8: "はっせん", -1: "せん"]
        ]
        
        for (counter, readings) in counters {
            // Regex: (\d+)(Counter)
            let pattern = #"(\d+)"# + counter
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsText = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
            
            for match in matches.reversed() {
                let numRange = match.range(at: 1)
                let numStr = nsText.substring(with: numRange)
                guard let num = Int(numStr) else { continue }
                
                var replacement = ""
                
                // Check exact match
                if let specific = readings[num] {
                    replacement = specific
                } else {
                    // Default suffix
                    let suffix = readings[-1] ?? ""
                    
                    // Special logic for generic number reading?
                    // E.g. "12人" -> "じゅう" + "に" + "にん" -> "じゅうににん"
                    // "14日" -> "じゅう" + "よっか"
                    
                    // Recursive decomposition is complex.
                    // Simple approach: Convert number to Hiragana + suffix
                    let numReading = numberToHiragana(num) // Basic reading
                    replacement = numReading + suffix
                }
                
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        
        // Specific fixes for counters
        result = result.replacingOccurrences(of: "さんひゃく", with: "さんびゃく") // 300
        result = result.replacingOccurrences(of: "ろくひゃく", with: "ろっぴゃく") // 600
        result = result.replacingOccurrences(of: "はちひゃく", with: "はっぴゃく") // 800
        result = result.replacingOccurrences(of: "さんせん", with: "さんぜん")     // 3000
        result = result.replacingOccurrences(of: "はちせん", with: "はっせん")     // 8000
        
        // Ordinals (Stub Mode Support)
        result = result.replacingOccurrences(of: "第", with: "だい")
        result = result.replacingOccurrences(of: "番目", with: "ばんめ")
        
        // Finally convert remaining numbers to basic Kanji then Hiragana?
        // No, convert remaining numbers to bare Hiragana readings
        result = processRemainingNumbersToHiragana(result)
        
        return result
    }
    
    private static func numberToHiragana(_ number: Int) -> String {
        // Recursive basic reading
        // 123 -> ひゃくにじゅうさん
        return convertToHiraganaBasic(number)
    }
    
    private static func convertToHiraganaBasic(_ text: Any) -> String {
        // Placeholder for full int->hiragana logic
        // For now, reuse Kanji conversion -> Kanji-to-Hiragana mapping
        if let n = text as? Int {
             let kanji = numberToKanji(n)
             return mapKanjiToHiragana(kanji)
        }
        return ""
    }
    
    private static func mapKanjiToHiragana(_ kanji: String) -> String {
        var s = kanji
        s = s.replacingOccurrences(of: "零", with: "れい")
        s = s.replacingOccurrences(of: "一", with: "いち")
        s = s.replacingOccurrences(of: "二", with: "に")
        s = s.replacingOccurrences(of: "三", with: "さん")
        s = s.replacingOccurrences(of: "四", with: "よん")
        s = s.replacingOccurrences(of: "五", with: "ご")
        s = s.replacingOccurrences(of: "六", with: "ろく")
        s = s.replacingOccurrences(of: "七", with: "なな")
        s = s.replacingOccurrences(of: "八", with: "はち")
        s = s.replacingOccurrences(of: "九", with: "きゅう")
        s = s.replacingOccurrences(of: "十", with: "じゅう")
        s = s.replacingOccurrences(of: "百", with: "ひゃく")
        s = s.replacingOccurrences(of: "千", with: "せん")
        s = s.replacingOccurrences(of: "万", with: "まん")
        s = s.replacingOccurrences(of: "億", with: "おく")
        return s
    }
    
    private static func processRemainingNumbersToHiragana(_ text: String) -> String {
         let pattern = #"\d+"#
         guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
         let nsText = text as NSString
         let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
         
         var result = text
         for match in matches.reversed() {
             let numStr = nsText.substring(with: match.range)
             if let num = Int(numStr) {
                 let reading = numberToHiragana(num)
                 result = (result as NSString).replacingCharacters(in: match.range, with: reading)
             }
         }
         return result
    }
}

// MARK: - String Extension for Regex Replace

private extension String {
    func replacingOccurrences(
        of pattern: String,
        with replacement: (String) -> String,
        options: NSString.CompareOptions = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }
        
        let nsText = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: nsText.length))
        
        var result = self
        for match in matches.reversed() {
            let matchedText = nsText.substring(with: match.range)
            let replacementText = replacement(matchedText)
            result = (result as NSString).replacingCharacters(in: match.range, with: replacementText)
        }
        
        return result
    }
}
