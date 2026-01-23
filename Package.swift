// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "misaki-jp-ios",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "misaki-jp-ios",
            targets: ["misaki-jp-ios"]
        ),
    ],
    dependencies: [],
    targets: [
        // Binary Target for OpenJTalk (NJD/JPCommon processing)
        .binaryTarget(
            name: "OpenJTalk",
            path: "OpenJTalk.xcframework"
        ),
        // Standard MeCab C++ library (replaces OpenJTalk's incompatible MeCab)
        .target(
            name: "MeCab",
            dependencies: [],
            path: "Sources/MeCab",
            exclude: [
                // Exclude CLI and training tools
                "dictionary_compiler.cpp",
                "dictionary_generator.cpp",
                "dictionary_rewriter.cpp",
                "eval.cpp",
                "iconv_utils.cpp",
                "MeCabWrapper.mm",
                "MeCabWrapper.h"
            ],
            publicHeadersPath: ".",
            cSettings: [
                .define("DIC_VERSION", to: "102"),
                .define("PACKAGE", to: "\"mecab\""),
                .define("VERSION", to: "\"0.996\""),
                .define("HAVE_UNSIGNED_LONG_LONG_INT"),
            ],
            cxxSettings: [
                .define("DIC_VERSION", to: "102"),
                .define("PACKAGE", to: "\"mecab\""),
                .define("VERSION", to: "\"0.996\""),
                .define("HAVE_UNSIGNED_LONG_LONG_INT"),
            ]
        ),
        // Objective-C++ wrapper
        .target(
            name: "MisakiJPObjC",
            dependencies: ["OpenJTalk", "MeCab"],
            path: "Sources/MisakiJPObjC",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../OpenJTalk/include"),
                .headerSearchPath("../MeCab"),
            ]
        ),
        // Swift wrapper
        .target(
            name: "misaki-jp-ios",
            dependencies: ["MisakiJPObjC"],
            path: "Sources/misaki-jp-ios",
            resources: [
                .copy("Resources/UniDic")
            ]
        ),
        .testTarget(
            name: "MisakiJPTests",
            dependencies: ["misaki-jp-ios"],
            path: "Tests/MisakiJPTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
