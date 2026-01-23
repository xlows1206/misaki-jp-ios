#pragma once

#include <string>
#include <vector>
#include <memory>

// Forward declaration to hide implementation details and OpenJTalk headers
// from the Swift/Objective-C++ header bridge if possible.
struct OpenJTalkNode {
    std::string string;
    std::string pron;
    std::string pos;
    int acc;
    int mora_size;
    int chain_flag;
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
