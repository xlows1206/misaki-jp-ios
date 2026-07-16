import XCTest
@testable import misaki_jp_ios

final class Num2KanaTests: XCTestCase {
    
    func testBasicNumbers() {
        XCTAssertEqual(Num2Kana.numberToKanji(0), "零")
        XCTAssertEqual(Num2Kana.numberToKanji(1), "一")
        XCTAssertEqual(Num2Kana.numberToKanji(10), "十")
        XCTAssertEqual(Num2Kana.numberToKanji(100), "百")
        XCTAssertEqual(Num2Kana.numberToKanji(1000), "千")
    }
    
    func testCompoundNumbers() {
        XCTAssertEqual(Num2Kana.numberToKanji(11), "十一")
        XCTAssertEqual(Num2Kana.numberToKanji(21), "二十一")
        XCTAssertEqual(Num2Kana.numberToKanji(123), "百二十三")
        XCTAssertEqual(Num2Kana.numberToKanji(1234), "千二百三十四")
    }
    
    func testLargeNumbers() {
        XCTAssertEqual(Num2Kana.numberToKanji(10000), "一万")
        XCTAssertEqual(Num2Kana.numberToKanji(100000000), "一億")
        XCTAssertEqual(Num2Kana.numberToKanji(2024), "二千二十四")
    }
    
    func testYearConversion() {
        let input = "2024年"
        let result = Num2Kana.convert(input)
        XCTAssertTrue(result.contains("二千二十四年"), "Got: \(result)")
    }
    
    func testMonthConversion() {
        let input = "12月"
        let result = Num2Kana.convert(input)
        XCTAssertTrue(result.contains("十二月"), "Got: \(result)")
    }
    
    func testFullDateConversion() {
        let input = "2024年12月25日"
        let result = Num2Kana.convert(input)
        print("Date conversion: \(input) → \(result)")
        XCTAssertTrue(result.contains("二千二十四"))
        XCTAssertTrue(result.contains("十二"))
        XCTAssertTrue(result.contains("二十五"))
    }
    
    func testPriceConversion() {
        let input = "123円です"
        let result = Num2Kana.convert(input)
        print("Price conversion: \(input) → \(result)")
        XCTAssertTrue(result.contains("百二十三"))
    }
}

final class TextNormalizerTests: XCTestCase {
    
    func testUnicodeNormalization() {
        // Test NFKC normalization
        let input = "ＡＢＣ１２３"  // Full-width
        let result = TextNormalizer.normalize(input)
        print("Unicode normalization: \(input) → \(result)")
        // Should contain number conversion
        XCTAssertNotEqual(result, input)
        XCTAssertTrue(result.contains("ABC"))
        XCTAssertTrue(result.contains("ひゃくにじゅうさん"))
    }
    
    func testNumberInText() {
        let input = "これは123円です"
        let result = TextNormalizer.normalize(input)
        print("Text with number: \(input) → \(result)")
        XCTAssertTrue(result.contains("ひゃくにじゅうさん"))
    }
}

final class CutletG2PTests: XCTestCase {
    
    func testBasicPhonemes() {
        let hiragana = "こんにちは"
        let phonemes = CutletG2P.convert(hiragana)
        print("Basic phonemes: \(hiragana) → \(phonemes)")
        XCTAssertEqual(phonemes, "koɲɲiʨiβa")
    }
    
    func testLongVowelNormalization() {
        // Test that our normalizeRepeatedVowels works
        let hiragana = "とうきょう"  // Tokyo with ou→ō
        let phonemes = CutletG2P.convert(hiragana)
        print("Long vowel: \(hiragana) → \(phonemes)")
        XCTAssertTrue(phonemes.contains("ː"), "Should contain long vowel mark: \(phonemes)")
    }
}
