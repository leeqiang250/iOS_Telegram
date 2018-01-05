#import "PGSharpenTool.h"

#import "PGPhotoSharpenPass.h"

@implementation PGSharpenTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"sharpen";
        _type = PGPhotoToolTypePass;
        _order = 2;
        
        _pass = [[PGPhotoSharpenPass alloc] init];
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.SharpenTool");
}

- (UIImage *)image
{
    return [UIImage imageNamed:@"PhotoEditorSharpenTool"];
}

- (PGPhotoProcessPass *)pass
{
    [self updatePassParameters];
    
    return _pass;
}

- (bool)shouldBeSkipped
{
    return false;
    //return (fabsf(((NSNumber *)self.displayValue).floatValue - self.defaultValue) < FLT_EPSILON);
}

- (void)updatePassParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    [(PGPhotoSharpenPass *)_pass setSharpness:0.125f + value.floatValue / 100 * 0.6f];
}

@end
