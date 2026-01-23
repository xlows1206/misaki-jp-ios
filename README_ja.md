# MisakiJP-iOS

MisakiJP-iOSは、iOSおよびmacOS向けの高性能な日本語Grapheme-to-Phoneme (G2P) ライブラリです。[Misaki](https://github.com/hexgrad/misaki) のSwift移植版であり、OpenJTalkバックエンドを統合して、堅牢なテキスト正規化と音素変換を提供します。

[English](README.md) | [中文](README_zh.md) | [日本語](README_ja.md)

## 特徴

- **Swiftフレンドリー**: 統合が容易なピュアSwift API。
- **堅牢なG2P**: OpenJTalk（バンドル済み）により、正確な漢字かな変換とアクセント生成を実現。
- **スタンドアローン**: 外部システム依存なし。標準的なMeCabおよびOpenJTalkライブラリを内包。
- **詳細な出力**: 音素、ピッチアクセント、フルコンテキストラベルを提供。
- **ゼロ設定**: 最適化されたUniDic辞書を同梱。

## インストール

Swift Package Managerを使用して、プロジェクトにこのパッケージを追加します：

```swift
dependencies: [
    .package(url: "https://github.com/your-username/misaki-jp-ios.git", from: "1.0.0")
]
```

## 使い方

### 基本的な音素変換

```swift
import misaki_jp_ios

let g2p = JAG2P()
let (phonemes, pitch) = g2p("こんにちは")

print(phonemes) // "koɲɲiʨiβa"
print(pitch)    // [0, 1, 1, 1, 1]
```

### 詳細分析 (Nodes)

品詞 (POS)、発音、アクセントブロックを含む詳細な単語レベルの情報にアクセスできます。

```swift
if let wrapper = g2p.wrapper {
    let nodes = wrapper.extractNodes("東京は日本の首都です")
    for node in nodes {
        print(node)
    }
}
```

### テキスト正規化

```swift
// 全角/半角およびUnicode形式 (NFKC) を正規化（かなは保持）
let normalized = TextNormalizer.normalize("１２３あいう")
// 出力: "123あいう"
```

### 数字かな変換

```swift
// 数字を日本語の読みに変換
let reading = Num2Kana.convert("2025年1月1日")
// 出力: "二千二十五年一月一日"
```

## クレジット

- **Misaki**: [hexgrad/misaki](https://github.com/hexgrad/misaki) (Python実装)
- **OpenJTalk**: 統合されたC++ライブラリ。
- **MeCab**: 統合されたC++ライブラリ。
- **UniDic**: 統合された日本語辞書。

## License

MIT
