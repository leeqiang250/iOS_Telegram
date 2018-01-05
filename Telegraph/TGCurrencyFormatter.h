#import <Foundation/Foundation.h>

@interface TGCurrencyFormatterEntry : NSObject

@property (nonatomic, strong, readonly) NSString *symbol;
@property (nonatomic, strong, readonly) NSString *thousandsSeparator;
@property (nonatomic, strong, readonly) NSString *decimalSeparator;
@property (nonatomic, readonly) bool symbolOnLeft;
@property (nonatomic, readonly) bool spaceBetweenAmountAndSymbol;
@property (nonatomic, readonly) int decimalDigits;

@end

@interface TGCurrencyFormatter : NSObject

+ (TGCurrencyFormatter *)shared;

- (NSString *)formatAmount:(int64_t)amount currency:(NSString *)currency;

@end
