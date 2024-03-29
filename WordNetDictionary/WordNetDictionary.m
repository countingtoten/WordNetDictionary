//
//  WordNetDictionary.m
//  WordNetDictionary
//
//  Created by James Weinert on 12/8/12.
//  Copyright (c) 2012 James Weinert. All rights reserved.
//


#import "WordNetDictionary.h"

#import "FMDatabase.h"

@interface WordNetDictionary ()
@property (readonly, strong, nonatomic) FMDatabase *db;
- (NSString *)applicationDocumentsDirectory;
@end

@implementation WordNetDictionary
@synthesize db = __db;

+ (WordNetDictionary *)sharedInstance {
    static dispatch_once_t onceToken;
    static WordNetDictionary *dictionary = nil;
    
    dispatch_once(&onceToken, ^{
        dictionary = [[WordNetDictionary alloc] init];
    });
    
    return dictionary;
}

- (void)dealloc {
    if (self.db != nil) {
        [self.db close];
    }
}

#pragma mark - Search

- (NSArray *)searchForWord:(NSString *)searchText {
    return [self searchForWord:searchText withLimit:50];
}

- (NSArray *)searchForWord:(NSString *)searchText withLimit:(NSUInteger)limit {
    NSString *searchTextTrimmed = [searchText stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    searchTextTrimmed = [searchTextTrimmed stringByReplacingOccurrencesOfString:@"\"" withString:@" "];
    if ([searchTextTrimmed isEqualToString:@""]) {
        return nil;
    }
    
    NSMutableArray *dbResults = [NSMutableArray array];
    FMResultSet *fineResults = [self.db executeQuery:@"SELECT lemma FROM words WHERE lemma MATCH ? LIMIT ?;", searchTextTrimmed, [NSNumber numberWithUnsignedInteger:limit]];
    
    while ([fineResults next]) {
        [dbResults addObject:[fineResults stringForColumn:@"lemma"]];
    }
    
    if ([dbResults count] < limit) {
        FMResultSet *broadResults = [self.db executeQuery:@"SELECT lemma FROM words WHERE lemma MATCH ? LIMIT ?;", [NSString stringWithFormat:@"%@*", searchTextTrimmed], [NSNumber numberWithUnsignedInteger:(limit - [dbResults count])]];
        
        while ([broadResults next]) {
            [dbResults addObject:[broadResults stringForColumn:@"lemma"]];
        }
    }
    
    if ([dbResults count] < limit) {
        FMResultSet *broadestResults = [self.db executeQuery:@"SELECT lemma FROM words WHERE lemma MATCH ? LIMIT ?;", [NSString stringWithFormat:@"*%@*", searchTextTrimmed], [NSNumber numberWithUnsignedInteger:(limit - [dbResults count])]];
        
        while ([broadestResults next]) {
            [dbResults addObject:[broadestResults stringForColumn:@"lemma"]];
        }
    }
    
    NSMutableArray *fineSearchArray = [NSMutableArray arrayWithArray:dbResults];
    NSString *fineSearchRegex = [NSString stringWithFormat:@"SELF like[cd] \"%@\"", searchTextTrimmed];
    NSPredicate *fineSearchPred = [NSPredicate predicateWithFormat:fineSearchRegex];
    [fineSearchArray filterUsingPredicate:fineSearchPred];
    
    NSMutableArray *broadSearchArray = [NSMutableArray arrayWithArray:dbResults];
    NSString *broadSearchRegex = [NSString stringWithFormat:@"SELF beginswith[cd] \"%@\"", searchTextTrimmed];
    NSPredicate *broadSearchPred = [NSPredicate predicateWithFormat:broadSearchRegex];
    [broadSearchArray filterUsingPredicate:broadSearchPred];
    
    NSMutableOrderedSet *wordsArray = [NSMutableOrderedSet orderedSetWithCapacity:limit];
    [wordsArray addObjectsFromArray:fineSearchArray];
    [wordsArray addObjectsFromArray:broadSearchArray];
    [wordsArray addObjectsFromArray:dbResults];
    
    return [wordsArray array];
}

#pragma mark - Define

- (NSDictionary *)defineWord:(NSString *)wordToDefine {
    NSString *wordToDefineTrimmed = [wordToDefine stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    wordToDefineTrimmed = [wordToDefineTrimmed stringByReplacingOccurrencesOfString:@"\"" withString:@" "];
    
    FMResultSet *wordSearchResults = [self.db executeQuery:@"SELECT * FROM words WHERE lemma MATCH ?;", wordToDefineTrimmed];

    int wordid = 0;
    while ([wordSearchResults next]) {
        if ([[wordSearchResults stringForColumn:@"lemma"] isEqualToString:wordToDefine]) {
            wordid = [wordSearchResults intForColumn:@"wordid"];
            break;
        }
    }

    FMResultSet *linkResults = [self.db executeQuery:@"SELECT synsetkey FROM links WHERE wordkey = ?", [NSNumber numberWithInt:wordid]];
    
    NSMutableArray *synsetidInOrder = [NSMutableArray array];
    while ([linkResults next]) {
        [synsetidInOrder addObject:[linkResults stringForColumn:@"synsetkey"]];
    }
    
    NSMutableDictionary *definitionsDictionary = [NSMutableDictionary dictionary];
    for (NSString *synsetid in synsetidInOrder) {
        FMResultSet *definitionResults = [self.db executeQuery:@"SELECT definition, partofspeech FROM synsets WHERE synsetid = ?;", synsetid];
        
        while ([definitionResults next]) {
            NSString *definition = [definitionResults stringForColumn:@"definition"];
            int partOfSpeech = [definitionResults intForColumn:@"partofspeech"];
            
            switch (partOfSpeech) {
                case WordNetNoun:
                {
                    NSMutableArray *nounArray = [definitionsDictionary objectForKey:@"noun"];
                    if (nounArray) {
                        [nounArray addObject:definition];
                    } else {
                        nounArray = [NSMutableArray arrayWithObject:definition];
                    }
                    
                    [definitionsDictionary setObject:nounArray forKey:@"noun"];
                    break;
                }
                case WordNetVerb:
                {
                    NSMutableArray *verbArray = [definitionsDictionary objectForKey:@"verb"];
                    if (verbArray) {
                        [verbArray addObject:definition];
                    } else {
                        verbArray = [NSMutableArray arrayWithObject:definition];
                    }
                    
                    [definitionsDictionary setObject:verbArray forKey:@"verb"];
                    break;
                }
                case WordNetAdjective:
                {
                    NSMutableArray *adjectiveArray = [definitionsDictionary objectForKey:@"adjective"];
                    if (adjectiveArray) {
                        [adjectiveArray addObject:definition];
                    } else {
                        adjectiveArray = [NSMutableArray arrayWithObject:definition];
                    }
                    
                    [definitionsDictionary setObject:adjectiveArray forKey:@"adjective"];
                    break;
                }
                case WordNetAdverb:
                {
                    NSMutableArray *adverbArray = [definitionsDictionary objectForKey:@"adverb"];
                    if (adverbArray) {
                        [adverbArray addObject:definition];
                    } else {
                        adverbArray = [NSMutableArray arrayWithObject:definition];
                    }
                    
                    [definitionsDictionary setObject:adverbArray forKey:@"adverb"];
                    break;
                }
            }
        }
    }
    
    return definitionsDictionary;
}

- (NSArray *)randomWords:(NSUInteger)limit {
    NSMutableArray *dbResults = [NSMutableArray array];
    FMResultSet *fineResults = [self.db executeQuery:@"SELECT lemma FROM words ORDER BY RANDOM() LIMIT ?;", [NSNumber numberWithUnsignedInteger:limit]];
    
    while ([fineResults next]) {
        [dbResults addObject:[fineResults stringForColumn:@"lemma"]];
    }
    
    return dbResults;
}

- (FMDatabase *)db {
    if (__db != nil) {
        return __db;
    }
    
    __db = [FMDatabase databaseWithPath:[[NSBundle mainBundle] pathForResource:@"WordNetDictionary" ofType:@"sqlite"]];
    [__db open];
    //__db.traceExecution = YES;
    
    return __db;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSString *)applicationDocumentsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

@end
