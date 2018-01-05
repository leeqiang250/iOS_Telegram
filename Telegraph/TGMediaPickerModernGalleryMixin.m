#import "TGMediaPickerModernGalleryMixin.h"

#import "TGModernGalleryController.h"
#import "TGMediaPickerGalleryItem.h"
#import "TGMediaPickerGalleryPhotoItem.h"
#import "TGMediaPickerGalleryVideoItem.h"
#import "TGMediaPickerGalleryVideoItemView.h"
#import "TGMediaPickerGalleryGifItem.h"

#import "TGMediaEditingContext.h"
#import "TGMediaSelectionContext.h"
#import "TGSuggestionContext.h"

#import "TGMediaAsset.h"
#import "TGMediaAssetFetchResult.h"
#import "TGMediaAssetMomentList.h"
#import "TGMediaAssetMoment.h"

#import "TGOverlayControllerWindow.h"

@interface TGMediaPickerModernGalleryMixin ()
{
    TGMediaEditingContext *_editingContext;
    bool _asFile;
    
    __weak TGViewController *_parentController;
    __weak TGModernGalleryController *_galleryController;
    TGModernGalleryController *_strongGalleryController;
    
    NSUInteger _itemsLimit;
}
@end

@implementation TGMediaPickerModernGalleryMixin

- (instancetype)initWithItem:(id)item fetchResult:(TGMediaAssetFetchResult *)fetchResult parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext suggestionContext:(TGSuggestionContext *)suggestionContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer inhibitDocumentCaptions:(bool)inhibitDocumentCaptions asFile:(bool)asFile itemsLimit:(NSUInteger)itemsLimit recipientName:(NSString *)recipientName
{
    return [self initWithItem:item fetchResult:fetchResult momentList:nil parentController:parentController thumbnailImage:thumbnailImage selectionContext:selectionContext editingContext:editingContext suggestionContext:suggestionContext hasCaptions:hasCaptions hasTimer:hasTimer inhibitDocumentCaptions:inhibitDocumentCaptions asFile:asFile itemsLimit:itemsLimit recipientName:recipientName];
}

- (instancetype)initWithItem:(id)item momentList:(TGMediaAssetMomentList *)momentList parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext suggestionContext:(TGSuggestionContext *)suggestionContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer inhibitDocumentCaptions:(bool)inhibitDocumentCaptions asFile:(bool)asFile itemsLimit:(NSUInteger)itemsLimit
{
    return [self initWithItem:item fetchResult:nil momentList:momentList parentController:parentController thumbnailImage:thumbnailImage selectionContext:selectionContext editingContext:editingContext suggestionContext:suggestionContext hasCaptions:hasCaptions hasTimer:hasTimer inhibitDocumentCaptions:inhibitDocumentCaptions asFile:asFile itemsLimit:itemsLimit recipientName:nil];
}

- (instancetype)initWithItem:(id)item fetchResult:(TGMediaAssetFetchResult *)fetchResult momentList:(TGMediaAssetMomentList *)momentList parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext suggestionContext:(TGSuggestionContext *)suggestionContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer inhibitDocumentCaptions:(bool)inhibitDocumentCaptions asFile:(bool)asFile itemsLimit:(NSUInteger)itemsLimit recipientName:(NSString *)recipientName
{
    self = [super init];
    if (self != nil)
    {
        _parentController = parentController;
        _editingContext = asFile ? nil : editingContext;
        _asFile = asFile;
        _itemsLimit = itemsLimit;
        
        __weak TGMediaPickerModernGalleryMixin *weakSelf = self;
        
        TGModernGalleryController *modernGallery = [[TGModernGalleryController alloc] init];
        _galleryController = modernGallery;
        _strongGalleryController = modernGallery;
        modernGallery.isImportant = true;
        
        __block id<TGModernGalleryItem> focusItem = nil;
        void (^enumerationBlock)(TGMediaPickerGalleryItem *) = ^(TGMediaPickerGalleryItem *galleryItem)
        {
            if (focusItem == nil && [galleryItem.asset isEqual:item])
            {
                focusItem = galleryItem;
                galleryItem.immediateThumbnailImage = thumbnailImage;
            }
        };
        
        NSArray *galleryItems = fetchResult != nil ? [self prepareGalleryItemsForFetchResult:fetchResult selectionContext:selectionContext editingContext:editingContext asFile:asFile enumerationBlock:enumerationBlock] : [self prepareGalleryItemsForMomentList:momentList selectionContext:selectionContext editingContext:editingContext asFile:asFile enumerationBlock:enumerationBlock];
        
        TGMediaPickerGalleryModel *model = [[TGMediaPickerGalleryModel alloc] initWithItems:galleryItems focusItem:focusItem selectionContext:selectionContext editingContext:editingContext hasCaptions:hasCaptions hasTimer:hasTimer inhibitDocumentCaptions:inhibitDocumentCaptions hasSelectionPanel:true recipientName:recipientName];
        _galleryModel = model;
        model.controller = modernGallery;
        model.suggestionContext = suggestionContext;
        model.willFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, id<TGMediaEditAdjustments> adjustments, id representation, bool hasChanges)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (hasChanges)
            {
                [editingContext setAdjustments:adjustments forItem:editableItem];
                [editingContext setTemporaryRep:representation forItem:editableItem];
            }
            
            if (selectionContext != nil && adjustments != nil && [editableItem conformsToProtocol:@protocol(TGMediaSelectableItem)])
                [selectionContext setItem:(id<TGMediaSelectableItem>)editableItem selected:true];
        };
        
        model.didFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, __unused id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage)
        {
            [editingContext setImage:resultImage thumbnailImage:thumbnailImage forItem:editableItem synchronous:false];
        };
        
        model.didFinishRenderingFullSizeImage = ^(id<TGMediaEditableItem> editableItem, UIImage *resultImage)
        {
            [editingContext setFullSizeImage:resultImage forItem:editableItem];
        };
        
        model.saveItemCaption = ^(id<TGMediaEditableItem> editableItem, NSString *caption)
        {
            [editingContext setCaption:caption forItem:editableItem];
            
            if (selectionContext != nil && caption.length > 0 && [editableItem conformsToProtocol:@protocol(TGMediaSelectableItem)])
                [selectionContext setItem:(id<TGMediaSelectableItem>)editableItem selected:true];
        };
        
        model.requestAdjustments = ^id<TGMediaEditAdjustments> (id<TGMediaEditableItem> editableItem)
        {
            return [editingContext adjustmentsForItem:editableItem];
        };
        
        model.interfaceView.usesSimpleLayout = asFile;
        [model.interfaceView updateSelectionInterface:selectionContext.count counterVisible:(selectionContext.count > 0) animated:false];
        model.interfaceView.donePressed = ^(TGMediaPickerGalleryItem *item)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_galleryModel.dismiss(true, false);
            
            if (strongSelf.completeWithItem != nil)
                strongSelf.completeWithItem(item);
        };
        
        modernGallery.model = model;
        modernGallery.itemFocused = ^(TGMediaPickerGalleryItem *item)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.itemFocused != nil)
                strongSelf.itemFocused(item);
        };

        modernGallery.beginTransitionIn = ^UIView *(TGMediaPickerGalleryItem *item, TGModernGalleryItemView *itemView)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            if (strongSelf.willTransitionIn != nil)
                strongSelf.willTransitionIn();
            
            if ([itemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
                [itemView setIsCurrent:true];
            
            if (strongSelf.referenceViewForItem != nil)
                return strongSelf.referenceViewForItem(item);
            
            return nil;
        };
        
        modernGallery.finishedTransitionIn = ^(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_galleryModel.interfaceView setSelectedItemsModel:strongSelf->_galleryModel.selectedItemsModel];
            
            if ([itemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
            {
                if (strongSelf->_galleryController.previewMode)
                    [(TGMediaPickerGalleryVideoItemView *)itemView playIfAvailable];
            }
        };

        modernGallery.beginTransitionOut = ^UIView *(TGMediaPickerGalleryItem *item, TGModernGalleryItemView *itemView)
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (strongSelf.willTransitionOut != nil)
                    strongSelf.willTransitionOut();
                
                if ([itemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
                    [(TGMediaPickerGalleryVideoItemView *)itemView stop];
                
                if (strongSelf.referenceViewForItem != nil)
                    return strongSelf.referenceViewForItem(item);
            }
            return nil;
        };

        modernGallery.completedTransitionOut = ^
        {
            __strong TGMediaPickerModernGalleryMixin *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.didTransitionOut != nil)
                strongSelf.didTransitionOut();
        };
    }
    return self;
}

- (void)present
{
    _galleryModel.editorOpened = self.editorOpened;
    _galleryModel.editorClosed = self.editorClosed;
    
    [_galleryController setPreviewMode:false];
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithParentController:_parentController contentController:_galleryController];
    controllerWindow.hidden = false;
    _galleryController.view.clipsToBounds = true;
    
    _strongGalleryController = nil;
}

- (UIViewController *)galleryController
{
    return _galleryController;
}

- (void)setPreviewMode
{
    _galleryController.previewMode = true;
    _strongGalleryController = nil;
}

- (void)updateWithFetchResult:(TGMediaAssetFetchResult *)fetchResult
{
    TGMediaAsset *currentAsset = ((TGMediaPickerGalleryItem *)_galleryController.currentItem).asset;
    bool exists = ([fetchResult indexOfAsset:currentAsset] != NSNotFound);
    
    if (!exists)
    {
        _galleryModel.dismiss(true, false);
        return;
    }
    
    __block id<TGModernGalleryItem> focusItem = nil;
    NSArray *galleryItems = [self prepareGalleryItemsForFetchResult:fetchResult selectionContext:_galleryModel.selectionContext editingContext:_editingContext asFile:_asFile enumerationBlock:^(TGMediaPickerGalleryItem *item)
    {
        if (focusItem == nil && [item isEqual:_galleryController.currentItem])
            focusItem = item;
    }];
    
    [_galleryModel _replaceItems:galleryItems focusingOnItem:focusItem];
}

- (NSArray *)prepareGalleryItemsForFetchResult:(TGMediaAssetFetchResult *)fetchResult selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext asFile:(bool)asFile enumerationBlock:(void (^)(TGMediaPickerGalleryItem *))enumerationBlock
{
    NSMutableArray *galleryItems = [[NSMutableArray alloc] init];
    
    NSUInteger count = fetchResult.count;
    if (_itemsLimit > 0)
        count = MIN(count, _itemsLimit);
    
    for (NSUInteger i = 0; i < count; i++)
    {
        TGMediaAsset *asset = [fetchResult assetAtIndex:i];
        
        TGMediaPickerGalleryItem *galleryItem = nil;
        switch (asset.type)
        {
            case TGMediaAssetVideoType:
            {
                TGMediaPickerGalleryVideoItem *videoItem = [[TGMediaPickerGalleryVideoItem alloc] initWithAsset:asset];
                videoItem.selectionContext = selectionContext;
                videoItem.editingContext = editingContext;
                
                galleryItem = videoItem;
            }
                break;
                
            case TGMediaAssetGifType:
            {
                TGMediaPickerGalleryGifItem *gifItem = [[TGMediaPickerGalleryGifItem alloc] initWithAsset:asset];
                gifItem.selectionContext = selectionContext;
                gifItem.editingContext = editingContext;
                
                galleryItem = gifItem;
            }
                break;
                
            default:
            {
                TGMediaPickerGalleryPhotoItem *photoItem = [[TGMediaPickerGalleryPhotoItem alloc] initWithAsset:asset];
                photoItem.selectionContext = selectionContext;
                photoItem.editingContext = editingContext;
                
                galleryItem = photoItem;
            }
                break;
        }
        
        if (enumerationBlock != nil)
            enumerationBlock(galleryItem);
        
        galleryItem.asFile = asFile;
        
        if (galleryItem != nil)
            [galleryItems addObject:galleryItem];
    }
    
    return galleryItems;
}

- (NSArray *)prepareGalleryItemsForMomentList:(TGMediaAssetMomentList *)momentList selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext asFile:(bool)asFile enumerationBlock:(void (^)(TGMediaPickerGalleryItem *))enumerationBlock
{
    NSMutableArray *galleryItems = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0; i < momentList.count; i++)
    {
        TGMediaAssetMoment *moment = momentList[i];
        
        for (NSUInteger k = 0; k < moment.assetCount; k++)
        {
            TGMediaAsset *asset = [moment.fetchResult assetAtIndex:k];
            
            TGMediaPickerGalleryItem *galleryItem = nil;
            switch (asset.type)
            {
                case TGMediaAssetVideoType:
                {
                    TGMediaPickerGalleryVideoItem *videoItem = [[TGMediaPickerGalleryVideoItem alloc] initWithAsset:asset];
                    videoItem.selectionContext = selectionContext;
                    videoItem.editingContext = editingContext;
                    
                    galleryItem = videoItem;
                }
                    break;
                    
                case TGMediaAssetGifType:
                {
                    TGMediaPickerGalleryGifItem *gifItem = [[TGMediaPickerGalleryGifItem alloc] initWithAsset:asset];
                    gifItem.selectionContext = selectionContext;
                    gifItem.editingContext = editingContext;
                    
                    galleryItem = gifItem;
                }
                    break;
                    
                default:
                {
                    TGMediaPickerGalleryPhotoItem *photoItem = [[TGMediaPickerGalleryPhotoItem alloc] initWithAsset:asset];
                    photoItem.selectionContext = selectionContext;
                    photoItem.editingContext = editingContext;
                    
                    galleryItem = photoItem;
                }
                    break;
            }
            
            if (enumerationBlock != nil)
                enumerationBlock(galleryItem);
            
            galleryItem.asFile = asFile;
            
            if (galleryItem != nil)
                [galleryItems addObject:galleryItem];
        }
    }
    
    return galleryItems;
}

- (void)setThumbnailSignalForItem:(SSignal *(^)(id))thumbnailSignalForItem
{
    [_galleryModel.interfaceView setThumbnailSignalForItem:thumbnailSignalForItem];
}

- (UIView *)currentReferenceView
{
    if (self.referenceViewForItem != nil)
        return self.referenceViewForItem(_galleryController.currentItem);
    
    return nil;
}

@end
