/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
int32_t murMurHash32(NSString *string);
int32_t murMurHashBytes32(void *bytes, int length);
int32_t phoneMatchHash(NSString *phone);
    
bool TGIsRTL();
bool TGIsArabic();
bool TGIsKorean();
bool TGIsLocaleArabic();
    
#ifdef __cplusplus
}
#endif

@interface TGStringUtils : NSObject

+ (NSString *)stringByEscapingForURL:(NSString *)string;
+ (NSString *)stringByEscapingForActorURL:(NSString *)string;
+ (NSString *)stringByEncodingInBase64:(NSData *)data;
+ (NSString *)stringByUnescapingFromHTML:(NSString *)srcString;

+ (NSString *)stringWithLocalizedNumber:(NSInteger)number;
+ (NSString *)stringWithLocalizedNumberCharacters:(NSString *)string;

+ (NSString *)md5:(NSString *)string;
+ (NSString *)md5ForData:(NSData *)data;

+ (NSDictionary *)argumentDictionaryInUrlString:(NSString *)string;

+ (bool)stringContainsEmoji:(NSString *)string;
+ (bool)stringContainsEmojiOnly:(NSString *)string length:(NSUInteger *)length;

+ (NSString *)stringForMessageTimerSeconds:(NSUInteger)seconds;
+ (NSString *)stringForShortMessageTimerSeconds:(NSUInteger)seconds;
+ (NSArray *)stringComponentsForMessageTimerSeconds:(NSUInteger)seconds;
+ (NSString *)stringForCallDurationSeconds:(NSUInteger)seconds;
+ (NSString *)stringForShortCallDurationSeconds:(NSUInteger)seconds;
+ (NSString *)stringForUserCount:(NSUInteger)userCount;
+ (NSString *)stringForFileSize:(int64_t)size;
+ (NSString *)stringForFileSize:(int64_t)size precision:(NSInteger)precision;

+ (NSString *)integerValueFormat:(NSString *)prefix value:(NSInteger)value;
+ (NSString *)stringForMuteInterval:(int)value;
+ (NSString *)stringForRemainingMuteInterval:(int)value;

+ (NSString *)stringForDeviceType;

+ (NSString *)stringForCurrency:(NSString *)currency amount:(int64_t)amount;

+ (NSString *)stringForEmojiHashOfData:(NSData *)data count:(NSInteger)count positionExtractor:(int32_t (^)(uint8_t *, int32_t, int32_t))positionExtractor;

@end

@interface NSString (Telegraph)

- (int)lengthByComposedCharacterSequences;
- (int)lengthByComposedCharacterSequencesInRange:(NSRange)range;

- (NSData *)dataByDecodingHexString;
- (NSArray *)getEmojiFromString:(BOOL)checkColor checkString:(__autoreleasing NSString **)checkString;

- (bool)containsSingleEmoji;

- (bool)hasNonWhitespaceCharacters;

- (NSAttributedString *)attributedFormattedStringWithRegularFont:(UIFont *)regularFont boldFont:(UIFont *)boldFont lineSpacing:(CGFloat)lineSpacing paragraphSpacing:(CGFloat)paragraphSpacing alignment:(NSTextAlignment)alignment;

- (NSString *)urlAnchorPart;

@end

@interface NSData (Telegraph)

- (NSString *)stringByEncodingInHex;
- (NSString *)stringByEncodingInHexSeparatedByString:(NSString *)string;

@end
