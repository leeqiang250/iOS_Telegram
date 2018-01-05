#import <Foundation/Foundation.h>

#import <LegacyDatabase/lmdb.h>

@interface PSLMDBTable : NSObject

@property (nonatomic, assign) MDB_dbi dbi;

- (instancetype)initWithDbi:(MDB_dbi)dbi;

@end
