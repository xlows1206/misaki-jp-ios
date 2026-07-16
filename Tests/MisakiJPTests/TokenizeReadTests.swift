import XCTest
@testable import misaki_jp_ios

/// Tests for `JAG2P.tokenize(_:)` — per-token orthographic reading (f[7], 読み).
///
/// These assert `read` returns the *orthographic* modern-kana form (the form
/// the ASR decoder emits), NOT the phonetic `pron` (f[8]). The two diverge on:
///   東京   read=トウキョウ  vs  pron=トーキョー
///   は     read=ハ          vs  pron=ワ
///   です   read=デス        vs  pron=デス’ (apostrophe)
///   氷     read=コオリ      vs  pron=コーリ
///
/// Requires the real bundled naist-jdic (default `JAG2P()`), so these run on
/// the iOS Simulator (macOS `swift test` can't load the iOS-only OpenJTalk
/// slice) — same constraint as the rest of the suite.
final class TokenizeReadTests: XCTestCase {

    var g2p: JAG2P!

    override func setUp() {
        super.setUp()
        // Default init → finds real bundled dictionary → full MeCab path.
        g2p = JAG2P()
    }

    /// Guard: if the real dictionary isn't loaded the suite is meaningless.
    private func requireRealDict() throws {
        if g2p.tokenize("東京").isEmpty {
            throw XCTSkip("Real naist-jdic not loaded (stub mode) — tokenize tests need the bundled dictionary.")
        }
    }

    func testTokyoOrthographicNotPhonetic() throws {
        try requireRealDict()
        let tokens = g2p.tokenize("東京")
        XCTAssertEqual(tokens.count, 1, "東京 should be a single token")
        XCTAssertEqual(tokens[0].read, "トウキョウ", "read must be orthographic トウキョウ, not pron トーキョー")
        XCTAssertEqual(tokens[0].pron, "トーキョー", "pron should still be the phonetic トーキョー")
    }

    func testParticleHaAndDesuOrthographic() throws {
        try requireRealDict()
        let tokens = g2p.tokenize("私は学生です")

        let ha = tokens.first { $0.surface == "は" }
        XCTAssertNotNil(ha, "should segment the particle は")
        XCTAssertEqual(ha?.read, "ハ", "particle は read must be ハ (orthographic), not ワ (pron)")

        let desu = tokens.first { $0.surface == "です" }
        XCTAssertNotNil(desu, "should segment です")
        XCTAssertEqual(desu?.read, "デス", "です read must be デス with no phonetic apostrophe")
        XCTAssertFalse(desu?.read.contains("’") ?? true, "read must not carry the pron apostrophe")
    }

    func testSanjuuSegmentsAndJuuReadsJuu() throws {
        try requireRealDict()
        let tokens = g2p.tokenize("三十")
        // 十 must not be stranded as a lone とお/トオ reading.
        let juu = tokens.first { $0.surface == "十" }
        XCTAssertNotNil(juu, "三十 should segment out 十")
        XCTAssertEqual(juu?.read, "ジュウ", "十 read must be ジュウ, never トオ")
        let joined = tokens.map { $0.read }.joined()
        XCTAssertFalse(joined.contains("トオ"), "no token should read トオ")
    }

    func testKooriAndOokiiOrthographic() throws {
        try requireRealDict()
        let koori = g2p.tokenize("氷")
        XCTAssertEqual(koori.first?.read, "コオリ", "氷 read must be コオリ, not コーリ")

        let ookii = g2p.tokenize("大きい")
        XCTAssertEqual(ookii.first?.read, "オオキイ", "大きい read must be オオキイ, not オーキイ")
    }

    func testCompoundColonSplitAligned() throws {
        try requireRealDict()
        // ありがとうございます is ONE naist-jdic node whose read/pron are each
        // colon-joined (read='アリガトウ:ゴザイマス'). The lockstep split must
        // yield aligned per-morpheme tokens with NO raw colon leaking through.
        let tokens = g2p.tokenize("ありがとうございます")
        XCTAssertEqual(tokens.count, 2, "compound should split into 2 morphemes")
        XCTAssertEqual(tokens.map { $0.read }, ["アリガトウ", "ゴザイマス"],
                       "read segments must align per-morpheme after colon split")
        for t in tokens {
            XCTAssertFalse(t.read.contains(":"), "no colon should leak into read: \(t.read)")
            XCTAssertFalse(t.read.isEmpty, "read must never be empty")
        }
    }

    func testKatakanaLongVowelPreservedInRead() throws {
        try requireRealDict()
        let tokens = g2p.tokenize("コーヒー")
        XCTAssertEqual(tokens.first?.read, "コーヒー", "コーヒー read must keep the ー long-vowel mark")
    }

    func testReadNeverEmpty() throws {
        try requireRealDict()
        // Every token's read is guaranteed non-empty (fallback read→pron→surface).
        for text in ["東京", "私は学生です", "三十", "氷", "大きい", "ありがとうございます", "コーヒー"] {
            for t in g2p.tokenize(text) {
                XCTAssertFalse(t.read.isEmpty, "read empty for surface '\(t.surface)' in '\(text)'")
            }
        }
    }
}
