//
//  JAG2P.swift
//  MisakiJP
//
//  Port of Python misaki.ja.JAG2P to Swift
//  Main API for Japanese Grapheme-to-Phoneme conversion
//

import Foundation
import MisakiJPObjC

/// A single tokenized morpheme with its dictionary readings.
///
/// Produced by `JAG2P.tokenize(_:)`. `read` is the orthographic modern-kana
/// reading (feature f[7], 読み) used for ASR normalization; `pron` is the
/// phonetic pronunciation (f[8], 発音) used for TTS.
public struct JAToken: Equatable {
    /// Surface form as segmented by MeCab.
    public let surface: String
    /// 読み (f[7]): orthographic katakana reading — for ASR normalization.
    /// Guaranteed non-empty (fallback chain read → pron → surface).
    public let read: String
    /// 発音 (f[8]): phonetic katakana pronunciation — for TTS.
    public let pron: String
    /// Part of speech (feature f[0]).
    public let pos: String

    public init(surface: String, read: String, pron: String, pos: String) {
        self.surface = surface
        self.read = read
        self.pron = pron
        self.pos = pos
    }
}

/// Japanese G2P - Main API matching Python misaki.ja.JAG2P
///
/// Usage:
/// ```swift
/// let g2p = JAG2P()
/// let (phonemes, pitch) = g2p("こんにちは")
/// // phonemes: "koɲɲiʨiβa"
/// ```
///
/// Note: This version works with pre-normalized hiragana input.
/// For full Japanese text support with kanji, integrate with OpenJTalk separately.
public class JAG2P {
    
    private let g2pWrapper: JapaneseG2PWrapper?
    
    public init(dicPath: String? = nil) {
        // Initialize wrapper (Stub or Real depending on compilation)
        // If dicPath is nil, try to find it. Failing that, pass empty string (init will likely return nil)
        let path = dicPath ?? Self.findUniDicPath() ?? ""
        self.g2pWrapper = JapaneseG2PWrapper(dictionaryPath: path)
    }
    
    /// Check if the library is running in fallback/stub mode (or if initialization failed)
    public var isStubMode: Bool {
        return g2pWrapper?.isStub ?? true
    }
    
    /// Main G2P function - matches Python misaki.ja.JAG2P()
    /// - Parameter text: Input Japanese text
    /// - Returns: Tuple of (phonemes, pitch accent)
    public func callAsFunction(_ text: String) -> (phonemes: String, pitch: [Int]) {
        // 1. Text normalization (includes number→kana conversion)
        // Pass isStubMode to decide whether to output Kanji (for OpenJTalk) or Hiragana (for Cutlet fallback)
        let normalized = TextNormalizer.normalize(text, toHiragana: isStubMode)
        
        // 2. G2P conversion
        // Try to get nodes from wrapper (Stub will return nil)
        if let wrapper = g2pWrapper, let nodes = wrapper.extractNodes(normalized) {
            // Full OpenJTalk mode
            let phonemes = CutletG2P.processNodes(nodes)
            let pitch = extractPitch(from: nodes)
            return (phonemes, pitch)
        } else {
            // Fallback / Stub mode: Direct hiragana conversion
            // Numbers have been converted to Hiragana by TextNormalizer in this mode
            
            if isStubMode {
                // Check if text still contains Kanji
                let hasKanji = normalized.unicodeScalars.contains { scalar in
                    // Simple check for CJK Unified Ideographs range
                    return scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
                }
                
                if hasKanji {
                    print("[MisakiJP] Warning: Kanji found in input, but library is running in Stub/Hiragana-only mode. Output may be incorrect.")
                    print("[MisakiJP] Input: \(text) -> Normalized: \(normalized)")
                }
            }
            
            let phonemes = CutletG2P.convert(normalized)
            return (phonemes, [])
        }
    }
    
    /// Get the Katakana reading (pronunciation) of the text without converting to phonemes
    /// Essential for domain alignment with BERT models trained on Katakana
    /// - Parameter text: Input Japanese text
    /// - Returns: Full Katakana reading (Yomi)
    public func getKatakanaReading(_ text: String) -> String {
        // 1. Text normalization
        // Note: For reading, we want Kanji->Katakana, so we do NOT force Hiragana stub mode unless necessary.
        let normalized = TextNormalizer.normalize(text, toHiragana: isStubMode)
        
        // 2. Extract Nodes
        if let wrapper = g2pWrapper, let nodes = wrapper.extractNodes(normalized) {
            var reading: [String] = []
            
            for node in nodes {
                // node["pron"] usually contains the Katakana reading
                if let pron = node["pron"] as? String, !pron.isEmpty {
                    reading.append(pron)
                } else if let surface = node["surface"] as? String {
                    // Fallback to surface if no pron (e.g. symbols, or untranslated)
                    // But if surface is Kanji and no pron, we are in trouble.
                    // Usually OpenJTalk guarantees valid node output.
                    reading.append(surface)
                }
            }
            
            return reading.joined()
        } else {
            // Fallback: Just return normalized text (which might be Hiragana/Kanji mix)
            // If in stub mode, TextNormalizer already converted numbers.
            // But we can't do Kanji->Kana without OpenJTalk.
            return normalized
        }
    }
    
    /// Real dictionary tokenization with per-token orthographic reading.
    ///
    /// Unlike `getKatakanaReading()` (which takes the phonetic `pron` and joins
    /// the whole utterance, losing token boundaries), this returns each MeCab
    /// token with its **orthographic** reading (`read`, feature f[7]) — the
    /// modern-kana form the ASR decoder emits (東京→トウキョウ, は→ハ, です→デス).
    ///
    /// Runs only MeCab morphological analysis via `extractNodes` — it does NOT
    /// run njd / accent estimation, so no は→ワ or long-vowel→ー phonetic
    /// post-processing is applied (that path produces `pron`, the opposite
    /// direction). Use this for ASR normalization, not `AccentPipeline`.
    ///
    /// - Parameter text: Input Japanese text.
    /// - Returns: One `JAToken` per token; `read` is guaranteed non-empty
    ///            (fallback chain read → pron → surface).
    public func tokenize(_ text: String) -> [JAToken] {
        let normalized = TextNormalizer.normalize(text, toHiragana: isStubMode)

        guard let wrapper = g2pWrapper,
              let nodes = wrapper.extractNodes(normalized) else {
            return []
        }

        var tokens: [JAToken] = []
        tokens.reserveCapacity(nodes.count)
        for node in nodes {
            let surface = (node["string"] as? String) ?? ""
            let read = (node["read"] as? String) ?? ""
            let pron = (node["pron"] as? String) ?? ""
            let pos = (node["pos"] as? String) ?? ""

            // UNK / noise nodes can have an empty read (f[7]); guarantee the
            // caller always gets a non-empty reading: read → pron → surface.
            let resolvedRead: String
            if !read.isEmpty {
                resolvedRead = read
            } else if !pron.isEmpty {
                resolvedRead = pron
            } else {
                resolvedRead = surface
            }

            tokens.append(JAToken(surface: surface,
                                  read: resolvedRead,
                                  pron: pron.isEmpty ? resolvedRead : pron,
                                  pos: pos))
        }
        return tokens
    }

    private func extractPitch(from nodes: [[String: Any]]) -> [Int] {
        var pitchAccent: [Int] = []
        for node in nodes {
            if let accentStr = node["acc"] as? String,
               let accent = Int(accentStr) {
                // OpenJTalk returns accent position (0 = flat, N = downstep at Nth mora)
                // Misaki format: array of pitch levels for each mora
                // Simple conversion: repeat accent value for word length
                if let pron = node["pron"] as? String {
                    let moraCount = pron.count // Simplified
                    pitchAccent.append(contentsOf: Array(repeating: accent, count: moraCount))
                }
            }
        }
        return pitchAccent
    }
    
    private static func findUniDicPath() -> String? {
        print("[MisakiJP Debug] 🔍 Searching for UniDic dictionary...")
        
        // Try common UniDic locations
        var candidates: [String?] = []
        
        // 1. Try Bundle.module first (works in Swift Package during development)
        #if SWIFT_PACKAGE
        if let modulePath = Bundle.module.path(forResource: "UniDic", ofType: nil) {
            print("[MisakiJP Debug] ✓ Found via Bundle.module.path: \(modulePath)")
            candidates.insert(modulePath, at: 0)
        } else {
            print("[MisakiJP Debug] ✗ Bundle.module.path(forResource: UniDic) returned nil")
        }
        
        if let moduleResourcePath = Bundle.module.resourcePath {
            let unidicPath = (moduleResourcePath as NSString).appendingPathComponent("UniDic")
            print("[MisakiJP Debug] → Bundle.module.resourcePath: \(moduleResourcePath)")
            print("[MisakiJP Debug]   Checking: \(unidicPath)")
            candidates.insert(unidicPath, at: 0)
        } else {
            print("[MisakiJP Debug] ✗ Bundle.module.resourcePath is nil")
        }
        #else
        print("[MisakiJP Debug] ⚠️ Not compiled with SWIFT_PACKAGE flag")
        #endif
        
        // 2. Try main bundle (works when embedded in app)
        if let mainPath = Bundle.main.path(forResource: "UniDic", ofType: nil) {
            print("[MisakiJP Debug] ✓ Found via Bundle.main.path: \(mainPath)")
            candidates.append(mainPath)
        } else {
            print("[MisakiJP Debug] ✗ Bundle.main.path(forResource: UniDic) returned nil")
        }
        
        if let mainResourcePath = Bundle.main.resourcePath {
            print("[MisakiJP Debug] → Bundle.main.resourcePath: \(mainResourcePath)")
            
            // Try direct UniDic subfolder
            let unidicInMain = (mainResourcePath as NSString).appendingPathComponent("UniDic")
            print("[MisakiJP Debug]   Checking: \(unidicInMain)")
            candidates.append(unidicInMain)
        } else {
            print("[MisakiJP Debug] ✗ Bundle.main.resourcePath is nil")
        }
        
        // 3. Try to find MisakiJP bundle within main bundle (for embedded SPM)
        if let mainBundlePath = Bundle.main.resourcePath {
            let bundleVariants = [
                "misaki-jp-ios_MisakiJP.bundle",
                "MisakiJP.bundle",
                "misaki_jp_ios_MisakiJP.bundle"
            ]
            
            for bundleName in bundleVariants {
                let misakiBundle = (mainBundlePath as NSString).appendingPathComponent(bundleName)
                let unidicInBundle = (misakiBundle as NSString).appendingPathComponent("UniDic")
                print("[MisakiJP Debug]   Checking SPM bundle: \(unidicInBundle)")
                candidates.append(unidicInBundle)
            }
        }
        
        // 4. Try via Bundle identifier
        let bundleIDs = ["misaki-jp-ios.MisakiJP", "com.peratalk.MisakiJP"]
        for bundleID in bundleIDs {
            if let misakiBundleID = Bundle(identifier: bundleID),
               let unidicPath = misakiBundleID.path(forResource: "UniDic", ofType: nil) {
                print("[MisakiJP Debug] ✓ Found via bundle identifier '\(bundleID)': \(unidicPath)")
                candidates.append(unidicPath)
            }
        }
        
        // 5. Fallback: check if sys.dic is nearby (in case UniDic folder name is different)
        if let sysDicPath = Bundle.main.path(forResource: "sys", ofType: "dic") {
            let parentPath = (sysDicPath as NSString).deletingLastPathComponent
            print("[MisakiJP Debug] ✓ Found via sys.dic parent: \(parentPath)")
            candidates.append(parentPath)
        }
        
        #if SWIFT_PACKAGE
        if let sysDicPath = Bundle.module.path(forResource: "sys", ofType: "dic") {
            let parentPath = (sysDicPath as NSString).deletingLastPathComponent
            print("[MisakiJP Debug] ✓ Found via module sys.dic parent: \(parentPath)")
            candidates.insert(parentPath, at: 0)
        }
        #endif

        
        // 6. Try relative path from source file location (for local SPM development)
        // This is a fallback for when the package is being developed locally
        let sourceBasedPaths = [
            "../../../misaki-jp-ios/Sources/MisakiJP/Resources/UniDic",
            "../../Sources/MisakiJP/Resources/UniDic",
            "./Resources/UniDic"
        ]
        
        for relPath in sourceBasedPaths {
            if let currentPath = Bundle.main.bundlePath as String? {
                let fullPath = (currentPath as NSString).appendingPathComponent(relPath)
                let normalized = (fullPath as NSString).standardizingPath
                print("[MisakiJP Debug]   Checking relative: \(normalized)")
                candidates.append(normalized)
            }
        }
        
        // 7. System path (rarely works on iOS, but try anyway)
        candidates.append("/usr/local/lib/mecab/dic/unidic")
        
        // Validate candidates
        let fm = FileManager.default
        print("[MisakiJP Debug] 📋 Validating \(candidates.compactMap({$0}).count) candidate paths...")
        
        for (index, path) in candidates.compactMap({ $0 }).enumerated() {
            let sysDic = (path as NSString).appendingPathComponent("sys.dic")
            print("[MisakiJP Debug] [\(index + 1)] Testing: \(sysDic)")
            
            if fm.fileExists(atPath: sysDic) {
                // Verify it's readable and has reasonable size
                if let attrs = try? fm.attributesOfItem(atPath: sysDic),
                   let size = attrs[.size] as? Int64 {
                    let sizeMB = Double(size) / 1024.0 / 1024.0
                    print("[MisakiJP Debug] ✅ FOUND valid UniDic at: \(path)")
                    print("[MisakiJP Debug]    sys.dic size: \(String(format: "%.1f", sizeMB)) MB")
                    
                    if sizeMB < 50 {
                        print("[MisakiJP Debug] ⚠️ Warning: sys.dic seems small (\(String(format: "%.1f", sizeMB)) MB), may be corrupted")
                    }
                    
                    return path
                }
            }
        }
        
        print("[MisakiJP Debug] ❌ UniDic dictionary not found in any location!")
        print("[MisakiJP Debug] Debug Info:")
        print("[MisakiJP Debug]   Bundle.main.bundlePath: \(Bundle.main.bundlePath)")
        print("[MisakiJP Debug]   Bundle.main.resourcePath: \(Bundle.main.resourcePath ?? "nil")")
        #if SWIFT_PACKAGE
        print("[MisakiJP Debug]   Bundle.module.resourcePath: \(Bundle.module.resourcePath ?? "nil")")
        print("[MisakiJP Debug]   Bundle.module.bundlePath: \(Bundle.module.bundlePath)")
        #endif
        
        return nil
    }

}

// MARK: - String Extension

private extension String {
    func deletingLastPathComponent() -> String {
        return (self as NSString).deletingLastPathComponent
    }
}
