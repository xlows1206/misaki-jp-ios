#pragma once

#include <string>
#include <vector>
#include <memory>

// One entry per NJD node surviving the full OpenJTalk accent pipeline
// (mecab2njd -> njd_set_accent_phrase -> njd_set_accent_type), i.e. after
// accent-phrase merging and chain-rule accent recomputation have already
// happened. `accentType` and `moraCount` are therefore sentence-context
// values, not isolated dictionary lookups.
struct AccentNode {
    std::string surface;
    std::string pos;
    int accentType;   // mora index of the pitch drop (0 = heiban/no drop)
    int moraCount;
    // 1 when this node was merged into the accent phrase started by the
    // previous node (i.e. it does NOT start a new accent phrase); 0 when it
    // starts a new accent phrase.
    int chainFlag;
};

// Wraps the sequence validated by the njd-pipeline prototype:
//   NJD_initialize -> mecab2njd -> njd_set_accent_phrase -> njd_set_accent_type
//   -> (read out accent/mora/chain data) -> NJD_clear
//
// Each call to computeAccents() owns a fresh NJD list for the lifetime of the
// call only; no state is kept between calls beyond the MeCab tagger itself.
class AccentPipeline {
public:
    explicit AccentPipeline(const std::string& dictionaryPath);
    ~AccentPipeline();

    // Returns false if the MeCab dictionary failed to load.
    bool isLoaded() const;

    // Runs the full sentence-context accent pipeline over `text` and returns
    // one AccentNode per surviving NJD node, in reading order.
    std::vector<AccentNode> computeAccents(const std::string& text);

private:
    struct Impl;
    std::unique_ptr<Impl> pImpl;
};
