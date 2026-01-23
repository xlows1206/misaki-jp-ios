#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MeCabNode : NSObject
@property (nonatomic, copy) NSString *surface;
@property (nonatomic, copy) NSString *feature; // Raw feature string from MeCab
// Helpers parsed from feature
@property (nonatomic, copy, nullable) NSString *pos;
@property (nonatomic, copy, nullable) NSString *reading; // Katakana reading
@property (nonatomic, copy, nullable) NSString *pronunciation;
@end

@interface MeCabWrapper : NSObject

// Initialize with path to UniDic directory (containing sys.dic)
- (nullable instancetype)initWithDictionaryPath:(NSString *)path;

// Tokenize text into nodes
- (NSArray<MeCabNode *> *)tokenize:(NSString *)text;

// Analyze text and return array of feature strings (one per token)
// Format: Surface \t FeatureCSV
- (NSArray<NSString *> *)analyzeToFeatures:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
