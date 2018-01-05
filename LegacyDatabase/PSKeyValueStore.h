#import <LegacyDatabase/PSKeyValueReader.h>
#import <LegacyDatabase/PSKeyValueWriter.h>

@protocol PSKeyValueStore <NSObject>

- (void)readInTransaction:(void (^)(id<PSKeyValueReader>))transaction;
- (void)readWriteInTransaction:(void (^)(id<PSKeyValueReader, PSKeyValueWriter>))transaction;

- (void)sync;

@end
