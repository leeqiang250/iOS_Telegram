#import "TGMediaPickerGalleryModel.h"

#import "TGMediaPickerGallerySelectedItemsModel.h"

#import "TGModernGalleryController.h"
#import "TGModernGalleryItem.h"
#import "TGModernGallerySelectableItem.h"
#import "TGModernGalleryEditableItem.h"
#import "TGModernGalleryEditableItemView.h"
#import "TGModernGalleryZoomableItemView.h"
#import "TGMediaPickerGalleryVideoItemView.h"

#import "TGModernMediaListItem.h"
#import "TGModernMediaListSelectableItem.h"

#import "PGPhotoEditorValues.h"

#import "TGSecretTimerMenu.h"

@interface TGMediaPickerGalleryModel ()
{
    id<TGModernGalleryEditableItem> _itemBeingEdited;
    TGMediaEditingContext *_editingContext;
}

@property (nonatomic, weak) TGPhotoEditorController *editorController;

@end

@implementation TGMediaPickerGalleryModel

- (instancetype)initWithItems:(NSArray *)items focusItem:(id<TGModernGalleryItem>)focusItem selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer inhibitDocumentCaptions:(bool)inhibitDocumentCaptions hasSelectionPanel:(bool)hasSelectionPanel recipientName:(NSString *)recipientName
{
    self = [super init];
    if (self != nil)
    {
        [self _replaceItems:items focusingOnItem:focusItem];
        
        _editingContext = editingContext;
        _selectionContext = selectionContext;
        
        __weak TGMediaPickerGalleryModel *weakSelf = self;
        if (selectionContext != nil)
        {
            _selectedItemsModel = [[TGMediaPickerGallerySelectedItemsModel alloc] initWithSelectionContext:selectionContext];
            _selectedItemsModel.selectionUpdated = ^(bool reload, bool incremental, bool add, NSInteger index)
            {
                __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;

                [strongSelf.interfaceView updateSelectionInterface:[strongSelf selectionCount] counterVisible:([strongSelf selectionCount] > 0) animated:incremental];
                [strongSelf.interfaceView updateSelectedPhotosView:reload incremental:incremental add:add index:index];
            };
        }
        
        _interfaceView = [[TGMediaPickerGalleryInterfaceView alloc] initWithFocusItem:focusItem selectionContext:selectionContext editingContext:editingContext hasSelectionPanel:hasSelectionPanel recipientName:recipientName];
        _interfaceView.hasCaptions = hasCaptions;
        _interfaceView.hasTimer = hasTimer;
        _interfaceView.inhibitDocumentCaptions = inhibitDocumentCaptions;
        [_interfaceView setEditorTabPressed:^(TGPhotoEditorTab tab)
        {
            __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGModernGalleryController *controller = strongSelf.controller;
            if ([controller.currentItem conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
                [strongSelf presentPhotoEditorForItem:(id<TGModernGalleryEditableItem>)controller.currentItem tab:tab];
        }];
        _interfaceView.photoStripItemSelected = ^(NSInteger index)
        {
            __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf setCurrentItemWithIndex:index];
        };
        _interfaceView.captionSet = ^(id<TGModernGalleryEditableItem> item, NSString *caption)
        {
            __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf.saveItemCaption == nil)
                return;
            
            __strong TGModernGalleryController *controller = strongSelf.controller;
            if ([controller.currentItem conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
                strongSelf.saveItemCaption(((id<TGModernGalleryEditableItem>)item).editableMediaItem, caption);
        };
        _interfaceView.timerRequested = ^
        {
            __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGModernGalleryController *controller = strongSelf.controller;
            id<TGMediaEditableItem> editableMediaItem = ((id<TGModernGalleryEditableItem>)controller.currentItem).editableMediaItem;
            
            NSString *description = editableMediaItem.isVideo ? TGLocalized(@"SecretTimer.VideoDescription") : TGLocalized(@"SecretTimer.ImageDescription");
            
            NSString *lastValueKey = @"mediaPickerLastTimerValue_v0";
            NSNumber *value = [strongSelf->_editingContext timerForItem:editableMediaItem];
            if (value == nil)
                value = [[NSUserDefaults standardUserDefaults] objectForKey:lastValueKey];
            
            [TGSecretTimerMenu presentInParentController:controller dark:true description:description values:[TGSecretTimerMenu secretMediaTimerValues] value:value completed:^(NSNumber *value)
            {
                __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (value == nil)
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:lastValueKey];
                else
                    [[NSUserDefaults standardUserDefaults] setObject:value forKey:lastValueKey];
                
                [strongSelf->_editingContext setTimer:value forItem:editableMediaItem];
                
                if (value.integerValue != 0)
                {
                    __strong TGModernGalleryController *controller = strongSelf.controller;
                    id<TGMediaSelectableItem> selectableItem = nil;
                    if ([controller.currentItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
                    {
                        selectableItem = ((id<TGModernGallerySelectableItem>)controller.currentItem).selectableMediaItem;
                        
                        if (selectableItem != nil)
                            [strongSelf->_selectionContext setItem:selectableItem selected:true animated:false sender:nil];
                    }
                }
            } dismissed:^
            {
                __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf->_interfaceView setAllInterfaceHidden:false delay:0.0f animated:true];
            } sourceView:controller.view sourceRect:^CGRect
            {
                __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return CGRectZero;
                
                __strong TGModernGalleryController *controller = strongSelf.controller;
                return [strongSelf->_interfaceView.timerButton convertRect:strongSelf->_interfaceView.timerButton.bounds toView:controller.view];
            }];
        };
    }
    return self;
}

- (void)setSuggestionContext:(TGSuggestionContext *)suggestionContext
{
    _suggestionContext = suggestionContext;
    [_interfaceView setSuggestionContext:suggestionContext];
}

- (NSInteger)selectionCount
{
    if (self.externalSelectionCount != nil)
        return self.externalSelectionCount();
    
    return _selectedItemsModel.selectedCount;
}

- (void)setCurrentItem:(id<TGMediaSelectableItem>)item direction:(TGModernGalleryScrollAnimationDirection)direction
{
    if (![(id)item conformsToProtocol:@protocol(TGMediaSelectableItem)])
        return;
    
    id<TGMediaSelectableItem> targetSelectableItem = (id<TGMediaSelectableItem>)item;
    
    __block NSUInteger newIndex = NSNotFound;
    [self.items enumerateObjectsUsingBlock:^(id<TGModernGalleryItem> galleryItem, NSUInteger idx, BOOL *stop)
    {
         if ([galleryItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
         {
             id<TGMediaSelectableItem> selectableItem = ((id<TGModernGallerySelectableItem>)galleryItem).selectableMediaItem;
             
             if ([selectableItem.uniqueIdentifier isEqual:targetSelectableItem.uniqueIdentifier])
             {
                 newIndex = idx;
                 *stop = true;
             }
         }
    }];
    
    TGModernGalleryController *galleryController = self.controller;
    [galleryController setCurrentItemIndex:newIndex direction:direction animated:true];
}

- (void)setCurrentItemWithIndex:(NSUInteger)index
{
    if (_selectedItemsModel == nil)
        return;
    
    TGModernGalleryController *galleryController = self.controller;
    
    if (![galleryController.currentItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
        return;
    
    id<TGModernGallerySelectableItem> currentGalleryItem = (id<TGModernGallerySelectableItem>)galleryController.currentItem;

    __block NSUInteger currentSelectedItemIndex = NSNotFound;
    [_selectedItemsModel.items enumerateObjectsUsingBlock:^(id<TGMediaSelectableItem> item, NSUInteger index, BOOL *stop)
    {
        if ([item.uniqueIdentifier isEqualToString:currentGalleryItem.selectableMediaItem.uniqueIdentifier])
        {
            currentSelectedItemIndex = index;
            *stop = true;
        }
    }];

    id<TGMediaSelectableItem> item = _selectedItemsModel.items[index];
    
    TGModernGalleryScrollAnimationDirection direction = TGModernGalleryScrollAnimationDirectionLeft;
    if (currentSelectedItemIndex < index)
        direction = TGModernGalleryScrollAnimationDirectionRight;
    
    [self setCurrentItem:item direction:direction];
}

- (UIView <TGModernGalleryInterfaceView> *)createInterfaceView
{
    return _interfaceView;
}

- (UIView *)referenceViewForItem:(id<TGModernGalleryItem>)item frame:(CGRect *)frame
{
    TGModernGalleryController *galleryController = self.controller;
    TGModernGalleryItemView *galleryItemView = [galleryController itemViewForItem:item];
    
    if ([galleryItemView isKindOfClass:[TGModernGalleryZoomableItemView class]])
    {
        TGModernGalleryZoomableItemView *zoomableItemView = (TGModernGalleryZoomableItemView *)galleryItemView;
        
        if (zoomableItemView.contentView != nil)
        {
            if (frame != NULL)
                *frame = [zoomableItemView transitionViewContentRect];
            
            return (UIImageView *)zoomableItemView.transitionContentView;
        }
    }
    else if ([galleryItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
    {
        TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)galleryItemView;
        
        if (frame != NULL)
            *frame = [videoItemView transitionViewContentRect];
        
        return (UIView *)videoItemView;
    }
    
    return nil;
}

- (void)updateHiddenItem
{
    TGModernGalleryController *galleryController = self.controller;
    
    for (TGModernGalleryItemView *itemView in galleryController.visibleItemViews)
    {
        if ([itemView conformsToProtocol:@protocol(TGModernGalleryEditableItemView)])
            [(TGModernGalleryItemView <TGModernGalleryEditableItemView> *)itemView setHiddenAsBeingEdited:[itemView.item isEqual:_itemBeingEdited]];
    }
}

- (void)updateEditedItemView
{
    TGModernGalleryController *galleryController = self.controller;
    
    for (TGModernGalleryItemView *itemView in galleryController.visibleItemViews)
    {
        if ([itemView conformsToProtocol:@protocol(TGModernGalleryEditableItemView)])
        {
            if ([itemView.item isEqual:_itemBeingEdited])
            {
                [(TGModernGalleryItemView <TGModernGalleryEditableItemView> *)itemView setItem:_itemBeingEdited synchronously:true];
                if (self.itemsUpdated != nil)
                    self.itemsUpdated(_itemBeingEdited);
            }
        }
    }
}

- (void)presentPhotoEditorForItem:(id<TGModernGalleryEditableItem>)item tab:(TGPhotoEditorTab)tab
{
    __weak TGMediaPickerGalleryModel *weakSelf = self;
    
    if (_itemBeingEdited != nil)
        return;
    
    _itemBeingEdited = item;

    PGPhotoEditorValues *editorValues = (PGPhotoEditorValues *)[item.editingContext adjustmentsForItem:item.editableMediaItem];
    
    NSString *caption = [item.editingContext captionForItem:item.editableMediaItem];

    CGRect refFrame = CGRectZero;
    UIView *editorReferenceView = [self referenceViewForItem:item frame:&refFrame];
    UIView *referenceView = nil;
    UIImage *screenImage = nil;
    UIView *referenceParentView = nil;
    UIImage *image = nil;
    
    bool isVideo = false;
    if ([editorReferenceView isKindOfClass:[UIImageView class]])
    {
        screenImage = [(UIImageView *)editorReferenceView image];
        referenceView = editorReferenceView;
    }
    else if ([editorReferenceView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
    {
        TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)editorReferenceView;
        [videoItemView prepareForEditing];
        
        refFrame = [videoItemView editorTransitionViewRect];
        screenImage = [videoItemView transitionImage];
        image = [videoItemView screenImage];
        referenceView = [[UIImageView alloc] initWithImage:screenImage];
        referenceParentView = editorReferenceView;
        
        isVideo = true;
    }
    
    if (self.useGalleryImageAsEditableItemImage && self.storeOriginalImageForItem != nil)
        self.storeOriginalImageForItem(item.editableMediaItem, screenImage);
    
    TGPhotoEditorControllerIntent intent = isVideo ? TGPhotoEditorControllerVideoIntent : TGPhotoEditorControllerGenericIntent;
    TGPhotoEditorController *controller = [[TGPhotoEditorController alloc] initWithItem:item.editableMediaItem intent:intent adjustments:editorValues caption:caption screenImage:screenImage availableTabs:_interfaceView.currentTabs selectedTab:tab];
    controller.editingContext = _editingContext;
    self.editorController = controller;
    controller.suggestionContext = self.suggestionContext;
    controller.willFinishEditing = ^(id<TGMediaEditAdjustments> adjustments, id temporaryRep, bool hasChanges)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_itemBeingEdited = nil;
        
        if (strongSelf.willFinishEditingItem != nil)
            strongSelf.willFinishEditingItem(item.editableMediaItem, adjustments, temporaryRep, hasChanges);
    };
    
    void (^didFinishEditingItem)(id<TGMediaEditableItem>item, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage) = self.didFinishEditingItem;
    controller.didFinishEditing = ^(id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage, bool hasChanges)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil) {
            TGLog(@"controller.didFinishEditing strongSelf == nil");
        }
        
#ifdef DEBUG
        if (adjustments != nil && hasChanges && !isVideo)
            NSAssert(resultImage != nil, @"resultImage should not be nil");
#endif
        
        if (hasChanges)
        {
            if (didFinishEditingItem != nil) {
                didFinishEditingItem(item.editableMediaItem, adjustments, resultImage, thumbnailImage);
            }
        }
        
        if ([editorReferenceView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
        {
            TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)editorReferenceView;
            [videoItemView setScrubbingPanelApperanceLocked:false];
            [videoItemView presentScrubbingPanelAfterReload:hasChanges];
        }
    };
    
    controller.didFinishRenderingFullSizeImage = ^(UIImage *image)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.didFinishRenderingFullSizeImage != nil)
            strongSelf.didFinishRenderingFullSizeImage(item.editableMediaItem, image);
    };
    
    controller.captionSet = ^(NSString *caption)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.saveItemCaption != nil)
            strongSelf.saveItemCaption(item.editableMediaItem, caption);
    };
    
    controller.requestToolbarsHidden = ^(bool hidden, bool animated)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.interfaceView setToolbarsHidden:hidden animated:animated];
    };

    controller.beginTransitionIn = ^UIView *(CGRect *referenceFrame, __unused UIView **parentView)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        if (strongSelf.editorOpened != nil)
            strongSelf.editorOpened();
        
        [strongSelf updateHiddenItem];
        [strongSelf.interfaceView editorTransitionIn];
        
        *referenceFrame = refFrame;
        
        if (referenceView.superview == nil)
            *parentView = referenceParentView;
        
        if (iosMajorVersion() >= 7)
            [strongSelf.controller setNeedsStatusBarAppearanceUpdate];
        else
            [[UIApplication sharedApplication] setStatusBarHidden:true];
        
        return referenceView;
    };
    
    controller.finishedTransitionIn = ^
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGModernGalleryController *galleryController = strongSelf.controller;
        TGModernGalleryItemView *galleryItemView = [galleryController itemViewForItem:strongSelf->_itemBeingEdited];
        if (![galleryItemView isKindOfClass:[TGModernGalleryZoomableItemView class]])
            return;
        
        TGModernGalleryZoomableItemView *zoomableItemView = (TGModernGalleryZoomableItemView *)galleryItemView;
        [zoomableItemView reset];
    };
    
    controller.beginTransitionOut = ^UIView *(CGRect *referenceFrame, __unused UIView **parentView)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        [strongSelf.interfaceView editorTransitionOut];
        
        CGRect refFrame;
        UIView *referenceView = [strongSelf referenceViewForItem:item frame:&refFrame];
        if ([referenceView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
        {
            TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)referenceView;
            refFrame = [videoItemView editorTransitionViewRect];
            UIImage *screenImage = [videoItemView transitionImage];
            *parentView = referenceView;
            referenceView = [[UIImageView alloc] initWithImage:screenImage];
        }
        
        *referenceFrame = refFrame;
        
        return referenceView;
    };
    
    controller.finishedTransitionOut = ^(__unused bool saved)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.editorClosed != nil)
            strongSelf.editorClosed();
        
        [strongSelf updateHiddenItem];
        
        UIView *referenceView = [strongSelf referenceViewForItem:item frame:NULL];
        if ([referenceView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
            [(TGMediaPickerGalleryVideoItemView *)referenceView setPlayButtonHidden:false animated:true];
        
        if (iosMajorVersion() >= 7)
            [strongSelf.controller setNeedsStatusBarAppearanceUpdate];
        else
            [[UIApplication sharedApplication] setStatusBarHidden:false];
    };
    
    controller.requestThumbnailImage = ^SSignal *(id<TGMediaEditableItem> editableItem)
    {
        return [editableItem thumbnailImageSignal];
    };
    
    controller.requestOriginalScreenSizeImage = ^SSignal *(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem screenImageSignal:position];
    };
    
    controller.requestOriginalFullSizeImage = ^SSignal *(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem originalImageSignal:position];
    };
    
    controller.requestAdjustments = ^id<TGMediaEditAdjustments> (id<TGMediaEditableItem> editableItem)
    {
        __strong TGMediaPickerGalleryModel *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.requestAdjustments != nil)
            return strongSelf.requestAdjustments(editableItem);
    
        return nil;
    };
    
    controller.requestImage = ^
    {
        return image;
    };
    
    [self.controller addChildViewController:controller];
    [self.controller.view addSubview:controller.view];
}

- (void)_replaceItems:(NSArray *)items focusingOnItem:(id<TGModernGalleryItem>)item
{
    [super _replaceItems:items focusingOnItem:item];
 
    TGModernGalleryController *controller = self.controller;
    
    NSArray *itemViews = [controller.visibleItemViews copy];
    for (TGModernGalleryItemView *itemView in itemViews)
        [itemView setItem:itemView.item synchronously:false];
}

- (bool)_shouldAutorotate
{
    TGPhotoEditorController *editorController = self.editorController;
    return (!editorController || [editorController shouldAutorotate]);
}

@end
