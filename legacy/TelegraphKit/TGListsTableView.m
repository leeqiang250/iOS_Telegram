/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGListsTableView.h"

#import "TGSearchBar.h"

#import "Freedom.h"

#import <objc/runtime.h>

@interface TGListsTableView ()
{
    UIView *_whiteFooterView;
    bool _hackHeaderSize;
}

@end

@implementation TGListsTableView

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self != nil)
    {
        if (iosMajorVersion() < 7)
        {
            self.backgroundView = [[UIView alloc] init];
            self.backgroundView.backgroundColor = [UIColor whiteColor];
        }
        else
        {
            _whiteFooterView = [[UIView alloc] init];
            _whiteFooterView.backgroundColor = [UIColor whiteColor];
            _whiteFooterView.userInteractionEnabled = false;
            [self insertSubview:_whiteFooterView atIndex:0];
        }
    }
    
    if ([self respondsToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
        if (@available(iOS 11.0, *)) {
            self.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        } else {
            // Fallback on earlier versions
        }
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    if (_whiteFooterView != nil)
        _whiteFooterView.frame = CGRectMake(0.0f, MAX(0.0f, bounds.origin.y), bounds.size.width, bounds.size.height);
    else
        self.backgroundView.frame = CGRectMake(0.0f, MAX(0.0f, bounds.origin.y), bounds.size.width, bounds.size.height);
    
    if (_hackHeaderSize)
    {
        UIView *tableHeaderView = self.tableHeaderView;
        if (tableHeaderView != nil)
        {
            CGSize size = self.frame.size;
            
            CGRect frame = tableHeaderView.frame;
            if (frame.size.width < size.width)
            {
                frame.size.width = size.width;
                tableHeaderView.frame = frame;
            }
        }
    }
    
    UIView *tableHeaderView = self.tableHeaderView;
    if (tableHeaderView != nil && [tableHeaderView respondsToSelector:@selector(updateClipping:)])
    {
        [(TGSearchBar *)tableHeaderView updateClipping:bounds.origin.y + self.contentInset.top];
    }
    
    UIView *indexView = self.subviews.lastObject;
    if ([NSStringFromClass([indexView class]) rangeOfString:@"ViewIndex"].location != NSNotFound)
    {
        indexView.frame = CGRectMake(self.frame.size.width - indexView.frame.size.width - self.indexOffset, indexView.frame.origin.y, indexView.frame.size.width, indexView.frame.size.height);
    }
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index {
    if (index == 0 && view != _whiteFooterView) {
        index = 1;
    }
    [super insertSubview:view atIndex:index];
}

- (void)didAddSubview:(UIView *)subview
{
    [super didAddSubview:subview];
    if (!self.mayHaveIndex)
        return;
    
    if (iosMajorVersion() >= 7)
    {
        static Class indexClass = Nil;
        static ptrdiff_t backgroundColorPtr = -1;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            indexClass = freedomClass(0xd93a1ed6U);
            if (indexClass != Nil)
                backgroundColorPtr = freedomIvarOffset(indexClass, 0xca7e3046U);
        });
        
        if ([subview isKindOfClass:indexClass] && backgroundColorPtr >= 0)
        {
            __strong UIColor **backgroundColor = (__strong UIColor **)(void *)(((uint8_t *)(__bridge void *)subview) + backgroundColorPtr);
            *backgroundColor = [UIColor clearColor];
        }
    }
}

- (void)sendSubviewToBack:(UIView *)view
{
    [super sendSubviewToBack:view];
    if (_whiteFooterView != nil && view != _whiteFooterView)
        [super sendSubviewToBack:_whiteFooterView];
}


- (void)hackHeaderSize
{
    _hackHeaderSize = true;
}

- (void)adjustBehaviour
{
    //FreedomBitfield tableFlagsOffset = freedomIvarBitOffset([UITableView class], 0x3fa93ecU, 0xe3ca73b1U);
    //if (tableFlagsOffset.offset != -1 && tableFlagsOffset.bit != -1)
    //    freedomSetBitfield((__bridge void *)self, tableFlagsOffset, 1);
}

- (void)scrollToTop
{
    if (iosMajorVersion() >= 11)
        [self performCustomScrollToTop];
    else
        [self setContentOffset:CGPointMake(0.0f, -self.contentInset.top) animated:true];
}

- (void)performCustomScrollToTop
{
    [self setContentOffset:self.contentOffset animated:false];
    self.blockContentOffset = true;

    self.frame=CGRectMake(self.frame.origin.x, self.frame.origin.y-self.contentInset.top, self.frame.size.width,self.frame.size.height);
}

- (void)setContentOffset:(CGPoint)contentOffset
{
    if (_blockContentOffset)
        return;
    
    [super setContentOffset:contentOffset];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (_onHitTest) {
        _onHitTest(point);
    }
    return [super hitTest:point withEvent:event];
}

@end
