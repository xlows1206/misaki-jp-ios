
#import "JapaneseG2PWrapper.h"
#include "JapaneseG2P.hpp"
#include <string>
#include <vector>

@implementation JapaneseG2PWrapper {
    std::unique_ptr<JapaneseG2P> _g2p;
}

- (nullable instancetype)initWithDictionaryPath:(NSString *)dictionaryPath {
    self = [super init];
    if (self) {
        NSLog(@"[JapaneseG2PWrapper] 🔧 Initializing with dictionary path: %@", dictionaryPath);
        
        // Verify path exists before attempting to load
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        BOOL exists = [fm fileExistsAtPath:dictionaryPath isDirectory:&isDirectory];
        
        if (!exists) {
            NSLog(@"[JapaneseG2PWrapper] ❌ Error: Dictionary path does not exist: %@", dictionaryPath);
            return nil;
        }
        
        if (!isDirectory) {
            NSLog(@"[JapaneseG2PWrapper] ❌ Error: Dictionary path is not a directory: %@", dictionaryPath);
            return nil;
        }
        
        // Check for sys.dic
        NSString *sysDicPath = [dictionaryPath stringByAppendingPathComponent:@"sys.dic"];
        if (![fm fileExistsAtPath:sysDicPath]) {
            NSLog(@"[JapaneseG2PWrapper] ❌ Error: sys.dic not found at: %@", sysDicPath);
            return nil;
        }
        
        NSDictionary *attrs = [fm attributesOfItemAtPath:sysDicPath error:nil];
        unsigned long long fileSize = [attrs fileSize];
        NSLog(@"[JapaneseG2PWrapper] ✓ sys.dic found, size: %.1f MB", fileSize / 1024.0 / 1024.0);
        
        try {
            std::string path = [dictionaryPath UTF8String];
            _g2p = std::make_unique<JapaneseG2P>(path);
            NSLog(@"[JapaneseG2PWrapper] ✅ Initialized successfully");
        } catch (const std::exception& e) {
            NSLog(@"[JapaneseG2PWrapper] ❌ C++ exception during init: %s", e.what());
            return nil;
        } catch (...) {
            NSLog(@"[JapaneseG2PWrapper] ❌ Unknown C++ exception during init");
            return nil;
        }
    }
    return self;
}


- (nullable NSArray<NSString *> *)extractPhonemes:(NSString *)text {
    if (!_g2p) {
        NSLog(@"G2P not initialized");
        return nil;
    }
    
    try {
        std::string inputText = [text UTF8String];
        std::vector<std::string> phonemes = _g2p->extractPhonemes(inputText);
        
        NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:phonemes.size()];
        for (const auto& p : phonemes) {
            [result addObject:[NSString stringWithUTF8String:p.c_str()]];
        }
        return result;
    } catch (const std::exception& e) {
        NSLog(@"extractPhonemes failed: %s", e.what());
        return nil;
    } catch (...) {
        NSLog(@"extractPhonemes failed with unknown error");
        return nil;
    }
}

- (nullable NSArray<NSString *> *)extractFullContextLabels:(NSString *)text {
    if (!_g2p) {
        NSLog(@"G2P not initialized");
        return nil;
    }
    
    try {
        std::string inputText = [text UTF8String];
        std::vector<std::string> labels = _g2p->extractFullContextLabels(inputText);
        
        NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:labels.size()];
        for (const auto& l : labels) {
            [result addObject:[NSString stringWithUTF8String:l.c_str()]];
        }
        return result;
    } catch (const std::exception& e) {
        NSLog(@"extractFullContextLabels failed: %s", e.what());
        return nil;
    } catch (...) {
        NSLog(@"extractFullContextLabels failed with unknown error");
        return nil;
    }
}

- (nullable NSArray<NSDictionary<NSString *, id> *> *)extractNodes:(NSString *)text {
    if (!_g2p) {
        NSLog(@"G2P not initialized");
        return nil;
    }
    
    try {
        std::string inputText = [text UTF8String];
        std::vector<OpenJTalkNode> nodes = _g2p->extractNodes(inputText);
        
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:nodes.size()];
        for (const auto& node : nodes) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            dict[@"string"] = [NSString stringWithUTF8String:node.string.c_str()];
            dict[@"pron"] = [NSString stringWithUTF8String:node.pron.c_str()];
            dict[@"pos"] = [NSString stringWithUTF8String:node.pos.c_str()];
            dict[@"acc"] = @(node.acc);
            dict[@"mora_size"] = @(node.mora_size);
            dict[@"chain_flag"] = @(node.chain_flag);
            
            [result addObject:dict];
        }
        return result;
    } catch (const std::exception& e) {
        NSLog(@"extractNodes failed: %s", e.what());
        return nil;
    } catch (...) {
        NSLog(@"extractNodes failed with unknown error");
        return nil;
    }
}

- (BOOL)isStub {
    return NO;
}

@end
