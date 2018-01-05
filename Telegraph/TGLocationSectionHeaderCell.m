#import "TGLocationSectionHeaderCell.h"

#import "TGFont.h"

NSString *const TGLocationSectionHeaderKind = @"TGLocationSectionHeaderKind";
const CGFloat TGLocationSectionHeaderHeight = 28.5f;

@interface TGLocationSectionHeaderCell ()
{
    UILabel *_titleLabel;
}
@end

@implementation TGLocationSectionHeaderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.selectedBackgroundView = [[UIView alloc] init];
        self.contentView.backgroundColor = UIColorRGB(0xf7f7f7);
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = self.contentView.backgroundColor;
        _titleLabel.font = TGMediumSystemFontOfSize(14);
        _titleLabel.textColor = UIColorRGB(0x8e8e93);
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title
{
    _titleLabel.text = title;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat padding = 14;
    _titleLabel.frame = CGRectMake(padding, 0, self.frame.size.width - padding, self.frame.size.height - 2);
}

@end
