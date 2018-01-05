/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGNavigationController.h"

typedef enum {
    TGToolbarButtonTypeGeneric = 0,
    TGToolbarButtonTypeBack = 1,
    TGToolbarButtonTypeDone = 2,
    TGToolbarButtonTypeDoneBlack = 3,
    TGToolbarButtonTypeImage = 4,
    TGToolbarButtonTypeDelete = 5,
    TGToolbarButtonTypeCustom = 6
} TGToolbarButtonType;

@interface TGToolbarButton : UIButton <TGBarItemSemantics>

@property (nonatomic) TGToolbarButtonType type;

@property (nonatomic) CGSize touchInset;

@property (nonatomic) int minWidth;
@property (nonatomic) float paddingLeft;
@property (nonatomic) float paddingRight;

@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, retain) UIImage *imageLandscape;
@property (nonatomic, retain) UIImage *imageHighlighted;

@property (nonatomic, retain) UILabel *buttonLabelView;
@property (nonatomic, retain) UIImageView *buttonImageView;

@property (nonatomic) bool isLandscape;
@property (nonatomic) int landscapeOffset;

@property (nonatomic) bool backSemantics;

- (id)initWithType:(TGToolbarButtonType)type;
- (id)initWithCustomImages:(UIImage *)imageNormal imageNormalHighlighted:(UIImage *)imageNormalHighlighted imageLandscape:(UIImage *)imageLandscape imageLandscapeHighlighted:(UIImage *)imageLandscapeHighlighted textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor;

@end
