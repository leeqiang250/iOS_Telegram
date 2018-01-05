#import "TGSharedMediaCollectionView.h"

#import "TGSharedMediaCollectionLayout.h"
#import "TGSharedMediaSectionHeader.h"
#import "TGSharedMediaSectionHeaderView.h"

@interface TGSharedMediaCollectionView ()
{
    NSMutableArray *_sectionHeaderViewQueue;
    NSMutableArray *_visibleSectionHeaderViews;
}

@end

@implementation TGSharedMediaCollectionView

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
    self = [super initWithFrame:frame collectionViewLayout:layout];
    if (self != nil)
    {
        _sectionHeaderViewQueue = [[NSMutableArray alloc] init];
        _visibleSectionHeaderViews = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)reloadData
{
    for (TGSharedMediaSectionHeaderView *headerView in _visibleSectionHeaderViews)
    {
        [self enqueueSectionHeaderView:headerView];
    }
    [_visibleSectionHeaderViews removeAllObjects];
    
    [super reloadData];
}

- (TGSharedMediaSectionHeaderView *)dequeueSectionHeaderView
{
    TGSharedMediaSectionHeaderView *headerView = [_sectionHeaderViewQueue lastObject];
    if (headerView != nil)
    {
        [_sectionHeaderViewQueue removeLastObject];
        return headerView;
    }
    else
    {
        headerView = [[TGSharedMediaSectionHeaderView alloc] init];
        return headerView;
    }
}

- (void)enqueueSectionHeaderView:(TGSharedMediaSectionHeaderView *)headerView
{
    [headerView removeFromSuperview];
    [_sectionHeaderViewQueue addObject:headerView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    UIEdgeInsets insets = self.contentInset;
    
    UIView *topmostViewForHeaders = nil;
    
    for (TGSharedMediaSectionHeader *sectionHeader in [(TGSharedMediaCollectionLayout *)self.collectionViewLayout sectionHeaders])
    {
        CGRect headerFloatingBounds = sectionHeader.floatingFrame;
        
        if (CGRectIntersectsRect(bounds, headerFloatingBounds))
        {
            TGSharedMediaSectionHeaderView *headerView = nil;
            for (TGSharedMediaSectionHeaderView *visibleHeaderView in _visibleSectionHeaderViews)
            {
                if (visibleHeaderView.index == sectionHeader.index)
                {
                    headerView = visibleHeaderView;
                    break;
                }
            }
            
            if (headerView == nil)
            {
                headerView = [self dequeueSectionHeaderView];
                headerView.index = sectionHeader.index;
                id<TGSharedMediaCollectionViewDelegate> delegate = (id<TGSharedMediaCollectionViewDelegate>)self.delegate;
                [delegate collectionView:self setupSectionHeaderView:headerView forSectionHeader:sectionHeader];
                [_visibleSectionHeaderViews addObject:headerView];
                
                if (topmostViewForHeaders == nil)
                    topmostViewForHeaders = [[self visibleCells] lastObject];
                
                if (topmostViewForHeaders == nil)
                    [self insertSubview:headerView atIndex:0];
                else
                    [self insertSubview:headerView aboveSubview:topmostViewForHeaders];
            }
            
            CGRect headerFrame = sectionHeader.bounds;
            headerFrame.origin.y = MIN(headerFloatingBounds.origin.y + headerFloatingBounds.size.height - headerFrame.size.height, MAX(headerFloatingBounds.origin.y, bounds.origin.y + insets.top));
            headerView.frame = headerFrame;
            [headerView.layer removeAllAnimations];
        }
        else
        {
            NSInteger index = -1;
            for (TGSharedMediaSectionHeaderView *headerView in _visibleSectionHeaderViews)
            {
                index++;
                if (headerView.index == sectionHeader.index)
                {
                    [self enqueueSectionHeaderView:headerView];
                    [_visibleSectionHeaderViews removeObjectAtIndex:index];
                    break;
                }
            }
        }
    }
}

@end
