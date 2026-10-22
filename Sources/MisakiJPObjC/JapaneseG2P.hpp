#pragma once

#include <string>
#include <vector>
#include <memory>

// Forward declaration to hide implementation details and OpenJTalk headers
// from the Swift/Objective-C++ header bridge if possible.
struct OpenJTalkNode {
    std::string string;
    std::string read;   // 読み (f[7]): orthographic modern-kana reading (東京→トウキョウ, は→ハ)
    std::string pron;   // 発音 (f[8]): phonetic pronunciation (東京→トーキョー, は→ワ)
    std::string pos;
    int acc;
    int mora_size;
    int chain_flag;
    // Extra dictionary fields (naist-jdic / IPADIC 11-column layout). Empty when the
    // dictionary has "*" for the column.
    std::string pos1;   // f[1] 品詞細分類1
    std::string pos2;   // f[2] 品詞細分類2
    std::string pos3;   // f[3] 品詞細分類3
    std::string ctype;  // f[4] 活用型
    std::string cform;  // f[5] 活用形
    std::string orig;   // f[6] 原形 (for chained entries: this part's orig only)
    // Span of the MeCab node surface in the input text, in UTF-8 BYTES.
    // `surface` == input.substr(begin, length): the true input slice. For a chained
    // (離合) dictionary entry the first part carries the whole node span; later parts
    // (chain_flag == 1) have surface == "" and length == 0, begin == end of the span.
    // NOTE `string` keeps its legacy meaning (for chained entries interior parts hold
    // their dictionary orig form, the last part the full surface) and is NOT the slice.
    std::string surface;
    int begin;
    int length;
};

class JapaneseG2P {
public:
    // Initialize with path to the dictionary directory (containing dicrc, etc.)
    JapaneseG2P(const std::string& dictionaryPath);
    ~JapaneseG2P();
    
    // Original method (flat phonemes)
    std::vector<std::string> extractPhonemes(const std::string& text);
    // Debug method
    std::vector<std::string> extractFullContextLabels(const std::string& text);
    
    // New method: Extract structured word nodes + accent logic
    std::vector<OpenJTalkNode> extractNodes(const std::string& text);
    
private:
    struct Impl;
    std::unique_ptr<Impl> pImpl;
};
