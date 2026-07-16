
#import "AccentPipelineWrapper.h"
#include "AccentPipeline.hpp"
#include <string>
#include <vector>

@implementation AccentPipelineWrapper {
    std::unique_ptr<AccentPipeline> _pipeline;
}

- (nullable instancetype)initWithDictionaryPath:(NSString *)dictionaryPath {
    self = [super init];
    if (self) {
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        BOOL exists = [fm fileExistsAtPath:dictionaryPath isDirectory:&isDirectory];
        if (!exists || !isDirectory) {
            NSLog(@"[AccentPipelineWrapper] dictionary path missing/not a directory: %@", dictionaryPath);
            return nil;
        }

        try {
            std::string path = [dictionaryPath UTF8String];
            _pipeline = std::make_unique<AccentPipeline>(path);
        } catch (const std::exception& e) {
            NSLog(@"[AccentPipelineWrapper] C++ exception during init: %s", e.what());
            return nil;
        } catch (...) {
            NSLog(@"[AccentPipelineWrapper] unknown C++ exception during init");
            return nil;
        }

        if (!_pipeline || !_pipeline->isLoaded()) {
            NSLog(@"[AccentPipelineWrapper] pipeline failed to load dictionary: %@", dictionaryPath);
            return nil;
        }
    }
    return self;
}

- (BOOL)isLoaded {
    return _pipeline && _pipeline->isLoaded();
}

- (nullable NSArray<NSDictionary<NSString *, id> *> *)computeAccents:(NSString *)text {
    if (!_pipeline) {
        return nil;
    }
    try {
        std::string inputText = [text UTF8String];
        std::vector<AccentNode> nodes = _pipeline->computeAccents(inputText);

        NSMutableArray *result = [NSMutableArray arrayWithCapacity:nodes.size()];
        for (const auto& node : nodes) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            dict[@"surface"] = [NSString stringWithUTF8String:node.surface.c_str()];
            dict[@"pos"] = [NSString stringWithUTF8String:node.pos.c_str()];
            dict[@"accent_type"] = @(node.accentType);
            dict[@"mora_count"] = @(node.moraCount);
            dict[@"chain_flag"] = @(node.chainFlag);
            [result addObject:dict];
        }
        return result;
    } catch (const std::exception& e) {
        NSLog(@"[AccentPipelineWrapper] computeAccents failed: %s", e.what());
        return nil;
    } catch (...) {
        NSLog(@"[AccentPipelineWrapper] computeAccents failed with unknown error");
        return nil;
    }
}

@end
