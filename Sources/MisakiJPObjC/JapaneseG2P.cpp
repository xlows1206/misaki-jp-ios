#include "JapaneseG2P.hpp"

// Standard MeCab C API (from misaki-jp-ios/Sources/MeCab/)
#include "mecab.h"

#include <iostream>
#include <cstring>
#include <sys/stat.h>
#include <fstream>
#include <vector>
#include <sstream>

// naist-jdic feature field indices -- VERIFIED against the actual sys.dic
// compiled into this package's Resources/UniDic (not just the dicrc's
// comments, which describe a 29-column UniDic schema that does NOT match
// what's actually baked into sys.dic). Verification method: a standalone
// MeCab CLI build (Sources/MeCab is plain portable C++, no OpenJTalk
// binary needed) loaded this exact dictionary and printed raw node->feature
// for real sentences, e.g.:
//   東京   -> "名詞,固有名詞,地域,一般,*,*,東京,トウキョウ,トーキョー,0/4,C2"
//   ませ   -> "助動詞,*,*,*,特殊・マス,未然形,ます,マセ,マセ,1/2,動詞%F4@1/助詞%F2@1"
// 11 comma-separated fields, matching classic naist-jdic layout exactly
// (this is also the layout mecab2njd()/NJDNode_load() expect natively --
// see AccentPipeline.cpp).
//
// f[0]:  pos          (品詞1)
// f[1]:  pos_group1    (品詞2)
// f[2]:  pos_group2    (品詞3)
// f[3]:  pos_group3    (品詞4)
// f[4]:  ctype         (活用型)
// f[5]:  cform         (活用形)
// f[6]:  orig          (原形)
// f[7]:  read          (読み)
// f[8]:  pron          (発音)
// f[9]:  acc/mora      ("N/M", or "N1/M1:N2/M2:..." for a dictionary entry
//                        that packs multiple chained morphemes -- see below)
// f[10]: chain_rule
//
// Chained/compound entries: some naist-jdic entries (typically fixed
// expressions like 感動詞 "ありがとうございます") store MULTIPLE morphemes
// in a single dictionary row, with orig/read/pron/acc EACH colon-separated
// per sub-morpheme, e.g. for "ありがとうございます":
//   orig = "ありがとう:ございます"
//   pron = "アリガトー:ゴザイマス'"
//   acc  = "2/5:4/5"
// OpenJTalk's own NJDNode_load() (njd_node.c) splits these into N separate
// NJDNodes; extractNodes() below does the equivalent for this flatter node
// representation, splitting on ':' the same way, so callers (e.g.
// getKatakanaReading()) get clean per-morpheme readings instead of the raw
// colon-joined dictionary row. This was the root cause of the T-ticket bug
// (ありがとうございます -> "2/5:4/5"): the OLD field-index heuristic here
// failed to recognize f[9] as the accent field specifically BECAUSE it
// contains a ':' (its "looks like accent" check only allowed digits and
// '/'), fell back to a hard-coded wrong default index, and the raw acc/mora
// string leaked straight into the "pron" output.

static std::vector<std::string> splitFeatureCSV(const char* feature) {
    std::vector<std::string> fields;
    std::string current;
    bool inQuotes = false;
    for (const char* p = feature; *p; ++p) {
        if (*p == '"') {
            inQuotes = !inQuotes;
        } else if (*p == ',' && !inQuotes) {
            fields.push_back(current);
            current.clear();
        } else {
            current += *p;
        }
    }
    fields.push_back(current);
    for (auto& v : fields) {
        if (v.size() >= 2 && v.front() == '"' && v.back() == '"') {
            v = v.substr(1, v.size() - 2);
        }
        if (v == "*") v.clear();
    }
    return fields;
}

static std::vector<std::string> splitOn(const std::string& s, char delim) {
    std::vector<std::string> parts;
    std::string cur;
    for (char c : s) {
        if (c == delim) { parts.push_back(cur); cur.clear(); }
        else cur += c;
    }
    parts.push_back(cur);
    return parts;
}

// Count moras in a katakana string (small kana / long-vowel mark don't add
// a new mora; sokuon ッ does).
static int countMoras(const std::string& kana) {
    static const char* small[] = {
        "ァ","ィ","ゥ","ェ","ォ","ャ","ュ","ョ", nullptr
    };
    int moraCount = 0;
    for (size_t i = 0; i < kana.size(); ) {
        unsigned char c = kana[i];
        int len = (c < 0x80) ? 1 : (c < 0xE0) ? 2 : (c < 0xF0) ? 3 : 4;
        std::string cp = kana.substr(i, len);
        bool isSmall = false;
        for (int k = 0; small[k]; k++) if (cp == small[k]) { isSmall = true; break; }
        if (cp != "ー" && !isSmall) moraCount++;
        i += len;
    }
    return moraCount;
}

struct JapaneseG2P::Impl {
    mecab_t* tagger;
    bool loaded;

    Impl(const std::string& dictionaryPath) : tagger(nullptr), loaded(false) {
        struct stat info;
        if (stat(dictionaryPath.c_str(), &info) != 0 || !(info.st_mode & S_IFDIR)) {
            std::cerr << "[JapaneseG2P] dictionary path invalid: " << dictionaryPath << std::endl;
            return;
        }
        std::string sysDicPath = dictionaryPath + "/sys.dic";
        if (stat(sysDicPath.c_str(), &info) != 0) {
            std::cerr << "[JapaneseG2P] sys.dic not found at: " << sysDicPath << std::endl;
            return;
        }

        std::string args = "-d " + dictionaryPath + " -r /dev/null";
        tagger = mecab_new2(args.c_str());
        if (tagger) {
            loaded = true;
        } else {
            std::cerr << "[JapaneseG2P] mecab_new2 failed: " << mecab_strerror(nullptr) << std::endl;
        }
    }

    ~Impl() {
        if (tagger) {
            mecab_destroy(tagger);
            tagger = nullptr;
        }
    }

    std::vector<std::string> extractPhonemes(const std::string& text) {
        std::vector<std::string> result;
        if (!loaded) return result;

        const mecab_node_t* node = mecab_sparse_tonode(tagger, text.c_str());
        if (!node) return result;

        for (const mecab_node_t* n = node; n; n = n->next) {
            if (n->stat != MECAB_NOR_NODE && n->stat != MECAB_UNK_NODE) continue;
            auto fields = splitFeatureCSV(n->feature);
            if (fields.size() > 8 && !fields[8].empty()) {
                // pron may be colon-joined for chained entries; emit each part.
                for (auto& p : splitOn(fields[8], ':')) {
                    if (!p.empty()) result.push_back(p);
                }
            }
        }
        return result;
    }

    std::vector<std::string> extractFullContextLabels(const std::string& text) {
        return extractPhonemes(text);
    }

    std::vector<OpenJTalkNode> extractNodes(const std::string& text) {
        std::vector<OpenJTalkNode> nodes;
        if (!loaded) {
            std::cerr << "[JapaneseG2P] not loaded" << std::endl;
            return nodes;
        }

        const mecab_node_t* node = mecab_sparse_tonode(tagger, text.c_str());
        if (!node) {
            std::cerr << "[JapaneseG2P] parseToNode failed" << std::endl;
            return nodes;
        }

        for (const mecab_node_t* n = node; n; n = n->next) {
            if (n->stat != MECAB_NOR_NODE && n->stat != MECAB_UNK_NODE) continue;

            auto fields = splitFeatureCSV(n->feature);
            std::string pos     = fields.size() > 0 ? fields[0] : "";
            std::string orig    = fields.size() > 6 ? fields[6] : "";
            std::string read    = fields.size() > 7 ? fields[7] : "";
            std::string pron    = fields.size() > 8 ? fields[8] : "";
            std::string accMora = fields.size() > 9 ? fields[9] : "";

            std::string surface(n->surface, n->length);

            // Chained/compound entry: orig/read/pron/acc are each colon-
            // separated per sub-morpheme (see file-level comment above).
            // Split them in lockstep and emit one OpenJTalkNode per part,
            // mirroring OpenJTalk's own NJDNode_load() chain-splitting so
            // callers never see raw "reading1:reading2" / "acc1/mora1:acc2/mora2"
            // garbage.
            std::vector<std::string> origParts = splitOn(orig, ':');
            std::vector<std::string> readParts = splitOn(read, ':');
            std::vector<std::string> pronParts = splitOn(pron, ':');
            std::vector<std::string> accParts  = splitOn(accMora, ':');
            size_t partCount = std::max(std::max(origParts.size(), readParts.size()),
                                         std::max(pronParts.size(), accParts.size()));
            if (partCount == 0) partCount = 1;

            for (size_t i = 0; i < partCount; i++) {
                OpenJTalkNode info;
                info.pos = pos;
                info.pron = i < pronParts.size() ? pronParts[i] : "";
                if (info.pron.empty()) {
                    info.pron = i < readParts.size() ? readParts[i] : "";
                }

                // Only the final chain-part keeps the node's real MeCab surface
                // span; earlier parts use their dictionary orig form, same as
                // OpenJTalk's own NJDNode_load() (which likewise has no way to
                // recover the exact original character span for interior
                // chain parts -- the surface bytes only exist as one run).
                if (partCount > 1 && i + 1 < partCount) {
                    info.string = i < origParts.size() ? origParts[i] : "";
                } else {
                    info.string = surface;
                }

                int acc = 0, mora = 0;
                if (i < accParts.size() && !accParts[i].empty()) {
                    auto accMoraParts = splitOn(accParts[i], '/');
                    if (!accMoraParts.empty() && !accMoraParts[0].empty()) {
                        try { acc = std::stoi(accMoraParts[0]); } catch (...) { acc = 0; }
                    }
                    if (accMoraParts.size() > 1 && !accMoraParts[1].empty()) {
                        try { mora = std::stoi(accMoraParts[1]); } catch (...) { mora = 0; }
                    }
                }
                if (mora <= 0) {
                    mora = countMoras(info.pron);
                }
                info.acc = acc;
                info.mora_size = mora;
                info.chain_flag = (partCount > 1 && i > 0) ? 1 : 0;

                nodes.push_back(info);
            }
        }

        return nodes;
    }
};

JapaneseG2P::JapaneseG2P(const std::string& dictionaryPath)
    : pImpl(std::make_unique<Impl>(dictionaryPath)) {}

JapaneseG2P::~JapaneseG2P() = default;

std::vector<std::string> JapaneseG2P::extractPhonemes(const std::string& text) {
    return pImpl->extractPhonemes(text);
}

std::vector<std::string> JapaneseG2P::extractFullContextLabels(const std::string& text) {
    return pImpl->extractFullContextLabels(text);
}

std::vector<OpenJTalkNode> JapaneseG2P::extractNodes(const std::string& text) {
    return pImpl->extractNodes(text);
}
