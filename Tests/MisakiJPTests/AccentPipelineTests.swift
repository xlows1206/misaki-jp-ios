import XCTest
@testable import misaki_jp_ios

/// Coverage for AccentPipeline (mecab2njd -> njd_set_accent_phrase ->
/// njd_set_accent_type), and a regression check for JapaneseG2P's
/// naist-jdic field-index fix (recvpvcMVRyMc6).
///
/// NOTE: these tests require OpenJTalk.xcframework's iOS binary slice and
/// therefore only run on an iOS Simulator/device test target -- `swift
/// test` on macOS cannot link this package (OpenJTalk.xcframework ships
/// ios-arm64 / ios-arm64_x86_64-simulator slices only, no macOS slice).
/// Field-index correctness was independently verified on macOS by compiling
/// the portable (non-OpenJTalk) Sources/MeCab against the real bundled
/// sys.dic directly -- see the njd/AccentPipeline PR description for the
/// raw node->feature dumps used to derive the naist-jdic indices below.
final class AccentPipelineTests: XCTestCase {

    var pipeline: AccentPipeline!

    override func setUp() {
        super.setUp()
        pipeline = AccentPipeline()
    }

    // MARK: - The three prototype-validated scenarios

    /// Compound noun accent-phrase merge: 東京(0/4) + 都庁(1/3) in isolation,
    /// but as a compound the accent core shifts under njd's chain_rule "C1"
    /// (東京都庁 -> a single accent phrase with the pitch drop landing on the
    /// 5th mora of the merged phrase, not on 都庁's own isolated 1st mora).
    func testCompoundNounAccentShift_TokyoTochou() throws {
        try XCTSkipUnless(pipeline.isStubMode == false, "MeCab dictionary not loaded in this environment")

        let isolatedTokyo = pipeline.computeAccentPhrases("東京")
        XCTAssertEqual(isolatedTokyo.first?.accentType, 0, "東京 alone is heiban (0)")

        let isolatedTochou = pipeline.computeAccentPhrases("都庁")
        XCTAssertEqual(isolatedTochou.first?.accentType, 1, "都庁 alone drops at mora 1")

        let phrases = pipeline.computeAccentPhrases("東京都庁")
        XCTAssertEqual(phrases.count, 1, "東京都庁 should merge into a single accent phrase")
        let merged = try XCTUnwrap(phrases.first)
        XCTAssertEqual(merged.surface, "東京都庁")
        XCTAssertEqual(merged.moraCount, 7, "4 (トーキョー) + 3 (トチョー) morae")
        // Exact value verified against the prototype's njd_set_accent_type dump:
        // chain_rule "C1" shifts the compound's accent core to mora 5 (== 都庁's
        // own accent nucleus position, but expressed as an absolute offset across
        // the full 7-mora compound rather than 都庁's isolated mora 1).
        XCTAssertEqual(merged.accentType, 5)
        XCTAssertNotEqual(merged.accentType, isolatedTochou.first?.accentType,
                           "compound accent core must differ from the isolated tail word's own accent -- this is the core regression this ticket exists to fix")
    }

    /// Particle downstep: は must merge into the preceding accent phrase
    /// (chain_flag == 1), not start a new one.
    func testParticleDownstep_KyouWaYoiTenki() throws {
        try XCTSkipUnless(pipeline.isStubMode == false, "MeCab dictionary not loaded in this environment")

        let nodes = pipeline.computeAccents("今日は良い天気です")
        guard let wa = nodes.first(where: { $0.surface == "は" }) else {
            XCTFail("expected a は node")
            return
        }
        XCTAssertTrue(wa.chainFlag, "は must merge into the preceding accent phrase (助詞 downstep), not start a new one")

        let phrases = pipeline.computeAccentPhrases("今日は良い天気です")
        XCTAssertTrue(phrases.contains { $0.surface.hasPrefix("今日は") },
                      "今日 and は must land in the same accent phrase")
    }

    /// Verb + auxiliary chain: 食べ + ませ + ん must chain-rewrite accent
    /// across the whole predicate, not just report each morpheme's isolated
    /// citation-form accent.
    func testVerbAuxiliaryChain_TabemasenChain() throws {
        try XCTSkipUnless(pipeline.isStubMode == false, "MeCab dictionary not loaded in this environment")

        let nodes = pipeline.computeAccents("食べません")
        XCTAssertGreaterThanOrEqual(nodes.count, 3, "食べ/ませ/ん should tokenize as (at least) 3 morphemes")

        let phrases = pipeline.computeAccentPhrases("食べません")
        XCTAssertEqual(phrases.count, 1, "食べません is a single predicate accent phrase")
        let phrase = try XCTUnwrap(phrases.first)
        XCTAssertEqual(phrase.surface, "食べません")
        // Exact value verified against the prototype's njd_set_accent_type dump:
        // two chained auxiliary rules (動詞%F4@1 then 動詞%F4@0) rewrite the
        // predicate's accent core to mora 4, landing inside ん -- matching how
        // たべません is actually pronounced (drop going into the final ん).
        XCTAssertEqual(phrase.accentType, 4, "食べません's chain-rewritten accent core should land at mora 4 (inside ん)")
    }

    // MARK: - Sampling more real vocabulary

    func testHeibanWordsStayHeiban() throws {
        try XCTSkipUnless(pipeline.isStubMode == false, "MeCab dictionary not loaded in this environment")
        // さくら (桜) is a textbook heiban (flat, no drop) word.
        let phrases = pipeline.computeAccentPhrases("桜")
        XCTAssertEqual(phrases.first?.accentType, 0)
    }

    func testAccentPhraseNodeCountMatchesSourceMorphemes() throws {
        try XCTSkipUnless(pipeline.isStubMode == false, "MeCab dictionary not loaded in this environment")
        let phrases = pipeline.computeAccentPhrases("私は学生です")
        let totalNodes = phrases.reduce(0) { $0 + $1.nodes.count }
        XCTAssertGreaterThanOrEqual(totalNodes, 4, "私/は/学生/です should be at least 4 morphemes total")
    }

    // MARK: - Memory safety smoke test

    /// Each computeAccents() call does a fresh NJD_initialize/NJD_clear
    /// cycle; calling it many times in a row is the simplest black-box way
    /// to catch a double-free or leak-driven crash from this environment
    /// (AddressSanitizer would be the real tool, but this at least catches
    /// gross corruption deterministically).
    func testRepeatedCallsDoNotCrash() throws {
        try XCTSkipUnless(pipeline.isStubMode == false, "MeCab dictionary not loaded in this environment")
        for _ in 0..<50 {
            _ = pipeline.computeAccents("東京都庁は今日晴れです")
        }
    }
}

/// Regression coverage for the naist-jdic field-index fix in JapaneseG2P.cpp
/// (previously assumed a 29-column UniDic schema; the compiled sys.dic is
/// actually 11-column naist-jdic). Also covers the colon-chained compound
/// dictionary entry case that produced the T-ticket's "2/5:4/5" garbage
/// reading for ありがとうございます.
final class JapaneseG2PFieldIndexRegressionTests: XCTestCase {

    var g2p: JAG2P!

    override func setUp() {
        super.setUp()
        g2p = JAG2P()
    }

    func testArigatouGozaimasu_NoLongerLeaksRawAccentField() throws {
        try XCTSkipIf(g2p.isStubMode, "MeCab dictionary not loaded in this environment")
        let reading = g2p.getKatakanaReading("ありがとうございます")
        XCTAssertFalse(reading.contains("/"), "must not leak raw acc/mora field into the reading")
        XCTAssertFalse(reading.contains(":"), "must not leak the raw colon-chained dictionary row into the reading")
        XCTAssertTrue(reading.unicodeScalars.contains { $0.value >= 0x30A0 && $0.value <= 0x30FF },
                      "should be a katakana reading, not the T-ticket's numeric garbage")
    }

    func testCommonWordsStillReadCorrectly() throws {
        try XCTSkipIf(g2p.isStubMode, "MeCab dictionary not loaded in this environment")
        // Simple non-chained words must be unaffected by the index fix.
        XCTAssertEqual(g2p.getKatakanaReading("東京"), "トーキョー")
        XCTAssertEqual(g2p.getKatakanaReading("明日"), "アシタ")
    }
}
