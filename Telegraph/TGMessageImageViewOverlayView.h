/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

typedef enum {
    TGMessageImageViewOverlayStyleDefault = 0,
    TGMessageImageViewOverlayStyleAccent = 1,
    TGMessageImageViewOverlayStyleList = 2,
    TGMessageImageViewOverlayStyleIncoming = 3,
    TGMessageImageViewOverlayStyleOutgoing = 4
} TGMessageImageViewOverlayStyle;

@interface TGMessageImageViewOverlayView : UIView

@property (nonatomic, readonly) CGFloat progress;

- (void)setBlurless:(bool)blurless;
- (void)setRadius:(CGFloat)radius;
- (void)setOverlayBackgroundColorHint:(UIColor *)overlayBackgroundColorHint;
- (void)setOverlayStyle:(TGMessageImageViewOverlayStyle)overlayStyle;
- (void)setBlurredBackgroundImage:(UIImage *)blurredBackgroundImage;
- (void)setDownload;
- (void)setProgress:(CGFloat)progress animated:(bool)animated;
- (void)setSecretProgress:(CGFloat)progress completeDuration:(NSTimeInterval)completeDuration animated:(bool)animated;
- (void)setProgress:(CGFloat)progress cancelEnabled:(bool)cancelEnabled animated:(bool)animated;
- (void)setProgressAnimated:(CGFloat)progress duration:(NSTimeInterval)duration cancelEnabled:(bool)cancelEnabled;
- (void)setPlay;
- (void)setPlayMedia;
- (void)setPauseMedia;
- (void)setSecret:(bool)isViewed;
- (void)setNone;

@end
