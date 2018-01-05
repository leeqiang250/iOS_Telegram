#import "TGLocationSignals.h"

#import <CoreLocation/CoreLocation.h>
#import "thirdparty/AFNetworking/AFHTTPClient.h"

#import "TGRemoteHttpLocationSignal.h"

#import "TGLocationVenue.h"
#import "TGLocationReverseGeocodeResult.h"

NSString *const TGLocationFoursquareSearchEndpointUrl = @"https://api.foursquare.com/v2/venues/search/";
NSString *const TGLocationFoursquareClientId = @"BN3GWQF1OLMLKKQTFL0OADWD1X1WCDNISPPOT1EMMUYZTQV1";
NSString *const TGLocationFoursquareClientSecret = @"WEEZHCKI040UVW2KWW5ZXFAZ0FMMHKQ4HQBWXVSX4WXWBWYN";
NSString *const TGLocationFoursquareVersion = @"20150326";
NSString *const TGLocationFoursquareVenuesCountLimit = @"25";
NSString *const TGLocationFoursquareLocale = @"en";

NSString *const TGLocationGooglePlacesSearchEndpointUrl = @"https://maps.googleapis.com/maps/api/place/nearbysearch/json";
NSString *const TGLocationGooglePlacesApiKey = @"AIzaSyBCTH4aAdvi0MgDGlGNmQAaFS8GTNBrfj4";
NSString *const TGLocationGooglePlacesRadius = @"150";
NSString *const TGLocationGooglePlacesLocale = @"en";

NSString *const TGLocationGoogleGeocodeLocale = @"en";

@interface TGLocationHelper : NSObject <CLLocationManagerDelegate> {
    CLLocationManager *_locationManager;
    void (^_locationDetermined)(CLLocation *);
    bool _startedUpdating;
}

@end

@implementation TGLocationHelper

- (instancetype)initWithLocationDetermined:(void (^)(CLLocation *))locationDetermined {
    self = [super init];
    if (self != nil) {
        _locationDetermined = [locationDetermined copy];
        
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = kCLDistanceFilterNone;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        
        bool startUpdating = false;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            switch ([CLLocationManager authorizationStatus])
            {
                case kCLAuthorizationStatusAuthorizedAlways:
                case kCLAuthorizationStatusAuthorizedWhenInUse:
                    startUpdating = true;
                default:
                    break;
            }
        }
        
        if (startUpdating) {
            [self startUpdating];
        }
    }
    return self;
}

- (void)dealloc {
    [_locationManager stopUpdatingLocation];
}

- (void)startUpdating {
    if (!_startedUpdating) {
        _startedUpdating = true;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            [_locationManager requestWhenInUseAuthorization];
        }
        [_locationManager startUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)__unused manager didUpdateLocations:(NSArray *)locations {
    if (locations.count != 0) {
        if (_locationDetermined) {
            _locationDetermined([locations lastObject]);
        }
    }
}

@end

@implementation TGLocationSignals

+ (SSignal *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
{
    NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true&language=%@", coordinate.latitude, coordinate.longitude, TGLocationGoogleGeocodeLocale]];
    
    return [[TGRemoteHttpLocationSignal jsonForHttpLocation:url.absoluteString] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSArray *results = json[@"results"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;
        
        if (![results.firstObject isKindOfClass:[NSDictionary class]])
            return nil;
        
        return [TGLocationReverseGeocodeResult reverseGeocodeResultWithDictionary:results.firstObject];
    }];
}

+ (SSignal *)searchNearbyPlacesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate service:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return [self _searchGooglePlacesWithQuery:query coordinate:coordinate];
            
        default:
            return [self _searchFoursquareVenuesWithQuery:query coordinate:coordinate];
    }
}

+ (SSignal *)_searchFoursquareVenuesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"limit"] = TGLocationFoursquareVenuesCountLimit;
    parameters[@"ll"] = [NSString stringWithFormat:@"%lf,%lf", coordinate.latitude, coordinate.longitude];
    if (query.length > 0)
        parameters[@"query"] = query;
    
    NSString *url = [self _urlForService:TGLocationPlacesServiceFoursquare parameters:parameters];
    return [[TGRemoteHttpLocationSignal jsonForHttpLocation:url] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;

        NSArray *results = json[@"response"][@"venues"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;

        NSMutableArray *venues = [[NSMutableArray alloc] init];
        for (NSDictionary *result in results)
        {
            TGLocationVenue *venue = [TGLocationVenue venueWithFoursquareDictionary:result];
            if (venue != nil)
                [venues addObject:venue];
        }
        
        return venues;
    }];
}

+ (SSignal *)_searchGooglePlacesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"location"] = [NSString stringWithFormat:@"%lf,%lf", coordinate.latitude, coordinate.longitude];
    if (query.length > 0)
        parameters[@"name"] = query;
    
    NSString *url = [self _urlForService:TGLocationPlacesServiceGooglePlaces parameters:parameters];
    return [[TGRemoteHttpLocationSignal jsonForHttpLocation:url] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSArray *results = json[@"results"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;
        
        NSMutableArray *venues = [[NSMutableArray alloc] init];
        for (NSDictionary *result in results)
        {
            TGLocationVenue *venue = [TGLocationVenue venueWithGooglePlacesDictionary:result];
            if (venue != nil)
                [venues addObject:venue];
        }
        
        return venues;
    }];
}

+ (NSString *)_urlForService:(TGLocationPlacesService)service parameters:(NSDictionary *)parameters
{
    if (service == TGLocationPlacesServiceNone)
        return nil;
    
    NSMutableDictionary *finalParameters = [[self _defaultParametersForService:service] mutableCopy];
    [finalParameters addEntriesFromDictionary:parameters];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", [self _endpointUrlForService:service], AFQueryStringFromParametersWithEncoding(finalParameters, NSUTF8StringEncoding)];
    
    return urlString;
}

+ (NSString *)_endpointUrlForService:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return TGLocationGooglePlacesSearchEndpointUrl;
            
        case TGLocationPlacesServiceFoursquare:
            return TGLocationFoursquareSearchEndpointUrl;
            
        default:
            return nil;
    }
}

+ (NSDictionary *)_defaultParametersForService:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return @
            {
                @"key": TGLocationGooglePlacesApiKey,
                @"language": TGLocationGooglePlacesLocale,
                @"radius": TGLocationGooglePlacesRadius,
                @"sensor": @"true"
            };
            
        case TGLocationPlacesServiceFoursquare:
            return @
            {
                @"v": TGLocationFoursquareVersion,
                @"locale": TGLocationFoursquareLocale,
                @"client_id": TGLocationFoursquareClientId,
                @"client_secret" :TGLocationFoursquareClientSecret
            };
            
        default:
            return nil;
    }
}

#pragma mark -

static CLLocation *lastKnownUserLocation;

+ (void)storeLastKnownUserLocation:(CLLocation *)location
{
    lastKnownUserLocation = location;
}

+ (CLLocation *)lastKnownUserLocation
{
    NSTimeInterval locationAge = -[lastKnownUserLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 600)
        lastKnownUserLocation = nil;
    
    return lastKnownUserLocation;
}

+ (SSignal *)userLocation:(SVariable *)locationRequired {
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        TGLocationHelper *helper = [[TGLocationHelper alloc] initWithLocationDetermined:^(CLLocation *location) {
            [subscriber putNext:location];
        }];
        
        id<SDisposable> requiredDisposable = [[[[locationRequired signal] take:1] deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id next) {
            [helper startUpdating];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^{
            [helper description]; // keep reference
            [requiredDisposable dispose];
        }];
    }] startOn:[SQueue mainQueue]];
}

@end
