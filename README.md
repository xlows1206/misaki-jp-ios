# MisakiJP-iOS

MisakiJP-iOS is a high-performance Japanese Grapheme-to-Phoneme (G2P) library for iOS and macOS. It is a Swift port of [Misaki](https://github.com/hexgrad/misaki) with an integrated OpenJTalk backend for robust text normalization and phonemization.

[English](README.md) | [中文](README_zh.md) | [日本語](README_ja.md)

## Features

- **Swift Friendly**: Pure Swift API for easy integration.
- **Robust G2P**: Powered by OpenJTalk (bundled) for accurate Kanji-to-Kana and accent generation.
- **Standalone**: No external system dependencies; includes standard MeCab and OpenJTalk libraries.
- **Detailed Output**: Provides phonemes, pitch accent, and full-context labels.

## Installation

Add this package to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/misaki-jp-ios.git", from: "1.0.0")
]
```

## Usage

### Basic Phonemization

```swift
import misaki_jp_ios

let g2p = JAG2P()
let (phonemes, pitch) = g2p("こんにちは")

print(phonemes) // "koɲɲiʨiβa"
print(pitch)    // [0, 1, 1, 1, 1]
```

### Full Analysis (Nodes)

You can access detailed word-level information including POS, pronunciation, and accent blocks.

```swift
if let wrapper = g2p.wrapper {
    let nodes = wrapper.extractNodes("東京は日本の首都です")
    for node in nodes {
        print(node)
    }
}
```

## Credits

- **Misaki**: [hexgrad/misaki](https://github.com/hexgrad/misaki) (Python implementation)
- **OpenJTalk**: Integrated C++ library.
- **MeCab**: Integrated C++ library.

## License

MIT
