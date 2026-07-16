//
//  AccentPipeline.swift
//  MisakiJP
//
//  Public Swift API for the full OpenJTalk sentence-context accent pipeline:
//  mecab2njd -> njd_set_accent_phrase -> njd_set_accent_type.
//
//  Unlike JAG2P.getKatakanaReading()/extractPitch (which read isolated
//  per-node dictionary fields), this runs the real accent-phrase merge and
//  chain-rule accent recomputation OpenJTalk uses, so compound words and
//  particle downsteps come out with their true sentence-context accent
//  rather than each morpheme's isolated citation-form accent.
//

import Foundation
import MisakiJPObjC

/// One accent-phrase-aware node produced by the full njd pipeline.
public struct AccentNode {
    /// Surface form of this node (as segmented by MeCab/NJD).
    public let surface: String
    /// Part-of-speech tag (NJD's own POS string, e.g. "名詞").
    public let pos: String
    /// Mora index of the pitch drop within this node's accent phrase.
    /// 0 = heiban (no drop / flat).
    public let accentType: Int
    /// Number of morae in this node.
    public let moraCount: Int
    /// true when this node was merged into the accent phrase started by the
    /// previous node (does NOT start a new accent phrase); false when it
    /// starts a new accent phrase.
    public let chainFlag: Bool

    public init(surface: String, pos: String, accentType: Int, moraCount: Int, chainFlag: Bool) {
        self.surface = surface
        self.pos = pos
        self.accentType = accentType
        self.moraCount = moraCount
        self.chainFlag = chainFlag
    }
}

/// A resolved accent phrase: one or more consecutive AccentNodes merged by
/// njd_set_accent_phrase, with a single sentence-context accentType/moraCount
/// pair -- this is the granularity that maps onto VOICEVOX's `accent_type`
/// field (which is itself per accent-phrase, not per morpheme).
public struct AccentPhrase {
    /// Concatenated surface of every node in this phrase.
    public let surface: String
    /// Total morae across every node in this phrase.
    public let moraCount: Int
    /// Mora index of the pitch drop within this phrase (absolute offset
    /// across the WHOLE merged phrase, not relative to any one node), or 0
    /// if heiban (no drop). OpenJTalk's njd_set_accent_type writes the
    /// phrase's final resolved accent onto the FIRST (phrase-starting,
    /// chain_flag != 1) node -- trailing merged nodes keep their own
    /// original/isolated per-morpheme accent as vestigial data, not the
    /// phrase's real value. Verified against the prototype's raw
    /// njd_set_accent_type dump for 東京都庁 (東京 node ends up FINAL_acc=5,
    /// i.e. mora 5 of the 7-mora compound == where 都庁's own accent
    /// nucleus falls once merged; 都庁 node itself is left at its stale
    /// isolated acc=1) and for 食べません (食べ node ends up FINAL_acc=4,
    /// landing inside ん as Japanese speakers actually pronounce it; ませ/ん
    /// keep their stale isolated values). See AccentPipelineTests.
    public let accentType: Int
    /// The individual nodes that were merged into this phrase, in order.
    public let nodes: [AccentNode]
}

public class AccentPipeline {

    private let wrapper: AccentPipelineWrapper?

    public init(dicPath: String? = nil) {
        let path = dicPath ?? Self.findUniDicPath() ?? ""
        self.wrapper = AccentPipelineWrapper(dictionaryPath: path)
    }

    /// true if the underlying MeCab dictionary failed to load.
    public var isStubMode: Bool {
        return wrapper == nil
    }

    /// Run the full accent pipeline and return one AccentNode per surviving
    /// NJD node (morpheme granularity, already reflecting sentence-context
    /// accent-phrase merges and chain-rule recomputation).
    public func computeAccents(_ text: String) -> [AccentNode] {
        guard let wrapper = wrapper, let raw = wrapper.computeAccents(text) else { return [] }
        return raw.compactMap { dict -> AccentNode? in
            guard let surface = dict["surface"] as? String,
                  let pos = dict["pos"] as? String,
                  let accentType = dict["accent_type"] as? Int,
                  let moraCount = dict["mora_count"] as? Int,
                  let chainFlagRaw = dict["chain_flag"] as? Int else { return nil }
            return AccentNode(surface: surface, pos: pos, accentType: accentType,
                               moraCount: moraCount, chainFlag: chainFlagRaw == 1)
        }
    }

    /// Same as computeAccents(_:) but pre-grouped into accent phrases
    /// (consecutive chainFlag==true nodes merged with the phrase-starting
    /// node before them). This is the granularity callers should use when
    /// injecting into VOICEVOX's per-word `accent_type` field for a furigana
    /// surface that may itself be a multi-morpheme compound.
    public func computeAccentPhrases(_ text: String) -> [AccentPhrase] {
        let nodes = computeAccents(text)
        var phrases: [AccentPhrase] = []
        var current: [AccentNode] = []

        func flush() {
            guard !current.isEmpty else { return }
            let surface = current.map { $0.surface }.joined()
            let moraCount = current.reduce(0) { $0 + $1.moraCount }
            // njd_set_accent_type resolves the phrase's real accent onto the
            // FIRST (phrase-starting) node -- see the accentType doc comment
            // on AccentPhrase for why trailing merged nodes must NOT be used.
            let accentType = current.first?.accentType ?? 0
            phrases.append(AccentPhrase(surface: surface, moraCount: moraCount,
                                         accentType: accentType, nodes: current))
            current = []
        }

        for node in nodes {
            if node.chainFlag {
                current.append(node)
            } else {
                flush()
                current.append(node)
            }
        }
        flush()
        return phrases
    }

    /// Convenience: look up the accent phrase whose concatenated surface
    /// exactly equals `surface` (e.g. a furigana-annotated compound word),
    /// or nil if no single phrase matches exactly.
    public func accentPhrase(forSurface surface: String, inSentence sentence: String) -> AccentPhrase? {
        return computeAccentPhrases(sentence).first { $0.surface == surface }
    }

    private static func findUniDicPath() -> String? {
        var candidates: [String?] = []

        #if SWIFT_PACKAGE
        candidates.insert(Bundle.module.path(forResource: "UniDic", ofType: nil), at: 0)
        if let moduleResourcePath = Bundle.module.resourcePath {
            candidates.insert((moduleResourcePath as NSString).appendingPathComponent("UniDic"), at: 0)
        }
        #endif

        candidates.append(Bundle.main.path(forResource: "UniDic", ofType: nil))
        if let mainResourcePath = Bundle.main.resourcePath {
            candidates.append((mainResourcePath as NSString).appendingPathComponent("UniDic"))
        }
        if let mainBundlePath = Bundle.main.resourcePath {
            for bundleName in ["misaki-jp-ios_MisakiJP.bundle", "MisakiJP.bundle", "misaki_jp_ios_MisakiJP.bundle"] {
                let misakiBundle = (mainBundlePath as NSString).appendingPathComponent(bundleName)
                candidates.append((misakiBundle as NSString).appendingPathComponent("UniDic"))
            }
        }

        let fm = FileManager.default
        for path in candidates.compactMap({ $0 }) {
            let sysDic = (path as NSString).appendingPathComponent("sys.dic")
            if fm.fileExists(atPath: sysDic) {
                return path
            }
        }
        return nil
    }
}
