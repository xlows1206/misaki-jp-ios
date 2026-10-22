import XCTest
@testable import misaki_jp_ios

/// Tests for the extra MeCab node fields (pos1-3, ctype, cform, orig, begin, length)
/// and `JAG2P.tokenizeRaw(_:)`.
///
/// The JAToken default tests need no dictionary. The rest need the real bundled
/// dictionary (iOS Simulator; macOS `swift test` cannot link the iOS-only OpenJTalk
/// slice) and skip themselves in stub mode.
final class TokenizeExtraFieldsTests: XCTestCase {

    func testLegacyInitDefaults() {
        let t = JAToken(surface: "東京", read: "トウキョウ", pron: "トーキョー", pos: "名詞")
        XCTAssertEqual(t.pos1, "")
        XCTAssertEqual(t.pos2, "")
        XCTAssertEqual(t.pos3, "")
        XCTAssertEqual(t.ctype, "")
        XCTAssertEqual(t.cform, "")
        XCTAssertEqual(t.orig, "")
        XCTAssertEqual(t.begin, 0)
        XCTAssertEqual(t.length, 6)
        XCTAssertEqual(t, JAToken(surface: "東京", read: "トウキョウ", pron: "トーキョー", pos: "名詞"))
    }

    private func rawTokens(_ text: String) throws -> [JAToken] {
        let g2p = JAG2P()
        guard let tokens = g2p.tokenizeRaw(text) else {
            throw XCTSkip("Real naist-jdic not loaded (stub mode).")
        }
        return tokens
    }

    func testTokenizeRawNilInStubMode() {
        let g2p = JAG2P(dicPath: "/nonexistent/dictionary")
        XCTAssertTrue(g2p.isStubMode)
        XCTAssertNil(g2p.tokenizeRaw("食べます"))
    }

    func testTokenizeRawDoesNotNormalize() throws {
        // Full-width digits would be NFKC/number-expanded by tokenize(); raw keeps them.
        let text = "１２３"
        let tokens = try rawTokens(text)
        XCTAssertEqual(tokens.map(\.surface).joined(), text)
    }

    func testSurfacesConcatenateAndOffsetsAreUTF8Bytes() throws {
        for text in ["毎日朝ごはんを食べます。", "食べさせられた", "ありがとうございます", "電話番号を教えてください", "ディスった"] {
            let tokens = try rawTokens(text)
            XCTAssertEqual(tokens.map(\.surface).joined(), text, text)
            let bytes = Array(text.utf8)
            for t in tokens {
                let slice = String(decoding: bytes[t.begin ..< t.begin + t.length], as: UTF8.self)
                XCTAssertEqual(slice, t.surface, "\(text): offset slice mismatch")
            }
        }
    }

    func testRawChainedEntryTrueSurface() throws {
        let tokens = try rawTokens("ありがとうございます")
        XCTAssertEqual(tokens.map(\.surface), ["ありがとうございます", ""])
        XCTAssertEqual(tokens[1].length, 0)
        XCTAssertEqual(tokens[0].orig, "ありがとう")
        XCTAssertEqual(tokens[1].orig, "ございます")
    }

    /// tokenize() must keep the legacy `surface` semantics for chained entries.
    func testTokenizeChainedEntryLegacySurfacePinned() throws {
        let g2p = JAG2P()
        let tokens = g2p.tokenize("ありがとうございます")
        if tokens.isEmpty { throw XCTSkip("stub mode") }
        XCTAssertEqual(tokens.map(\.surface), ["ありがとう", "ありがとうございます"])
        // The true-slice span is still exposed through begin/length (normalized text).
        XCTAssertEqual(tokens[0].length, "ありがとうございます".utf8.count)
        XCTAssertEqual(tokens[1].length, 0)
    }

    func testConjugationFields() throws {
        let t = try rawTokens("食べました")
        XCTAssertEqual(t[0].surface, "食べ")
        XCTAssertEqual(t[0].ctype, "一段")
        XCTAssertEqual(t[0].cform, "連用形")
        XCTAssertEqual(t[0].orig, "食べる")
        XCTAssertEqual(t[0].pos1, "自立")

        let n = try rawTokens("食べないで")
        let nai = n.first { $0.surface == "ない" }
        XCTAssertEqual(nai?.cform, "連用デ接続")
    }

    func testTokenizeFillsNewFields() throws {
        let g2p = JAG2P()
        let tokens = g2p.tokenize("食べます")
        if tokens.isEmpty { throw XCTSkip("stub mode") }
        XCTAssertEqual(tokens[0].orig, "食べる")
        XCTAssertEqual(tokens[0].begin, 0)
        XCTAssertEqual(tokens[0].length, 6)
    }
}
