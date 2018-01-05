#import "TGLocationVenue.h"

#import "TGLocationMediaAttachment.h"

NSString *const TGLocationGooglePlacesVenueProvider = @"google";
NSString *const TGLocationFoursquareVenueProvider = @"foursquare";

@interface TGLocationVenue ()
{
    NSString *_displayAddress;
}
@end

@implementation TGLocationVenue

+ (TGLocationVenue *)venueWithFoursquareDictionary:(NSDictionary *)dictionary
{
    TGLocationVenue *venue = [[TGLocationVenue alloc] init];
    venue->_identifier = dictionary[@"id"];
    venue->_name = dictionary[@"name"];
    
    NSDictionary *location = dictionary[@"location"];
    venue->_coordinate = CLLocationCoordinate2DMake([location[@"lat"] doubleValue], [location[@"lng"] doubleValue]);
    
    NSArray *categories = dictionary[@"categories"];
    if (categories.count > 0)
    {
        NSDictionary *category = categories.firstObject;
        venue->_categoryName = category[@"name"];
        
        NSDictionary *icon = category[@"icon"];
        if (icon != nil)
            venue->_categoryIconUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@64%@", icon[@"prefix"], icon[@"suffix"]]];
    }
    
    
    
    venue->_country = location[@"country"];
    venue->_state = location[@"state"];
    venue->_city = location[@"city"];
    venue->_address = location[@"address"];
    venue->_crossStreet = location[@"crossStreet"];
    
    venue->_provider = TGLocationFoursquareVenueProvider;
    
    return venue;
}

+ (TGLocationVenue *)venueWithGooglePlacesDictionary:(NSDictionary *)dictionary
{
    TGLocationVenue *venue = [[TGLocationVenue alloc] init];
    venue->_identifier = dictionary[@"place_id"];
    venue->_name = dictionary[@"name"];
    
    NSDictionary *location = dictionary[@"geometry"][@"location"];
    venue->_coordinate = CLLocationCoordinate2DMake([location[@"lat"] doubleValue],
                                                    [location[@"lng"] doubleValue]);
    
    NSArray *types = dictionary[@"types"];
    if (types.count > 0)
    {
        if ([types containsObject:@"political"])
            return nil;
        
        venue->_categoryName = types.firstObject;
    }
    
    venue->_displayAddress = dictionary[@"vicinity"];
    
    venue->_provider = TGLocationGooglePlacesVenueProvider;
    
    return venue;
}

- (NSString *)displayAddress
{
    if (_displayAddress.length > 0)
        return _displayAddress;
    if (self.street.length > 0)
        return self.street;
    else if (self.city.length > 0)
        return self.city;
    else if (self.country.length > 0)
        return self.country;
    
    return nil;
}

- (NSString *)street
{
    if (self.address.length > 0)
        return self.address;
    else
        return self.crossStreet;
}

- (TGVenueAttachment *)venueAttachment
{
    return [[TGVenueAttachment alloc] initWithTitle:self.name address:self.displayAddress provider:self.provider venueId:self.identifier];
}

@end
