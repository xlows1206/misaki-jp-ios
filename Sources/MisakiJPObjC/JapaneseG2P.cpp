#include "JapaneseG2P.hpp"

// Standard MeCab C API (from misaki-jp-ios/Sources/MeCab/)
#include "mecab.h"

#include <iostream>
#include <cstring>
#include <sys/stat.h>
#include <fstream>
#include <vector>
#include <sstream>

// UniDic feature field indices (from dicrc)
// f[0]:  pos1 (品詞大分類)
// f[1]:  pos2 (品詞中分類)
// f[2]:  pos3 (品詞小分類)
// f[3]:  pos4 (品詞細分類)
// f[9]:  pron (発音/カタカナ発音)
// f[20]: kana (読み/カタカナ)
// f[24]: aType (アクセント型)

struct JapaneseG2P::Impl {
    mecab_t* tagger;
    bool loaded;
    
    Impl(const std::string& dictionaryPath) : tagger(nullptr), loaded(false) {
        std::cerr << "[MeCab Debug] Attempting to load dictionary..." << std::endl;
        std::cerr << "[MeCab Debug] Dictionary path: " << dictionaryPath << std::endl;
        
        // Verify path exists
        struct stat info;
        if (stat(dictionaryPath.c_str(), &info) != 0) {
            std::cerr << "[MeCab Error] Path does not exist: " << dictionaryPath << std::endl;
            return;
        } else if (!(info.st_mode & S_IFDIR)) {
            std::cerr << "[MeCab Error] Path is not a directory: " << dictionaryPath << std::endl;
            return;
        }
        
        std::cerr << "[MeCab Debug] Path verified as directory" << std::endl;
        
        // Check for sys.dic
        std::string sysDicPath = dictionaryPath + "/sys.dic";
        struct stat sysDicInfo;
        if (stat(sysDicPath.c_str(), &sysDicInfo) == 0) {
            std::cerr << "[MeCab Debug] sys.dic found at: " << sysDicPath << std::endl;
            std::cerr << "[MeCab Debug] sys.dic size: " << sysDicInfo.st_size << " bytes" << std::endl;
        } else {
            std::cerr << "[MeCab Error] sys.dic not found at: " << sysDicPath << std::endl;
            return;
        }
        
        // Use standard MeCab API: mecab_new2("-d path -r /dev/null")
        std::string args = "-d " + dictionaryPath + " -r /dev/null";
        std::cerr << "[MeCab Debug] Calling Mecab_load (standard API)..." << std::endl;
        std::cerr << "[MeCab Debug] Args: " << args << std::endl;
        
        tagger = mecab_new2(args.c_str());
        
        if (tagger) {
            loaded = true;
            std::cerr << "[MeCab Debug] Mecab_load returned: 1" << std::endl;
            std::cerr << "[MeCab Debug] ✅ MeCab loaded successfully (standard API)" << std::endl;
            
            // Print dictionary info
            const mecab_dictionary_info_t* dicInfo = mecab_dictionary_info(tagger);
            if (dicInfo) {
                std::cerr << "[MeCab Debug] Dictionary: " << (dicInfo->filename ? dicInfo->filename : "unknown") << std::endl;
                std::cerr << "[MeCab Debug] Charset: " << (dicInfo->charset ? dicInfo->charset : "unknown") << std::endl;
            }
        } else {
            std::cerr << "[MeCab Error] ❌ Failed to create tagger" << std::endl;
            std::cerr << "[MeCab Error] Last error: " << mecab_strerror(nullptr) << std::endl;
        }
    }
    
    ~Impl() {
        if (tagger) {
            mecab_destroy(tagger);
            tagger = nullptr;
        }
    }
    
    // Parse UniDic feature CSV and extract specific field
    std::string getFeatureField(const char* feature, int index) {
        if (!feature) return "";
        
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
        
        if (index < (int)fields.size()) {
            std::string val = fields[index];
            // Remove surrounding quotes if present
            if (val.size() >= 2 && val.front() == '"' && val.back() == '"') {
                val = val.substr(1, val.size() - 2);
            }
            // Return empty for placeholder "*"
            if (val == "*") return "";
            return val;
        }
        return "";
    }
    
    // Parse accent type from UniDic format (e.g., "0" or "0,2")
    int parseAccentType(const std::string& aType) {
        if (aType.empty()) return 0;
        // Take first number before comma
        size_t comma = aType.find(',');
        std::string first = comma != std::string::npos ? aType.substr(0, comma) : aType;
        try {
            return std::stoi(first);
        } catch (...) {
            return 0;
        }
    }
    
    // Count moras in a katakana string
    int countMoras(const std::string& kana) {
        // Small kana don't count as separate moras
        static const char* smallKana[] = {
            "ァ", "ィ", "ゥ", "ェ", "ォ", "ャ", "ュ", "ョ", nullptr
        };
        
        int moraCount = 0;
        const char* p = kana.c_str();
        while (*p) {
            // Get UTF-8 character length
            int charLen = 1;
            if ((*p & 0xF0) == 0xF0) charLen = 4;
            else if ((*p & 0xE0) == 0xE0) charLen = 3;
            else if ((*p & 0xC0) == 0xC0) charLen = 2;
            
            std::string ch(p, charLen);
            
            // Check if it's a small kana
            bool isSmall = false;
            for (const char** sk = smallKana; *sk; ++sk) {
                if (ch == *sk) {
                    isSmall = true;
                    break;
                }
            }
            
            // Long vowel mark is not a separate mora
            if (ch != "ー" && !isSmall) {
                moraCount++;
            }
            
            p += charLen;
        }
        return moraCount;
    }
    
    std::vector<std::string> extractPhonemes(const std::string& text) {
        std::vector<std::string> result;
        
        if (!loaded) {
            std::cerr << "Mecab not loaded" << std::endl;
            return result;
        }
        
        const mecab_node_t* node = mecab_sparse_tonode(tagger, text.c_str());
        if (!node) {
            std::cerr << "[MeCab Error] parseToNode failed" << std::endl;
            return result;
        }
        
        // Collect pronunciations from UniDic
        for (const mecab_node_t* n = node; n; n = n->next) {
            if (n->stat == MECAB_NOR_NODE || n->stat == MECAB_UNK_NODE) {
                // Get pronunciation (f[9]) from UniDic
                std::string pron = getFeatureField(n->feature, 9);
                if (!pron.empty()) {
                    result.push_back(pron);
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
            std::cerr << "Mecab not loaded" << std::endl;
            return nodes;
        }
        
        std::cerr << "[MeCab Debug] extractNodes input: " << text << std::endl;
        
        const mecab_node_t* node = mecab_sparse_tonode(tagger, text.c_str());
        if (!node) {
            std::cerr << "[MeCab Error] parseToNode failed" << std::endl;
            return nodes;
        }
        
        // Extract node info directly from UniDic features
        for (const mecab_node_t* n = node; n; n = n->next) {
            if (n->stat == MECAB_NOR_NODE || n->stat == MECAB_UNK_NODE) {
                OpenJTalkNode info;
                
                // Surface form
                info.string = std::string(n->surface, n->length);
                
                // POS (f[0])
                info.pos = getFeatureField(n->feature, 0);
                
                // Pronunciation (f[9] - カタカナ発音)
                info.pron = getFeatureField(n->feature, 9);
                if (info.pron.empty()) {
                    // Fallback to kana (f[20])
                    info.pron = getFeatureField(n->feature, 20);
                }
                
                // Accent type (f[24])
                std::string aType = getFeatureField(n->feature, 24);
                info.acc = parseAccentType(aType);
                
                // Mora size (count from pronunciation)
                info.mora_size = countMoras(info.pron);
                
                // Chain flag - set to 0 for now (would need multi-word analysis)
                info.chain_flag = 0;
                
                // Debug: print raw feature string
                std::cerr << "[MeCab Debug] Raw feature: " << n->feature << std::endl;
                
                // Debug: parse and print all fields
                std::vector<std::string> debugFields;
                std::string debugCurrent;
                bool debugInQuotes = false;
                for (const char* dp = n->feature; *dp; ++dp) {
                    if (*dp == '"') {
                        debugInQuotes = !debugInQuotes;
                    } else if (*dp == ',' && !debugInQuotes) {
                        debugFields.push_back(debugCurrent);
                        debugCurrent.clear();
                    } else {
                        debugCurrent += *dp;
                    }
                }
                debugFields.push_back(debugCurrent);
                
                std::cerr << "[MeCab Debug] Field count: " << debugFields.size() << std::endl;
                for (size_t fi = 0; fi < debugFields.size() && fi < 30; ++fi) {
                    std::cerr << "[MeCab Debug]   f[" << fi << "]: " << debugFields[fi] << std::endl;
                }
                
                // Auto-detect field indices if not already found
                int pronIndex = 9;  // Default UniDic
                int accIndex = 24;  // Default UniDic
                
                // Scan fields to find best candidates
                int candidatePron = -1;
                int candidateAcc = -1;
                
                for (size_t i = 0; i < debugFields.size(); ++i) {
                    const std::string& field = debugFields[i];
                    if (field == "*" || field.empty()) continue;
                    
                    // Check for Pronunciation (Katakana)
                    // Simple heuristic: check if string contains Katakana range bytes
                    // UTF-8 Katakana: E3 82 A0 - E3 83 BF
                    bool isKatakana = true;
                    bool hasKatakana = false;
                    for (size_t c = 0; c < field.length(); ) {
                        unsigned char uc = (unsigned char)field[c];
                        if (uc >= 0xE3 && c+2 < field.length()) {
                            unsigned char uc2 = (unsigned char)field[c+1];
                            // unsigned char uc3 = (unsigned char)field[c+2];
                            if (uc == 0xE3 && (uc2 >= 0x82 && uc2 <= 0x83)) {
                                hasKatakana = true;
                                c += 3;
                            } else if (uc == 0xE3 && uc2 == 0x81 && field[c+2] == 0x9B) { 
                                // Long vowel mark ー (E3 81 9B) often in Hiragana block too? 
                                // Actually ー is E3 83 BC in Katakana block usually.
                                // Let's simplify: just look for HIGH BIT chars that aren't digits
                                c += 3;
                            } else {
                                // Maybe Kanji or Hiragana
                                if (uc2 < 0x80) { isKatakana = false; break; } // ASCII
                                c += 3; // Assume 3-byte UTF8
                            }
                        } else if (uc == '-' || uc == '!') {
                            c++; // Allowed chars
                        } else {
                            // Non-katakana char (e.g. digit, ascii)
                            isKatakana = false;
                            break;
                        }
                    }
                    
                    // Specific Katakana check (more robust)
                    bool looksLikePron = true;
                    for (size_t c = 0; c < field.length(); ) {
                        unsigned char uc = (unsigned char)field[c];
                         if (uc < 0x80) {
                            if (uc != '!' && uc != '?' && uc != '-') { 
                                looksLikePron = false; break; 
                            }
                            c++;
                         } else {
                             // Check for Katakana block E3 82 xx - E3 83 xx
                             if (uc == 0xE3 && c+2 < field.length()) {
                                 unsigned char uc2 = (unsigned char)field[c+1];
                                 if (uc2 >= 0x82 && uc2 <= 0x83) {
                                     c += 3; continue;
                                 }
                             }
                             looksLikePron = false; break;
                         }
                    }
                    
                    if (looksLikePron && field.length() > 0) {
                        // Prefer LATER fields if multiple match.
                        // Typically: [Surface] ... [Reading/f7] [Pronunciation/f8] [Accent/f9]
                        // We want Pronunciation (f8) because it handles particles correctly (e.g. Ha -> Wa).
                        // Note: If f8 contains symbols like ' (e.g. デス’), it will be rejected by checks above, 
                        // so we correctly fall back to f7 (Reading).
                        candidatePron = (int)i;
                    }
                    
                    // Check for Accent (Integer or N/M format)
                    // Format: "0", "1", "0,2", "0/4"
                    bool isDigitOrSlash = true;
                    bool hasDigit = false;
                    for (char c : field) {
                        if (!isdigit(c) && c != '/' && c != ',') {
                            isDigitOrSlash = false;
                            break;
                        }
                        if (isdigit(c)) hasDigit = true;
                    }
                    if (isDigitOrSlash && hasDigit) {
                        // Usually accent is later in the list
                        if (i > 15) candidateAcc = (int)i; 
                    }
                }
                
                // Override indices if detection seems better
                // User reported f[9] was "0/5" (accent-like).
                // So if f[9] looks like accent, we DEFINITELY need to move.
                std::string valAt9 = (9 < debugFields.size()) ? debugFields[9] : "";
                bool f9IsAcc = false;
                 for (char c : valAt9) { if (isdigit(c) || c=='/') f9IsAcc=true; else if(c!='*'){f9IsAcc=false; break;} }
                
                if (f9IsAcc && candidatePron != -1) {
                    std::cerr << "[MeCab Fix] f[9] looks like Accent '" << valAt9 << "', switching Pron to f[" << candidatePron << "]" << std::endl;
                    pronIndex = candidatePron;
                    
                    // CRITICAL FIX: If f[9] is the accent field (Format: Accent/Mora, e.g. "0/5"), 
                    // we MUST use it for accent info. The default f[24] is empty/invalid in this dictionary.
                    accIndex = 9;  // Force accIndex to 9
                    std::cerr << "[MeCab Fix] Also switching Acc to f[9] to capture '" << valAt9 << "'" << std::endl;
                }
                
                if (candidateAcc != -1 && candidateAcc != accIndex && !f9IsAcc) { // Only search if we haven't found it at f9
                     // Only switch if current accIndex is clearly wrong (e.g. out of bounds or empty)
                     if (accIndex >= debugFields.size() || debugFields[accIndex] == "*" || debugFields[accIndex].empty()) {
                         std::cerr << "[MeCab Fix] Switching Acc to f[" << candidateAcc << "]" << std::endl;
                         accIndex = candidateAcc;
                     }
                }
                
                std::cerr << "[MeCab Debug] Using indices :: Pron: " << pronIndex << ", Acc: " << accIndex << std::endl;

                std::cerr << "[MeCab Debug] Node: surface='" << info.string 
                          << "' pron='" << info.pron 
                          << "' pos='" << info.pos 
                          << "' acc=" << info.acc 
                          << " mora=" << info.mora_size << std::endl;
                
                // RE-READ with correct indices
                info.pron = getFeatureField(n->feature, pronIndex);
                if (info.pron.empty()) info.pron = getFeatureField(n->feature, 20); // Fallback
                
                std::string aTypeRaw = getFeatureField(n->feature, accIndex);
                
                // Special handling for "Accent/Mora" format (e.g., "0/5")
                // Standard parseAccentType handles "0,2" but maybe not "0/5" correctly if not robust.
                // Let's ensure we handle the slash.
                size_t slashPos = aTypeRaw.find('/');
                if (slashPos != std::string::npos) {
                    try {
                        std::string accPart = aTypeRaw.substr(0, slashPos);
                        info.acc = std::stoi(accPart);
                        
                        // We can also trust the mora count from here if valid
                        std::string moraPart = aTypeRaw.substr(slashPos + 1);
                        int parsedMora = std::stoi(moraPart);
                        if (parsedMora > 0) {
                             info.mora_size = parsedMora;
                             // Note: We'll still count moras from pron below as a fallback/verification, 
                             // but we should prefer this if the dictionary provides it explicitly.
                        }
                    } catch (...) {
                        info.acc = 0;
                    }
                } else {
                    info.acc = parseAccentType(aTypeRaw);
                }
                
                // If we didn't get mora size from the feature (or it wasn't the slash format), calculate it
                if (slashPos == std::string::npos) {
                    info.mora_size = countMoras(info.pron);
                }
                
                // Detailed Verification Log
                std::cerr << "[MeCab Verification] Index [" << pronIndex << "] (Pron): '" << info.pron << "'" << std::endl;
                std::cerr << "[MeCab Verification] Index [" << accIndex << "] (Acc): '" << aTypeRaw << "' -> parsed=" << info.acc << std::endl;
                std::cerr << "[MeCab Corrected] Node: surface='" << info.string 
                          << "' pron='" << info.pron 
                          << "' acc=" << info.acc 
                          << " mora=" << info.mora_size 
                          << " pos='" << info.pos << "'" << std::endl;
                
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
