
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C wrapper for the C++ JapaneseG2P class.
/// This allows Swift to interact with the OpenJTalk G2P functionality.
@interface JapaneseG2PWrapper : NSObject

/// Initialize the G2P with the path to the MeCab dictionary directory.
/// @param dictionaryPath Absolute path to the dictionary folder (e.g., UniDic).
- (nullable instancetype)initWithDictionaryPath:(NSString *)dictionaryPath;

/// Extract phonemes from Japanese text.
/// @param text Input Japanese text.
/// @return Array of phoneme strings, or nil if failed.
- (nullable NSArray<NSString *> *)extractPhonemes:(NSString *)text;

/// Extract full-context labels from Japanese text.
/// These labels contain detailed prosody, accent, and part-of-speech information.
/// @param text Input Japanese text.
/// @return Array of full-context label strings, or nil if failed.
- (nullable NSArray<NSString *> *)extractFullContextLabels:(NSString *)text;

/// Extract structure word nodes (including accent, mora size, pronunciation).
/// @param text Input Japanese text.
/// @return Array of Dictionaries containing node info ("pron", "acc", "mora_size", "string", "pos", "chain_flag").
- (nullable NSArray<NSDictionary<NSString *, id> *> *)extractNodes:(NSString *)text;

/// Indicates if this is the stub version (always NO for full version)
@property (nonatomic, readonly) BOOL isStub;

@end

NS_ASSUME_NONNULL_END
