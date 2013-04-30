//
//  WordNetDictionary.h
//  WordNetDictionary
//
//  Created by James Weinert on 12/8/12.
//  Copyright (c) 2012 James Weinert. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, WordNetPartOfSpeech) {
    WordNetNoun,
    WordNetVerb,
    WordNetAdjective,
    WordNetAdjectiveSatellite,
    WordNetAdverb
};

@interface WordNetDictionary : NSObject

+ (WordNetDictionary *)sharedInstance;

// Returns
- (NSArray *)searchForWord:(NSString *)searchText;
- (NSArray *)searchForWord:(NSString *)searchText withLimit:(NSUInteger)limit;

// Returns a dictionary of definitions. The keys are the part of speech and can be
// @"noun", @"verb", @"adjective", or @"adverb"
- (NSDictionary *)defineWord:(NSString *)wordToDefine;

- (NSArray *)randomWords:(NSUInteger)limit;

@end
