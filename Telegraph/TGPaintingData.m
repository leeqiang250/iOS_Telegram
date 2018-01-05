#import "TGPaintingData.h"

#import <SSignalKit/SQueue.h>

#import "TGPaintUtils.h"
#import "TGPhotoPaintStickerEntity.h"

#import "TGMediaEditingContext.h"
#import "TGPaintUndoManager.h"

@interface TGPaintingData ()
{
    UIImage *_image;
    NSData *_data;
    
    UIImage *(^_imageRetrievalBlock)(void);
}
@end

@implementation TGPaintingData

+ (instancetype)dataWithPaintingData:(NSData *)data image:(UIImage *)image entities:(NSArray *)entities undoManager:(TGPaintUndoManager *)undoManager
{
    TGPaintingData *paintingData = [[TGPaintingData alloc] init];
    paintingData->_data = data;
    paintingData->_image = image;
    paintingData->_entities = entities;
    paintingData->_undoManager = undoManager;
    return paintingData;
}

+ (instancetype)dataWithPaintingImagePath:(NSString *)imagePath
{
    TGPaintingData *paintingData = [[TGPaintingData alloc] init];
    paintingData->_imagePath = imagePath;
    return paintingData;
}

+ (void)storePaintingData:(TGPaintingData *)data inContext:(TGMediaEditingContext *)context forItem:(id<TGMediaEditableItem>)item forVideo:(bool)video
{
    [[TGPaintingData queue] dispatch:^
    {
        NSURL *dataUrl = nil;
        NSURL *imageUrl = nil;
        
        NSData *compressedData = TGPaintGZipDeflate(data.data);
        [context setPaintingData:compressedData image:data.image forItem:item dataUrl:&dataUrl imageUrl:&imageUrl forVideo:video];
        
        __weak TGMediaEditingContext *weakContext = context;
        [[SQueue mainQueue] dispatch:^
        {
            data->_dataPath = dataUrl.path;
            data->_imagePath = imageUrl.path;
            data->_data = nil;
            
            data->_imageRetrievalBlock = ^UIImage *
            {
                __strong TGMediaEditingContext *strongContext = weakContext;
                if (strongContext != nil)
                    return [strongContext paintingImageForItem:item];
                
                return nil;
            };
        }];
    }];
}

+ (void)facilitatePaintingData:(TGPaintingData *)data
{
    [[TGPaintingData queue] dispatch:^
    {
        if (data->_imagePath != nil)
            data->_image = nil;
    }];
}

- (void)dealloc
{
    [self.undoManager reset];
}

- (NSData *)data
{
    if (_data != nil)
        return _data;
    else if (_dataPath != nil)
        return TGPaintGZipInflate([[NSData alloc] initWithContentsOfFile:_dataPath]);
    else
        return nil;
}

- (UIImage *)image
{
    if (_image != nil)
        return _image;
    else if (_imageRetrievalBlock != nil)
        return _imageRetrievalBlock();
    else
        return nil;
}

- (NSArray *)stickers
{
    NSMutableSet *stickers = [[NSMutableSet alloc] init];
    for (TGPhotoPaintEntity *entity in self.entities)
    {
        if ([entity isKindOfClass:[TGPhotoPaintStickerEntity class]])
            [stickers addObject:((TGPhotoPaintStickerEntity *)entity).document];
    }
    return [stickers allObjects];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGPaintingData *data = (TGPaintingData *)object;
    return [data.entities isEqual:self.entities] && ((data.data != nil && [data.data isEqualToData:self.data]) || (data.data == nil && self.data == nil));
}

+ (SQueue *)queue
{
    static dispatch_once_t onceToken;
    static SQueue *queue;
    dispatch_once(&onceToken, ^
    {
        queue = [SQueue wrapConcurrentNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)];
    });
    return queue;
}

@end
