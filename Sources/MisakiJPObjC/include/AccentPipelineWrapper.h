
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C wrapper for the C++ AccentPipeline class -- the full
/// mecab2njd -> njd_set_accent_phrase -> njd_set_accent_type sentence-context
/// accent pipeline (as opposed to JapaneseG2PWrapper's isolated per-node
/// dictionary lookups).
@interface AccentPipelineWrapper : NSObject

/// Initialize with the path to the MeCab dictionary directory.
/// @param dictionaryPath Absolute path to the dictionary folder (e.g., UniDic).
- (nullable instancetype)initWithDictionaryPath:(NSString *)dictionaryPath;

/// Run the full sentence-context accent pipeline over `text`.
/// @return Array of dictionaries, one per surviving NJD node, each with keys
///         "surface" (NSString), "pos" (NSString), "accent_type" (NSNumber int,
///         mora index of the pitch drop), "mora_count" (NSNumber int),
///         "chain_flag" (NSNumber int, 1 = merged into the previous accent
///         phrase, 0 = starts a new accent phrase). Or nil if the pipeline
///         isn't loaded / text failed to tokenize.
- (nullable NSArray<NSDictionary<NSString *, id> *> *)computeAccents:(NSString *)text;

/// Indicates whether the MeCab dictionary loaded successfully.
@property (nonatomic, readonly) BOOL isLoaded;

@end

NS_ASSUME_NONNULL_END
