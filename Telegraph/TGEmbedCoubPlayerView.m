#import "TGEmbedCoubPlayerView.h"
#import "TGEmbedPlayerState.h"

#import "TGAppDelegate.h"

#import "TGMediaAssetImageSignals.h"
#import "TGPreparedLocalDocumentMessage.h"

#import <SSignalKit/SSignalKit.h>
#import "TGRemoteHttpLocationSignal.h"

#import "CBPlayerView.h"
#import "CBCoubAsset.h"
#import "CBCoubPlayer.h"
#import "CBCoubNew.h"

#import "PSLMDBKeyValueStore.h"

@interface TGEmbedCoubPlayerView () <CBCoubPlayerDelegate>
{
    NSString *_permalink;
    
    bool _started;
    UIImage *_coverImage;
    
    CBPlayerView *_playerView;
    CBCoubPlayer *_coubPlayer;
    
    SDisposableSet *_disposables;
    
    id<CBCoubAsset> _asset;
}
@end

@implementation TGEmbedCoubPlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal
{
    self = [super initWithWebPageAttachment:webPage thumbnailSignal:thumbnailSignal];
    if (self != nil)
    {
        _permalink = [TGEmbedCoubPlayerView _coubVideoIdFromText:webPage.embedUrl];
        _disposables = [[SDisposableSet alloc] init];
        
        if (thumbnailSignal == nil)
        {
            TGDocumentMediaAttachment *document = webPage.document;
            NSString *videoPath = nil;
            if ([document.mimeType isEqualToString:@"video/mp4"])
            {
                if (document.localDocumentId != 0) {
                    videoPath = [[TGPreparedLocalDocumentMessage localDocumentDirectoryForLocalDocumentId:document.localDocumentId version:document.version] stringByAppendingPathComponent:[document safeFileName]];
                } else {
                    videoPath = [[TGPreparedLocalDocumentMessage localDocumentDirectoryForDocumentId:document.documentId version:document.version] stringByAppendingPathComponent:[document safeFileName]];
                }
            }
            
            if (videoPath != nil && [[NSFileManager defaultManager] fileExistsAtPath:videoPath isDirectory:NULL])
            {
                __weak TGEmbedCoubPlayerView *weakSelf = self;
                [_disposables add:[[[TGMediaAssetImageSignals videoThumbnailForAVAsset:[AVURLAsset assetWithURL:[NSURL fileURLWithPath:videoPath]] size:CGSizeMake(480, 480) timestamp:CMTimeMake(1, 100)] deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
                {
                    __strong TGEmbedCoubPlayerView *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if ([next isKindOfClass:[UIImage class]])
                        [strongSelf setCoverImage:next];
                }]];
            }
        }
        
        self.controlsView.watermarkImage = [UIImage imageNamed:@"CoubWatermark"];
        self.controlsView.watermarkOffset = CGPointMake(12.0f, 12.0f);
    }
    return self;
}

- (void)dealloc
{
    [_disposables dispose];
}

- (bool)supportsPIP
{
    return false;
}

- (void)_watermarkAction
{
    [super _watermarkAction];
    
    NSString *permalink =  _permalink;
    NSString *coubId = nil;
    if ([_asset isKindOfClass:[CBCoubNew class]])
        coubId = ((CBCoubNew *)_asset).coubID;
    
    NSURL *appUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"coub://view/%@", coubId]];
    
    if ([[UIApplication sharedApplication] canOpenURL:appUrl])
    {
        [[UIApplication sharedApplication] openURL:appUrl];
        return;
    }
    
    NSURL *webUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://coub.com/view/%@", permalink]];
    [[UIApplication sharedApplication] openURL:webUrl];
}

- (void)setupWithEmbedSize:(CGSize)embedSize
{
    [super setupWithEmbedSize:embedSize];
    
    _playerView = [[CBPlayerView alloc] initWithFrame:[self _webView].bounds];
    [[self _webView].superview insertSubview:_playerView aboveSubview:[self _webView]];
    
    _coubPlayer = [[CBCoubPlayer alloc] initWithVideoLayer:(AVPlayerLayer *)_playerView.videoPlayerView.layer];
    _coubPlayer.withoutAudio = false;
    _coubPlayer.delegate = self;
    
    [self _cleanWebView];
    
    [self setDimmed:true animated:false shouldDelay:false];
    [self initializePlayer];
    
    [self setLoadProgress:0.01f duration:0.01];
}

- (void)playVideo
{
    [_coubPlayer resume];
}

- (void)pauseVideo:(bool)manually
{
    [super pauseVideo:manually];
    [_coubPlayer pause];
}


- (void)_onPageReady
{
    
}

- (void)_didBeginPlayback
{
    [super _didBeginPlayback];
    
    [self setDimmed:false animated:true shouldDelay:false];
}

- (TGEmbedPlayerControlsType)_controlsType
{
    return TGEmbedPlayerControlsTypeSimple;
}

- (NSString *)_embedHTML
{
    NSError *error = nil;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"DefaultPlayer" ofType:@"html"];
    
    NSString *embedHTMLTemplate = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        TGLog(@"[CoubEmbedPlayer]: Received error rendering template: %@", error);
        return nil;
    }
    
    NSString *embedHTML = [NSString stringWithFormat:embedHTMLTemplate, @"about:blank"];
    return embedHTML;
}

- (NSURL *)_baseURL
{
    return [NSURL URLWithString:@"https://coub.com/"];
}

#pragma mark - 

- (bool)_useFakeLoadingProgress
{
    return false;
}

- (void)initializePlayer
{
    NSString *url = [NSString stringWithFormat:@"http://coub.com/api/v2/coubs/%@", _permalink];
    
    __weak TGEmbedCoubPlayerView *weakSelf = self;
    SSignal *cachedSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        __strong TGEmbedCoubPlayerView *strongSelf = weakSelf;
        if (strongSelf == nil)
        {
            [subscriber putCompletion];
            return nil;
        }
        
        NSDictionary *json = [TGEmbedCoubPlayerView coubJSONByPermalink:strongSelf->_permalink];
        if (json != nil)
        {
            [subscriber putNext:json];
            [subscriber putCompletion];
        }
        else
        {
            [subscriber putError:nil];
        }
        
        return nil;
    }];
    
    SSignal *dataSignal = [[cachedSignal mapToSignal:^SSignal *(NSDictionary *json)
    {
        return [[SSignal single:@{ @"json": json, @"cached": @true }] delay:0.2 onQueue:[SQueue mainQueue]];
    }] catch:^SSignal *(__unused id error)
    {
        return [[TGRemoteHttpLocationSignal jsonForHttpLocation:url] map:^id(NSDictionary *json)
        {
            return @{ @"json": json, @"cached": @false };
        }];
    }];
    
    [_disposables add:[[dataSignal deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *data)
    {
        __strong TGEmbedCoubPlayerView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        id<CBCoubAsset> coub = [CBCoubNew coubWithAttributes:data[@"json"]];
        strongSelf->_asset = coub;
        
        if ([coub isKindOfClass:[CBCoubNew class]])
        {
            CBCoubNew *coubNew = (CBCoubNew *)coub;
            if (strongSelf.onMetadataLoaded != nil)
                strongSelf.onMetadataLoaded(coubNew.title, coubNew.author.name);
        }
        
        [strongSelf->_coubPlayer playAsset:strongSelf->_asset];
        
        if (![data[@"cached"] boolValue])
            [TGEmbedCoubPlayerView setCoubJSON:data[@"json"] forPermalink:strongSelf->_permalink];
    }]];
}

- (void)playerReadyToPlay:(CBCoubPlayer *)__unused player
{
    [self setLoadProgress:1.0f duration:0.2];
    [_playerView play];
    
    if (self.onRealLoadProgress != nil)
        self.onRealLoadProgress(1.0f, 0.2);
}

- (void)playerDidStartPlaying:(CBCoubPlayer *)__unused player
{
    if (!_started)
    {
        _started = true;
        [self _didBeginPlayback];
        
        TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true];
        [self updateState:state];
    }
}

- (void)player:(CBCoubPlayer *)__unused player didReachProgressWhileDownloading:(float)progress
{
    [self setLoadProgress:progress duration:0.3];
    
    if (self.onRealLoadProgress != nil)
        self.onRealLoadProgress(progress, 0.3);
}

- (void)playerDidPause:(CBCoubPlayer *)__unused player withUserAction:(BOOL)isUserAction
{
    if (!isUserAction)
        return;
    
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:false];
    [self updateState:state];
}

- (void)playerDidResume:(CBCoubPlayer *)__unused player
{
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true];
    [self updateState:state];
}

- (void)playerDidFail:(CBCoubPlayer *)__unused player error:(NSError *)error
{
    TGLog(@"[CoubPlayer] ERROR: %@", error.localizedDescription);
}

- (void)playerDidStop:(CBCoubPlayer *)__unused player
{
    
}

#pragma mark -

+ (NSString *)_coubVideoIdFromText:(NSString *)text
{
    NSMutableArray *prefixes = [NSMutableArray arrayWithArray:@
    [
        @"http://coub.com/v/",
        @"https://coub.com/v/",
        @"http://coub.com/embed/",
        @"https://coub.com/embed/",
        @"http://coub.com/view/",
        @"https://coub.com/view/" 
    ]];
    
    NSString *prefix = nil;
    for (NSString *p in prefixes)
    {
        if ([text hasPrefix:p])
        {
            prefix = p;
            break;
        }
    }
    
    if (prefix != nil)
    {
        NSString *suffix = [text substringFromIndex:prefix.length];
        
        for (int i = 0; i < (int)suffix.length; i++)
        {
            unichar c = [suffix characterAtIndex:i];
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '=' || c == '&' || c == '#'))
                return nil;
        }
        
        return suffix;
    }
    
    return nil;
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSString *url = webPage.embedUrl;
    return ([url hasPrefix:@"http://coub.com/embed/"] || [url hasPrefix:@"https://coub.com/embed/"]);
}

+ (PSLMDBKeyValueStore *)coubMetaStore
{
    static PSLMDBKeyValueStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *documentsPath = [TGAppDelegate documentsPath];
        store = [PSLMDBKeyValueStore storeWithPath:[documentsPath stringByAppendingPathComponent:@"misc/coubmetadata"] size:1 * 1024 * 1024];
    });
    return store;
}

+ (NSDictionary *)coubJSONByPermalink:(NSString *)permalink
{
    if (permalink.length == 0)
        return nil;
    
    __block NSData *jsonData = nil;
    [[self coubMetaStore] readInTransaction:^(id<PSKeyValueReader> reader)
    {
        NSMutableData *keyData = [[NSMutableData alloc] init];
        int8_t keyspace = 0;
        [keyData appendBytes:&keyspace length:1];
        [keyData appendData:[permalink dataUsingEncoding:NSUTF8StringEncoding]];
        PSData key = {.data = (uint8_t *)keyData.bytes, .length = keyData.length};
        PSData value;
        if ([reader readValueForRawKey:&key value:&value])
            jsonData = [[NSData alloc] initWithBytes:value.data length:value.length];
    }];
    
    if (jsonData.length > 0)
    {
        @try
        {
            NSDictionary *json = [NSKeyedUnarchiver unarchiveObjectWithData:jsonData];
            return json;
        }
        @catch(NSException *)
        {
        }
    }
    
    return nil;
}

+ (void)setCoubJSON:(NSDictionary *)json forPermalink:(NSString *)permalink
{
    if (permalink.length == 0 || json.allKeys.count == 0)
        return;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:json];
    if (data.length == 0)
        return;
    
    [[self coubMetaStore] readWriteInTransaction:^(id<PSKeyValueReader,PSKeyValueWriter> writer)
    {
        NSMutableData *keyData = [[NSMutableData alloc] init];
        int8_t keyspace = 0;
        [keyData appendBytes:&keyspace length:1];
        [keyData appendData:[permalink dataUsingEncoding:NSUTF8StringEncoding]];
        PSData key = {.data = (uint8_t *)keyData.bytes, .length = keyData.length};
        PSData value = {.data = (uint8_t *)data.bytes, .length = data.length};
        [writer writeValueForRawKey:key.data keyLength:key.length value:value.data valueLength:value.length];
    }];
}

@end
