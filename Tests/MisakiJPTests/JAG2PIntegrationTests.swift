import XCTest
@testable import misaki_jp_ios

/// Integration tests for full MisakiJP pipeline
final class JAG2PIntegrationTests: XCTestCase {
    
    var g2p: JAG2P!
    
    override func setUp() {
        super.setUp()
        // Initialize without OpenJTalk for direct hiragana mode
        g2p = JAG2P()
    }
    
    // MARK: - Direct Hiragana Mode Tests
    
    func testDirectHiraganaConversion() {
        let (phonemes, _) = g2p("こんにちは")
        print("こんにちは → \(phonemes)")
        XCTAssertEqual(phonemes, "koɲɲiʨiβa", "Direct hiragana should work")
    }
    
    func testLongVowelInDirectMode() {
        let (phonemes, _) = g2p("とうきょう")
        print("とうきょう → \(phonemes)")
        XCTAssertTrue(phonemes.contains("ː"), "Should contain long vowel mark")
    }
    
    func testNumberConversionWithG2P() {
        let (phonemes, _) = g2p("123円です")
        print("123円です → \(phonemes)")
        // 123 -> ひゃくにじゅうさん -> çakɯɲiʥɯːsaɴ
        XCTAssertTrue(phonemes.contains("çak"), "Should contain hyaku")
    }
    
    func testFullWidthNormalization() {
        let (phonemes, _) = g2p("ＡＢＣ")
        print("ＡＢＣ → \(phonemes)")
        // After normalization, ABC should be converted by Num2Kana if applicable
        // or passed through
        XCTAssertNotNil(phonemes)
    }
    
    // MARK: - Pipeline Tests
    
    func testFullPipelineIntegration() {
        let testCases = [
            "こんにちは",
            "とうきょう",
            "これは123円です",
        ]
        
        for text in testCases {
            let (phonemes, pitch) = g2p(text)
            print("[\(text)] → phonemes: '\(phonemes)', pitch: \(pitch)")
            XCTAssertFalse(phonemes.isEmpty, "Should produce phonemes for: \(text)")
        }
    }
    
    func testParticleHandling() {
        let (phonemes, _) = g2p("わたしは")
        print("わたしは → \(phonemes)")
        XCTAssertTrue(phonemes.hasSuffix("βa"), "Final は should be βa (particle)")
    }
    
    func testMultipleParticles() {
        let (phonemes, _) = g2p("がっこうへいく")
        print("がっこうへいく → \(phonemes)")
        // Should contain both ʔ (sokuon) and long vowel ː
        XCTAssertTrue(phonemes.contains("ʔ"))
        XCTAssertTrue(phonemes.contains("ː"))
    }
}
