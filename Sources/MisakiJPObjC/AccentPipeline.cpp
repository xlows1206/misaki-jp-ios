#include "AccentPipeline.hpp"

#include "mecab.h"
extern "C" {
#include "njd.h"
#include "mecab2njd.h"
#include "njd_set_accent_phrase.h"
#include "njd_set_accent_type.h"
}

#include <iostream>
#include <cstring>
#include <sys/stat.h>

// ---- Design note -----------------------------------------------------
// mecab2njd()/NJDNode_load() consume a naist-jdic-shaped 11-column CSV row
// (pos,pos_group1,pos_group2,pos_group3,ctype,cform,orig,read,pron,acc/mora,
// chain_rule) PLUS a leading surface token that MeCab's node->feature does
// not itself carry. This was verified against the actual sys.dic compiled
// into this package (prototype: /tmp/misaki-njd-poc/njd_poc_final.cpp) --
// node->feature IS already exactly that 11-column naist-jdic row, so no
// re-indexing/synthesis is required here: we just prepend the surface and
// an explicit trailing "*" chain_flag token (unset -> njd_set_accent_phrase
// derives it from POS as usual) and feed the row straight into mecab2njd.
//
// This is a DIFFERENT bug/fix than JapaneseG2P.cpp's hand-rolled field
// parser (used for reading/pron extraction), which previously assumed a
// 29-column UniDic schema and has been corrected separately to naist-jdic
// indices. AccentPipeline never parses feature fields itself for the njd
// feed -- OpenJTalk's own NJDNode_load() does that internally using its
// native (correct) naist-jdic column layout.
static std::string buildNaistStyleFeatureRow(const mecab_node_t* n) {
    std::string surface(n->surface, n->length);
    std::string row;
    row.reserve(surface.size() + std::strlen(n->feature) + 4);
    row += surface;
    row += ',';
    row += n->feature; // already naist-jdic 11-column CSV
    row += ",*";        // chain_flag: unset, let njd_set_accent_phrase decide
    return row;
}

struct AccentPipeline::Impl {
    mecab_t* tagger = nullptr;
    bool loaded = false;

    explicit Impl(const std::string& dictionaryPath) {
        struct stat info;
        if (stat(dictionaryPath.c_str(), &info) != 0 || !(info.st_mode & S_IFDIR)) {
            std::cerr << "[AccentPipeline] dictionary path invalid: " << dictionaryPath << std::endl;
            return;
        }
        std::string args = "-d " + dictionaryPath + " -r /dev/null";
        tagger = mecab_new2(args.c_str());
        if (!tagger) {
            std::cerr << "[AccentPipeline] mecab_new2 failed: " << mecab_strerror(nullptr) << std::endl;
            return;
        }
        loaded = true;
    }

    ~Impl() {
        if (tagger) {
            mecab_destroy(tagger);
            tagger = nullptr;
        }
    }

    std::vector<AccentNode> computeAccents(const std::string& text) {
        std::vector<AccentNode> result;
        if (!loaded) return result;

        const mecab_node_t* node = mecab_sparse_tonode(tagger, text.c_str());
        if (!node) {
            std::cerr << "[AccentPipeline] mecab_sparse_tonode failed" << std::endl;
            return result;
        }

        // Build the naist-jdic-style rows mecab2njd expects. Keep the
        // std::string storage alive for the lifetime of this call -- the
        // char* array handed to mecab2njd only borrows into it.
        std::vector<std::string> rows;
        for (const mecab_node_t* n = node; n; n = n->next) {
            if (n->stat == MECAB_BOS_NODE || n->stat == MECAB_EOS_NODE) continue;
            if (!n->feature) continue;
            rows.push_back(buildNaistStyleFeatureRow(n));
        }
        if (rows.empty()) return result;

        std::vector<char*> cfeat;
        cfeat.reserve(rows.size());
        for (auto& s : rows) cfeat.push_back(const_cast<char*>(s.c_str()));

        NJD njd;
        NJD_initialize(&njd);

        // IMPORTANT: mecab2njd() loads nodes into njd.head. Do NOT call
        // NJD_refresh() here -- empirically (see prototype) it strips
        // freshly-loaded nodes; that cleanup step belongs later in a real
        // open_jtalk pipeline (e.g. after njd_remove_silent_node()), not
        // immediately after loading.
        mecab2njd(&njd, cfeat.data(), (int)cfeat.size());

        njd_set_accent_phrase(&njd);
        njd_set_accent_type(&njd);

        for (NJDNode* n = njd.head; n; n = n->next) {
            AccentNode out;
            const char* surfaceC = NJDNode_get_string(n);
            const char* posC = NJDNode_get_pos(n);
            out.surface = surfaceC ? surfaceC : "";
            out.pos = posC ? posC : "";
            out.accentType = NJDNode_get_acc(n);
            out.moraCount = NJDNode_get_mora_size(n);
            out.chainFlag = NJDNode_get_chain_flag(n);
            result.push_back(std::move(out));
        }

        // NJD is a hand-managed C linked list (NJDNode_initialize/NJDNode_clear
        // internals) -- NJD_clear() frees every node it owns. Balanced 1:1 with
        // NJD_initialize() above; no node pointer is retained past this point.
        NJD_clear(&njd);

        return result;
    }
};

AccentPipeline::AccentPipeline(const std::string& dictionaryPath)
    : pImpl(std::make_unique<Impl>(dictionaryPath)) {}

AccentPipeline::~AccentPipeline() = default;

bool AccentPipeline::isLoaded() const {
    return pImpl && pImpl->loaded;
}

std::vector<AccentNode> AccentPipeline::computeAccents(const std::string& text) {
    if (!pImpl) return {};
    return pImpl->computeAccents(text);
}
