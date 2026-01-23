#import "MeCabWrapper.h"

// Note: You must add mecab.h and libmecab sources to your project
#if __has_include("mecab.h")
#include "mecab.h"
#else
// Stub for compilation until user adds MeCab source
namespace MeCab {
    class Tagger {
    public:
        static Tagger* create(const char*) { return nullptr; }
        virtual const void* parseToNode(const char*) { return nullptr; }
        virtual const char* parse(const char*) { return ""; }
    };
    struct Node {
        struct Node *next;
        const char *surface;
        unsigned short length;
        const char *feature;
        unsigned char stat;
    };
}
#endif

@implementation MeCabNode
@end

@implementation MeCabWrapper {
    MeCab::Tagger *_tagger;
}

- (nullable instancetype)initWithDictionaryPath:(NSString *)path {
    self = [super init];
    if (self) {
        // Construct argument string for MeCab
        // -d: Directory of dictionary
        // -r: /dev/null to disable loading rc file
        NSString *args = [NSString stringWithFormat:@"-d %@ -r /dev/null", path];
        _tagger = MeCab::Tagger::create([args UTF8String]);
        
        if (!_tagger) {
            NSLog(@"[MeCabWrapper] Failed to create tagger with args: %@", args);
            return nil;
        }
    }
    return self;
}

- (NSArray<MeCabNode *> *)tokenize:(NSString *)text {
    if (!_tagger || text.length == 0) return @[];
    
    NSMutableArray<MeCabNode *> *result = [NSMutableArray array];
    
    // Lock if shared? MeCab Tagger is generally not thread safe for write, but read is ok?
    @synchronized(self) {
        const MeCab::Node *node = _tagger->parseToNode([text UTF8String]);
        
        for (; node; node = node->next) {
            // Skip BOS/EOS
            if (node->stat == 2 || node->stat == 3) continue; 
            
            NSString *surface = [[NSString alloc] initWithBytes:node->surface length:node->length encoding:NSUTF8StringEncoding];
            NSString *feature = [NSString stringWithUTF8String:node->feature];
            
            if (!surface) continue;
            
            MeCabNode *mcNode = [[MeCabNode alloc] init];
            mcNode.surface = surface;
            mcNode.feature = feature;
            
            // Parse feature CSV for UniDic-lite format:
            // [0]=POS [1]=POS2 [2]=POS3 [3]=POS4 [4]=CType [5]=CForm [6]=Reading(カタカナ) [7]=書字形 [8]=発音形 [9]=発音(カタカナ)
            NSArray *components = [feature componentsSeparatedByString:@","];
            if (components.count > 0) mcNode.pos = components[0];
            
            // UniDic-lite: Reading (片假名) is at index 6
            if (components.count > 6) {
                NSString *reading = components[6];
                // 过滤掉 "*" 占位符
                if (![reading isEqualToString:@"*"] && reading.length > 0) {
                    mcNode.reading = reading;
                }
            }
            
            // Pronunciation (発音) is at index 9
            if (components.count > 9) {
                NSString *pronunciation = components[9];
                if (![pronunciation isEqualToString:@"*"] && pronunciation.length > 0) {
                    mcNode.pronunciation = pronunciation;
                }
            }
            
            [result addObject:mcNode];
        }
    }
    
    return result;
}

- (NSArray<NSString *> *)analyzeToFeatures:(NSString *)text {
    if (!_tagger || text.length == 0) return @[];
    
    @synchronized(self) {
        // Raw Parse: Surface \t FeatureCSV \n ...
        const char *result = _tagger->parse([text UTF8String]);
        if (!result) return @[];
        
        NSString *fullResult = [NSString stringWithUTF8String:result];
        if (fullResult.length == 0) return @[];
        
        // Filter out BOS/EOS which shows as just "EOS" line usually?
        // MeCab output format:
        // Surface \t Feature \n
        // EOS \n
        
        NSArray *lines = [fullResult componentsSeparatedByString:@"\n"];
        NSMutableArray *features = [NSMutableArray arrayWithCapacity:lines.count];
        
        for (NSString *line in lines) {
            if ([line isEqualToString:@"EOS"] || line.length == 0) continue;
            [features addObject:line];
        }
        return features;
    }
}

- (void)dealloc {
    if (_tagger) {
        delete _tagger;
    }
}

@end
