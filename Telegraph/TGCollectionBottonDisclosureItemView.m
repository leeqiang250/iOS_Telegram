#import "TGCollectionBottonDisclosureItemView.h"

#import "TGFont.h"

#import "TGStringUtils.h"

#import "TGModernTextViewModel.h"

#import "TGLinkTargetView.h"

@interface TGCollectionBottonDisclosureItemView ()
{
    UILabel *_titleLabel;
    UIImageView *_disclosureIndicator;
    
    bool _expanded;
    
    TGModernTextViewModel *_textModel;
    UIImageView *_textContentView;
    TGLinkTargetView *_linkTargetView;
    void (^_followAnchor)(NSString *);
}

@end

@implementation TGCollectionBottonDisclosureItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textAlignment = NSTextAlignmentLeft;
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17);
        _titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _titleLabel.numberOfLines = 0;
        [self.contentView addSubview:_titleLabel];
        
        /*_textLabel = [[UILabel alloc] init];
        _textLabel.textColor = [UIColor blackColor];
        _textLabel.backgroundColor = [UIColor clearColor];
        _textLabel.font = TGSystemFontOfSize(15);
        _textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _textLabel.numberOfLines = 0;
        [self addSubview:_textLabel];*/
        
        _textContentView = [[UIImageView alloc] init];
        _textContentView.userInteractionEnabled = true;
        [self.contentView addSubview:_textContentView];
        
        _linkTargetView = [[TGLinkTargetView alloc] init];
        __weak TGCollectionBottonDisclosureItemView *weakSelf = self;
        _linkTargetView.tap = ^(CGPoint point)
        {
            __strong TGCollectionBottonDisclosureItemView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                point = [strongSelf convertPoint:point fromView:strongSelf->_linkTargetView];
                NSString *link = [strongSelf->_textModel linkAtPoint:CGPointMake(point.x - strongSelf->_textContentView.frame.origin.x, point.y - strongSelf->_textContentView.frame.origin.y) regionData:NULL];
                if (link.length != 0)
                {
                    if ([link hasPrefix:@"#"])
                    {
                        if (strongSelf->_followAnchor)
                            strongSelf->_followAnchor([link substringFromIndex:1]);
                    }
                    else if ([link hasPrefix:@"/"])
                    {
                        link = [[NSString alloc] initWithFormat:@"https://telegram.org/%@", link];
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:link]];
                    }
                    else
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:link]];
                }
            }
        };
        [self.contentView addSubview:_linkTargetView];
        
        _disclosureIndicator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ListsDownDisclosureIndicator.png"]];
        [self.contentView addSubview:_disclosureIndicator];
    }
    return self;
}

+ (CGSize)title:(NSString *)title sizeForWidth:(CGFloat)width
{
    return [title sizeWithFont:TGSystemFontOfSize(17) constrainedToSize:CGSizeMake(width - 15.0f - 40.0f, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
}

+ (CTFontRef)mediumFont
{
    static CTFontRef font = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() >= 7) {
            font = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)[TGMediumSystemFontOfSize(15.0f) fontDescriptor], 0.0f, NULL);
        } else {
            UIFont *systemFont = TGMediumSystemFontOfSize(15.0f);
            font = CTFontCreateWithName((__bridge CFStringRef)systemFont.fontName, systemFont.pointSize, nil);
        }
    });
    
    return font;
}

+ (CTFontRef)italicFont
{
    static CTFontRef font = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() >= 7) {
            font = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)[TGItalicSystemFontOfSize(15.0f) fontDescriptor], 0.0f, NULL);
        } else {
            UIFont *systemFont = TGItalicSystemFontOfSize(15.0f);
            font = CTFontCreateWithName((__bridge CFStringRef)systemFont.fontName, systemFont.pointSize, nil);
        }
    });
    
    return font;
}

+ (NSString *)stringForText:(NSString *)text outAttributes:(__autoreleasing NSArray **)outAttributes outTextCheckingResults:(NSArray *__autoreleasing *)outTextCheckingResults
{
    NSMutableString *string = [[NSMutableString alloc] initWithString:[TGStringUtils stringByUnescapingFromHTML:text]];
    
    [string replaceOccurrencesOfString:@"<p>" withString:@"" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"</p>" withString:@"\n" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"<br>" withString:@"\n" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"<ol>" withString:@"" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"</ol>" withString:@"" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"<li>" withString:@"— " options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"</li>" withString:@"" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"<ul>" withString:@"" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"</ul>" withString:@"" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"<blockquote>" withString:@"" options:0 range:NSMakeRange(0, string.length)];
    [string replaceOccurrencesOfString:@"</blockquote>" withString:@"" options:0 range:NSMakeRange(0, string.length)];
    while (string.length != 0)
    {
        unichar c = [string characterAtIndex:0];
        if (c == ' ' || c =='\n' || c == '\r')
        {
            [string deleteCharactersInRange:NSMakeRange(0, 1)];
        }
        else
            break;
    }
    
    while (string.length != 0)
    {
        unichar c = [string characterAtIndex:string.length - 1];
        if (c == ' ' || c =='\n' || c == '\r')
        {
            [string deleteCharactersInRange:NSMakeRange(string.length - 1, 1)];
        }
        else
            break;
    }
    
    NSMutableArray *emRanges = [[NSMutableArray alloc] init];
    NSMutableArray *strongRanges = [[NSMutableArray alloc] init];
    NSMutableArray *aRanges = [[NSMutableArray alloc] init];
    NSMutableArray *textCheckingResults = [[NSMutableArray alloc] init];
    
    while (true)
    {
        NSRange startEmRange = [string rangeOfString:@"<em>"];
        NSRange startStrongRange = [string rangeOfString:@"<strong>"];
        NSRange startARange = [string rangeOfString:@"<a"];
        if (startEmRange.location == NSNotFound && startStrongRange.location == NSNotFound && startARange.location == NSNotFound)
            break;
        
        NSUInteger minLocation = MIN(startEmRange.location, MIN(startStrongRange.location, startARange.location));
        
        if (startEmRange.location == minLocation)
        {
            [string deleteCharactersInRange:startEmRange];
            NSRange endRange = [string rangeOfString:@"</em>"];
            if (endRange.location == NSNotFound)
                break;
            [string deleteCharactersInRange:endRange];
            [emRanges addObject:[NSValue valueWithRange:NSMakeRange(startEmRange.location, endRange.location - startEmRange.location)]];
        }
        else if (startStrongRange.location == minLocation)
        {
            [string deleteCharactersInRange:startStrongRange];
            NSRange endRange = [string rangeOfString:@"</strong>"];
            if (endRange.location == NSNotFound)
                break;
            [string deleteCharactersInRange:endRange];
            [strongRanges addObject:[NSValue valueWithRange:NSMakeRange(startStrongRange.location, endRange.location - startStrongRange.location)]];
        }
        else if (startARange.location == minLocation)
        {
            NSRange endLinkRange = [string rangeOfString:@">" options:0 range:NSMakeRange(startARange.location + 1, string.length - startARange.location - 1)];
            if (endLinkRange.location == NSNotFound)
                break;
            NSString *linkUrl = @"";
            NSRange hrefRange = [string rangeOfString:@"href=\""];
            if (hrefRange.location != NSNotFound)
            {
                NSRange hrefEndRange = [string rangeOfString:@"\"" options:0 range:NSMakeRange(hrefRange.location + hrefRange.length, string.length - hrefRange.location - hrefRange.length)];
                if (hrefEndRange.location != NSNotFound)
                {
                    linkUrl = [string substringWithRange:NSMakeRange(hrefRange.location + hrefRange.length, hrefEndRange.location - hrefRange.location - hrefRange.length)];
                }
            }
            
            startARange.length = endLinkRange.location + endLinkRange.length - startARange.location;
            [string deleteCharactersInRange:startARange];
            
            NSRange endRange = [string rangeOfString:@"</a>"];
            if (endRange.location == NSNotFound)
                break;
            [string deleteCharactersInRange:endRange];
            NSURL *url = [[NSURL alloc] initWithString:linkUrl];
            if (url != nil)
            {
                [aRanges addObject:[NSValue valueWithRange:NSMakeRange(startARange.location, endRange.location - startARange.location)]];
                [textCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:NSMakeRange(startARange.location, endRange.location - startARange.location) URL:url]];
            }
        }
        else
            break;
    }
    
    while (true)
    {
        NSRange startRange = [string rangeOfString:@"<strong>"];
        if (startRange.location == NSNotFound)
            break;
        
        [string deleteCharactersInRange:startRange];
        
        NSRange endRange = [string rangeOfString:@"</strong>"];
        if (endRange.location == NSNotFound)
            break;
        
        [string deleteCharactersInRange:endRange];
        
        [strongRanges addObject:[NSValue valueWithRange:NSMakeRange(startRange.location, endRange.location - startRange.location)]];
    }
    
    NSMutableArray *attributes = [[NSMutableArray alloc] init];

    NSArray *emAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[self italicFont], (NSString *)kCTFontAttributeName, nil];
    NSArray *strongAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[self mediumFont], (NSString *)kCTFontAttributeName, nil];
    NSArray *aAttributes = [[NSArray alloc] initWithObjects:(__bridge id)TGAccentColor().CGColor, (NSString *)kCTForegroundColorAttributeName, nil];
    
    for (NSValue *nRange in emRanges)
    {
        NSRange range = [nRange rangeValue];
        [attributes addObject:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)]];
        [attributes addObject:emAttributes];
    }
    
    for (NSValue *nRange in strongRanges)
    {
        NSRange range = [nRange rangeValue];
        [attributes addObject:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)]];
        [attributes addObject:strongAttributes];
    }
    
    for (NSValue *nRange in aRanges)
    {
        NSRange range = [nRange rangeValue];
        [attributes addObject:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)]];
        [attributes addObject:aAttributes];
    }
    
    if (outAttributes != NULL)
        *outAttributes = attributes;
    if (outTextCheckingResults != NULL)
        *outTextCheckingResults = textCheckingResults;
    
    return string;
}

- (void)setTitle:(NSString *)title textModel:(TGModernTextViewModel *)textModel expanded:(bool)expanded followAnchor:(void (^)(NSString *))followAnchor
{
    _titleLabel.text = title;
    _expanded = expanded;
    _textModel = textModel;
    _followAnchor = [followAnchor copy];
    
    [self setExpanded:expanded];
}

- (void)updateTextContentView
{
    UIGraphicsBeginImageContextWithOptions(_textModel.frame.size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [_textModel drawInContext:context];
    _textContentView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

- (void)setExpanded:(bool)expanded
{
    _expanded = expanded;
    _textContentView.hidden = !_expanded;
    
    _titleLabel.textColor = _expanded ? TGAccentColor(): [UIColor blackColor];
    _disclosureIndicator.image = _expanded ? [UIImage imageNamed:@"ListsDownDisclosureIndicator_Highlighted.png"] : [UIImage imageNamed:@"ListsDownDisclosureIndicator.png"];
    
    [self setNeedsLayout];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (CGRectContainsPoint(CGRectMake(0.0f, 0.0f, self.frame.size.width, 44.0f), point))
        return [super hitTest:point withEvent:event];
    else if (_expanded && CGRectContainsPoint(_linkTargetView.frame, point))
        return _linkTargetView;
    
    return nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    CGSize titleSize = [TGCollectionBottonDisclosureItemView title:_titleLabel.text sizeForWidth:self.frame.size.width];
    _titleLabel.frame = CGRectMake(15, 12.0f, bounds.size.width - 15 - 40, CGFloor(titleSize.height + 1.0f));
    _disclosureIndicator.frame = CGRectMake(bounds.size.width - _disclosureIndicator.frame.size.width - 15, CGFloor((44.0f - _disclosureIndicator.frame.size.height) / 2), _disclosureIndicator.frame.size.width, _disclosureIndicator.frame.size.height);
    
    _linkTargetView.frame = _expanded ? CGRectMake(0.0f, CGRectGetMaxY(_titleLabel.frame) + 12.0f, bounds.size.width, bounds.size.height - CGRectGetMaxY(_titleLabel.frame) - 12.0f) : CGRectZero;
    
    if (_expanded)
    {
        CGRect frame = CGRectMake(15.0f, 12.0f + CGFloor(titleSize.height + 1.0f) + 15.0f, _textModel.frame.size.width, _textModel.frame.size.height);
        
        if (!CGSizeEqualToSize(_textContentView.frame.size, frame.size))
        {
            _textContentView.frame = frame;
            [self updateTextContentView];
        }
    }
}

@end
