#import "TGStickerKeyboardTabPanel.h"

#import "TGStickerKeyboardTabCell.h"
#import "TGStickerKeyboardTabSettingsCell.h"

#import "TGStickerPack.h"
#import "TGDocumentMediaAttachment.h"

#import "TGImageUtils.h"

#import "TGStickerPacksSettingsController.h"
#import "TGAppDelegate.h"

@interface TGStickerKeyboardTabPanel () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
{
    TGStickerKeyboardViewStyle _style;
    
    bool _showRecent;
    bool _showGifs;
    bool _showTrendingFirst;
    bool _showTrendingLast;
    NSArray *_stickerPacks;
    
    UICollectionView *_collectionView;
    UICollectionViewFlowLayout *_collectionLayout;
    UIView *_bottomStripe;
    
    NSString *_trendingStickersBadge;
    CGFloat _innerAlpha;
    
    bool _expanded;
}

@end

@implementation TGStickerKeyboardTabPanel

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame style:TGStickerKeyboardViewDefaultStyle];
}

- (instancetype)initWithFrame:(CGRect)frame style:(TGStickerKeyboardViewStyle)style
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _style = style;
        
        _collectionLayout = [[UICollectionViewFlowLayout alloc] init];
        _collectionLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, frame.size.height) collectionViewLayout:_collectionLayout];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.backgroundColor = nil;
        _collectionView.opaque = false;
        _collectionView.showsHorizontalScrollIndicator = false;
        _collectionView.showsVerticalScrollIndicator = false;
        _collectionView.contentInset = UIEdgeInsetsZero;
        [_collectionView registerClass:[TGStickerKeyboardTabCell class] forCellWithReuseIdentifier:@"TGStickerKeyboardTabCell"];
        [_collectionView registerClass:[TGStickerKeyboardTabSettingsCell class] forCellWithReuseIdentifier:@"TGStickerKeyboardTabSettingsCell"];
        [self addSubview:_collectionView];
        
        switch (style)
        {
            case TGStickerKeyboardViewDarkBlurredStyle:
            {
                self.backgroundColor = UIColorRGB(0x444444);
            }
                break;
                
            case TGStickerKeyboardViewPaintStyle:
            {
                self.backgroundColor = [UIColor clearColor];
                _collectionView.contentInset = UIEdgeInsetsMake(0.0f, 12.0f, 0.0f, 12.0f);
            }
                break;
                
            case TGStickerKeyboardViewPaintDarkStyle:
            {
                self.backgroundColor = [UIColor clearColor];
                _collectionView.contentInset = UIEdgeInsetsMake(0.0f, 12.0f, 0.0f, 12.0f);
            }
                break;
                
            default:
            {
                self.backgroundColor = UIColorRGB(0xf7f7f7);
                
                CGFloat stripeHeight = TGScreenPixel;
                _bottomStripe = [[UIView alloc] initWithFrame:CGRectMake(0.0f, frame.size.height, frame.size.width, stripeHeight)];
                _bottomStripe.backgroundColor = UIColorRGB(0xbec2c6);
                [self addSubview:_bottomStripe];
            }
                break;
        }
        
        _innerAlpha = 1.0f;
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (_expanded)
        return CGRectContainsPoint(CGRectMake(0, -15.0f, self.bounds.size.width, self.bounds.size.height + 15.0f), point);
    
    return [super pointInside:point withEvent:event];
}

- (void)arrowTapped
{
    if (self.toggleExpanded != nil)
        self.toggleExpanded();
}

- (void)setFrame:(CGRect)frame
{
    bool sizeUpdated = !CGSizeEqualToSize(frame.size, self.frame.size);
    [super setFrame:frame];
    
    if (sizeUpdated && frame.size.width > FLT_EPSILON && frame.size.height > FLT_EPSILON)
        [self layoutForSize:frame.size];
}

- (void)setInnerAlpha:(CGFloat)alpha
{
    _innerAlpha = alpha;
    _collectionView.alpha = _innerAlpha;
    for (TGStickerKeyboardTabCell *cell in _collectionView.visibleCells)
    {
        if ([cell respondsToSelector:@selector(setInnerAlpha:)])
        {
            NSIndexPath *indexPath = [_collectionView indexPathForCell:cell];
            if (!_expanded || indexPath.row != 0 || !_showGifs)
                [cell setInnerAlpha:_innerAlpha];
        }
    }
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 36.0f * (1.0f - alpha));
    transform = CGAffineTransformScale(transform, alpha, alpha);
}

- (void)setBounds:(CGRect)bounds
{
    bool sizeUpdated = !CGSizeEqualToSize(bounds.size, self.bounds.size);
    [super setBounds:bounds];
    
    if (sizeUpdated && bounds.size.width > FLT_EPSILON && bounds.size.height > FLT_EPSILON)
        [self layoutForSize:bounds.size];
}

- (void)layoutForSize:(CGSize)size
{
    _collectionView.frame = CGRectMake(0.0f, 0.0f, size.width, _collectionView.frame.size.height);
    [_collectionLayout invalidateLayout];
    
    CGFloat stripeHeight = TGScreenPixel;
    _bottomStripe.frame = CGRectMake(0.0f, size.height, size.width, stripeHeight);
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)__unused collectionView
{
    return 2 + ((_style == TGStickerKeyboardViewDefaultStyle) ? 1 : 0);
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)__unused section
{
    if (section == 0) {
        return (_showGifs ? 1 : 0) + (_showTrendingFirst ? 1 : 0);
    } else if (section == 1) {
        return 1 + _stickerPacks.count;
    } else if (section == 2) {
        return 1 + (_showTrendingLast ? 1 : 0);
    } else {
        return 0;
    }
}

- (CGSize)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout*)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)__unused indexPath
{
    if (indexPath.section == 1 && indexPath.item == 0 && !_showRecent)
        return CGSizeMake(1.0f, _collectionView.frame.size.height);
    
    CGFloat width = 52.0f;
    if (_style == TGStickerKeyboardViewDefaultStyle)
        width = 48.0f;
    return CGSizeMake(width, _collectionView.frame.size.height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout insetForSectionAtIndex:(NSInteger)__unused section
{
    return UIEdgeInsetsZero;
}

- (CGFloat)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout*)__unused collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)__unused section
{
    return 0.0f;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)__unused collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)__unused section
{
    return (collectionView.frame.size.width < 330.0f) ? 0.0f : 4.0f;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        TGStickerKeyboardTabSettingsCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TGStickerKeyboardTabSettingsCell" forIndexPath:indexPath];
        [cell setStyle:_style];
        [cell setInnerAlpha:_innerAlpha];
        
        if (indexPath.item == 0 && _showGifs) {
            [cell setMode:TGStickerKeyboardTabSettingsCellGifs];
            [cell setBadge:nil];
            
            if (_expanded)
                [cell setInnerAlpha:0.0f];
        } else {
            [cell setMode:TGStickerKeyboardTabSettingsCellTrending];
            [cell setBadge:_trendingStickersBadge];
        }
        
        return cell;
    } else if (indexPath.section == 1) {
        TGStickerKeyboardTabCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TGStickerKeyboardTabCell" forIndexPath:indexPath];
        [cell setStyle:_style];
        
        if (indexPath.item == 0) {
            if (_showRecent) {
                [cell setRecent];
            } else {
                [cell setNone];
            }
        }
        else
        {
            if (((TGStickerPack *)_stickerPacks[indexPath.item - 1]).documents.count != 0)
                [cell setDocumentMedia:((TGStickerPack *)_stickerPacks[indexPath.item - 1]).documents[0]];
            else
                [cell setNone];
        }
        
        [cell setInnerAlpha:_innerAlpha];
        
        return cell;
    } else if (indexPath.section == 2) {
        TGStickerKeyboardTabSettingsCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TGStickerKeyboardTabSettingsCell" forIndexPath:indexPath];
        [cell setStyle:_style];

        if (_showTrendingLast && indexPath.item == 0) {
            [cell setBadge:_trendingStickersBadge];
            [cell setMode:TGStickerKeyboardTabSettingsCellTrending];
            cell.pressed = nil;
        } else {
            [cell setBadge:nil];
            [cell setMode:TGStickerKeyboardTabSettingsCellSettings];
            cell.pressed = self.openSettings;
        }
        
        [cell setInnerAlpha:_innerAlpha];
        
        return cell;
    } else {
        return nil;
    }
}

- (void)collectionView:(UICollectionView *)__unused collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (iosMajorVersion() < 8)
        return;
    
    if (indexPath.section == 0) {
        if (indexPath.item == 0 && _showGifs) {
            if ([cell isKindOfClass:[TGStickerKeyboardTabSettingsCell class]])
            {
                TGStickerKeyboardTabSettingsCell *settingsCell = (TGStickerKeyboardTabSettingsCell *)cell;
                [settingsCell setInnerAlpha:_expanded && settingsCell.mode == TGStickerKeyboardTabSettingsCellGifs ? 0.0f : 1.0f];
            }
        }
    }
}

- (void)collectionView:(UICollectionView *)__unused collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (iosMajorVersion() < 8)
        return;
    
    if (indexPath.section == 0) {
        if (indexPath.item == 0 && _showGifs) {
            if ([cell isKindOfClass:[TGStickerKeyboardTabSettingsCell class]])
            {
                TGStickerKeyboardTabSettingsCell *settingsCell = (TGStickerKeyboardTabSettingsCell *)cell;
                [settingsCell setInnerAlpha:_expanded && settingsCell.mode == TGStickerKeyboardTabSettingsCellGifs ? 0.0f : 1.0f];
            }
        }
    }
}

- (void)updateCellsVisibility
{
    if (!_expanded)
        return;
    
    for (UICollectionViewCell *cell in _collectionView.visibleCells)
    {
        if ([cell isKindOfClass:[TGStickerKeyboardTabSettingsCell class]])
        {
            TGStickerKeyboardTabSettingsCell *settingsCell = (TGStickerKeyboardTabSettingsCell *)cell;
            [settingsCell setInnerAlpha:settingsCell.mode == TGStickerKeyboardTabSettingsCellGifs ? 0.0f : 1.0f];
        }
        else
        {
            if ([cell isKindOfClass:[TGStickerKeyboardTabCell class]])
            {
                TGStickerKeyboardTabCell *tabCell = (TGStickerKeyboardTabCell *)cell;
                [tabCell setInnerAlpha:1.0f];
            }
        }
    }
}

- (void)collectionView:(UICollectionView *)__unused collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (indexPath.item == 0 && _showGifs) {
            [self scrollToGifsButton];
        } else {
            [self scrollToTrendingButton];
        }
    } else if (indexPath.section == 1) {
        if (_currentStickerPackIndexChanged)
            _currentStickerPackIndexChanged(indexPath.item);
    } else if (indexPath.section == 2) {
        if (indexPath.item == 0 && _showTrendingLast) {
            [self scrollToTrendingButton];
        }
    }
}

- (void)setStickerPacks:(NSArray *)stickerPacks showRecent:(bool)showRecent showGifs:(bool)showGifs showTrendingFirst:(bool)showTrendingFirst showTrendingLast:(bool)showTrendingLast {
    _stickerPacks = stickerPacks;
    _showRecent = showRecent;
    _showGifs = showGifs;
    _showTrendingFirst = showTrendingFirst;
    _showTrendingLast = showTrendingLast;
    
    [_collectionView reloadData];
}

- (void)setCurrentStickerPackIndex:(NSUInteger)currentStickerPackIndex animated:(bool)animated
{
    NSArray *selectedItems = [_collectionView indexPathsForSelectedItems];
    if (selectedItems.count == 1 && ((NSIndexPath *)selectedItems[0]).item == (NSInteger)currentStickerPackIndex)
        return;
    
    UICollectionViewLayoutAttributes *attributes = [_collectionLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:currentStickerPackIndex inSection:1]];
    UICollectionViewScrollPosition scrollPosition = UICollectionViewScrollPositionNone;
    if (!CGRectContainsRect(_collectionView.bounds, attributes.frame))
    {
        if (attributes.frame.origin.x < _collectionView.bounds.origin.x + _collectionView.bounds.size.width / 2.0f)
        {
            scrollPosition = UICollectionViewScrollPositionLeft;
        }
        else
            scrollPosition = UICollectionViewScrollPositionRight;
    }
    [_collectionView selectItemAtIndexPath:[NSIndexPath indexPathForItem:currentStickerPackIndex inSection:1] animated:animated scrollPosition:scrollPosition];
}

- (void)setCurrentGifsModeSelected {
    [self scrollToGifsButton];
}

- (void)setCurrentTrendingModeSelected {
    [self scrollToTrendingButton];
}

- (void)scrollToGifsButton {
    UICollectionViewLayoutAttributes *attributes = [_collectionLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    UICollectionViewScrollPosition scrollPosition = UICollectionViewScrollPositionNone;
    if (!CGRectContainsRect(_collectionView.bounds, attributes.frame))
    {
        if (attributes.frame.origin.x < _collectionView.bounds.origin.x + _collectionView.bounds.size.width / 2.0f)
        {
            scrollPosition = UICollectionViewScrollPositionLeft;
        }
        else
            scrollPosition = UICollectionViewScrollPositionRight;
    }
    [_collectionView selectItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] animated:false scrollPosition:scrollPosition];
    
    if (_navigateToGifs) {
        _navigateToGifs();
    }
}

- (void)scrollToTrendingButton {
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:_showGifs ? 1 : 0 inSection:0];
    if (_showTrendingLast) {
        indexPath = [NSIndexPath indexPathForItem:0 inSection:2];
    }
    if (indexPath.section < [self numberOfSectionsInCollectionView:_collectionView] && indexPath.item < [self collectionView:_collectionView numberOfItemsInSection:indexPath.section]) {
        UICollectionViewLayoutAttributes *attributes = [_collectionLayout layoutAttributesForItemAtIndexPath:indexPath];
        
        UICollectionViewScrollPosition scrollPosition = UICollectionViewScrollPositionNone;
        if (!CGRectContainsRect(_collectionView.bounds, attributes.frame))
        {
            if (attributes.frame.origin.x < _collectionView.bounds.origin.x + _collectionView.bounds.size.width / 2.0f)
                scrollPosition = UICollectionViewScrollPositionLeft;
            else
                scrollPosition = UICollectionViewScrollPositionRight;
        }
        [_collectionView selectItemAtIndexPath:indexPath animated:false scrollPosition:scrollPosition];
        
        if (_showTrendingLast) {
            if (_navigateToTrendingLast) {
                _navigateToTrendingLast();
            }
        } else {
            if (_navigateToTrendingFirst) {
                _navigateToTrendingFirst();
            }
        }
    }
}

- (void)setTrendingStickersBadge:(NSString *)badge {
    if (!TGStringCompare(_trendingStickersBadge, badge)) {
        _trendingStickersBadge = badge;
        for (id cell in [_collectionView visibleCells]) {
            if ([cell isKindOfClass:[TGStickerKeyboardTabSettingsCell class]]) {
                if (((TGStickerKeyboardTabSettingsCell *)cell).mode == TGStickerKeyboardTabSettingsCellTrending) {
                    [(TGStickerKeyboardTabSettingsCell *)cell setBadge:badge];
                }
            }
        }
        TGStickerKeyboardTabSettingsCell *cell = (TGStickerKeyboardTabSettingsCell *)[_collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:2]];
        if (cell != nil) {
            [cell setBadge:badge];
        }
    }
}

- (void)setExpanded:(bool)expanded
{
    _expanded = expanded;
    
    [self updateExpanded:expanded];
}

- (void)updateExpanded:(bool)expanded
{
    if (iosMajorVersion() < 8)
        return;
    
    [UIView animateWithDuration:0.2 animations:^
    {
        _collectionView.contentInset = expanded ? UIEdgeInsetsMake(0.0f, -48.0f, 0.0f, 0.0f) : UIEdgeInsetsZero;
        
        if (!expanded && _collectionView.contentOffset.x <= 60.0f)
            [_collectionView setContentOffset:CGPointZero];
        
        TGStickerKeyboardTabSettingsCell *cell = (TGStickerKeyboardTabSettingsCell *)[_collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if ([cell isKindOfClass:[TGStickerKeyboardTabSettingsCell class]] && _showGifs && !expanded)
            [cell setInnerAlpha:1.0f];
    } completion:^(BOOL finished)
    {
        if (expanded && finished)
            [self updateCellsVisibility];
    }];
}

@end

