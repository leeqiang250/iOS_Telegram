#import "TGTextField.h"

#import "TGImageUtils.h"

@implementation TGTextField

- (void)drawPlaceholderInRect:(CGRect)rect
{
    if (_placeholderColor == nil || _placeholderFont == nil)
        [super drawPlaceholderInRect:rect];
    else
    {
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), _placeholderColor.CGColor);
        
        CGSize placeholderSize = [self.placeholder sizeWithFont:_placeholderFont];
        
        CGPoint placeholderOrigin = CGPointMake(0.0f, CGFloor((rect.size.height - placeholderSize.height) / 2.0f) - TGRetinaPixel);
        if (self.textAlignment == NSTextAlignmentCenter)
            placeholderOrigin.x = CGFloor((rect.size.width - placeholderSize.width) / 2.0f);
        else if (self.textAlignment == NSTextAlignmentRight)
            placeholderOrigin.x = rect.size.width - placeholderSize.width;
        
        placeholderOrigin.y += TGRetinaPixel;
        
        [self.placeholder drawAtPoint:placeholderOrigin withFont:_placeholderFont];
    }
}

- (CGRect)textRectForBounds:(CGRect)bounds
{
    CGRect rect = [super textRectForBounds:bounds];
    rect.origin.x += _leftInset;
    rect.size.width -= _leftInset + _rightInset;
    rect.origin.y = CGFloor((self.bounds.size.height - rect.size.height) / 2.0f);
    return rect;
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return CGRectOffset([self textRectForBounds:bounds], 0.0f, TGRetinaPixel + _editingRectOffset);
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds
{
    return [self textRectForBounds:bounds];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    
    if (self.window != nil && _movedToWindow)
        _movedToWindow();
}

@end
