#import "NSArray_SchemeParam.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation NSArray_SchemeParam


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x7f3dd14a;
}

- (int32_t)TLconstructorName
{
    TGLog(@"constructorName is not implemented for base type");
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::shared_ptr<TLMetaObject>)__unused metaObject
{
    TGLog(@"TLbuildFromMetaObject is not implemented for base type");
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
    TGLog(@"TLfillFieldsWithValues is not implemented for base type");
}

- (id)TLvectorConstruct
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array TLtagConstructorName:(int32_t)0x7f3dd14a];
    return array;
}


@end

