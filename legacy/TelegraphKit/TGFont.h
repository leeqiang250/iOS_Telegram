/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

#ifdef __cplusplus
extern "C" {
#endif

UIFont *TGSystemFontOfSize(CGFloat size);
UIFont *TGBoldSystemFontOfSize(CGFloat size);
UIFont *TGLightSystemFontOfSize(CGFloat size);
UIFont *TGUltralightSystemFontOfSize(CGFloat size);
UIFont *TGMediumSystemFontOfSize(CGFloat size);
UIFont *TGSemiboldSystemFontOfSize(CGFloat size);
UIFont *TGItalicSystemFontOfSize(CGFloat size);

CTFontRef TGCoreTextSystemFontOfSize(CGFloat size);
CTFontRef TGCoreTextMediumFontOfSize(CGFloat size);
CTFontRef TGCoreTextBoldFontOfSize(CGFloat size);
CTFontRef TGCoreTextLightFontOfSize(CGFloat size);
CTFontRef TGCoreTextFixedFontOfSize(CGFloat size);
CTFontRef TGCoreTextItalicFontOfSize(CGFloat size);
    
#ifdef __cplusplus
}
#endif

@interface TGFont : NSObject

+ (UIFont *)systemFontOfSize:(CGFloat)size;
+ (UIFont *)boldSystemFontOfSize:(CGFloat)size;

+ (UIFont *)roundedFontOfSize:(CGFloat)size;

@end
