# MisakiJP-iOS

MisakiJP-iOS 是一个适用于 iOS 和 macOS 的高性能日语字素转音素 (G2P) 库。它是 [Misaki](https://github.com/hexgrad/misaki) 的 Swift 移植版，集成了 OpenJTalk 后端，提供强大的文本标准化和注音功能。

[English](README.md) | [中文](README_zh.md) | [日本語](README_ja.md)

## 特性

- **Swift 友好**: 纯 Swift API，易于集成。
- **强大的 G2P**: 由 OpenJTalk (内置) 驱动，提供准确的汉字转假名和声调生成。
- **独立运行**: 无需外部系统依赖；包含标准的 MeCab 和 OpenJTalk 库。
- **详细输出**: 提供音素、声调重音和完整的上下文标签。
- **零配置**: 包含优化的 UniDic 词典。

## 安装

使用 Swift Package Manager 将此包添加到您的项目中：

```swift
dependencies: [
    .package(url: "https://github.com/your-username/misaki-jp-ios.git", from: "1.0.0")
]
```

## 使用方法

### 基础注音 (Phonemization)

```swift
import misaki_jp_ios

let g2p = JAG2P()
let (phonemes, pitch) = g2p("こんにちは")

print(phonemes) // "koɲɲiʨiβa"
print(pitch)    // [0, 1, 1, 1, 1]
```

### 完整分析 (Nodes)

您可以访问包括词性 (POS)、发音和重音块在内的详细词级信息。

```swift
if let wrapper = g2p.wrapper {
    let nodes = wrapper.extractNodes("東京は日本の首都です")
    for node in nodes {
        print(node)
    }
}
```

### 文本标准化

```swift
// 标准化全角/半角和 Unicode 形式 (NFKC)，保留假名
let normalized = TextNormalizer.normalize("１２３あいう")
// 输出: "123あいう"
```

### 数字转假名

```swift
// 将数字转换为日语读音
let reading = Num2Kana.convert("2025年1月1日")
// 输出: "二千二十五年一月一日"
```

## Credits

- **Misaki**: [hexgrad/misaki](https://github.com/hexgrad/misaki) (Python 实现)
- **OpenJTalk**: 集成的 C++ 库。
- **MeCab**: 集成的 C++ 库。
- **UniDic**: 集成的日语词典。

## License

MIT
