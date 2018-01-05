/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface NSData (GZip)

- (NSData *)compressGZip;
- (NSData *)decompressGZip;

- (NSData *)compressLZ4;
- (NSData *)decompressLZ4;

@end
