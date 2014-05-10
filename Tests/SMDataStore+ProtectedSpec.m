/**
 * Copyright 2012-2013 StackMob
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Kiwi/Kiwi.h>
#import "SMClient.h"
#import "SMDataStore+Protected.h"

SPEC_BEGIN(SMDataStore_CompletionBlocksSpec)
__block SMDataStore *dataStore = nil;
beforeEach(^{
    SMClient *client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
    dataStore = [[SMDataStore alloc] initWithAPIVersion:@"0" session:[client session]]; 
});

describe(@"SMFullResponseSuccessBlockForSchema:withSuccessBlock:", ^{
    it(@"returns a block which calls the success block with appropriate arguments", ^{
        NSDictionary *responseObject = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @"The Great American Novel", @"name", 
                                        @"Yours Truely", @"author",
                                        @"1234", @"book_id", 
                                        nil];
        NSURL *url = [NSURL URLWithString:@"http://mob1.stackmob.com/books/1234"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
        
        __block int completionBlockDidExecute = 0;
        SMDataStoreSuccessBlock successBlock = ^(NSDictionary* object, NSString *schema) {
            [[schema should] equal:@"book"];
            [[object should] equal:responseObject];
            completionBlockDidExecute = 1;
        };
        
        SMFullResponseSuccessBlock success = [dataStore SMFullResponseSuccessBlockForSchema:@"book" withSuccessBlock:successBlock];
        success(request, response, responseObject);
        
        [[theValue(completionBlockDidExecute) should] equal:theValue(1)];
    });
});

describe(@"-SMFullResponseFailureBlockForObject:ofSchema:withFailureBlock:", ^{
    it(@"returns a block which calls the failure block with appropriate arguments", ^{
        NSDictionary *requestObject = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @"1234", @"book_id", 
                                        nil];
        NSURL *url = [NSURL URLWithString:@"http://mob1.stackmob.com/books/1234"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
        
        __block int completionBlockDidExecute = 0;
        SMDataStoreFailureBlock failureBlock = ^(NSError *error, NSDictionary* object, NSString *schema) {
            [[schema should] equal:@"book"];
            [[object should] equal:requestObject];
            completionBlockDidExecute = 1;
        };
        
        SMFullResponseFailureBlock failure = [dataStore SMFullResponseFailureBlockForObject:requestObject ofSchema:@"book" withFailureBlock:failureBlock];
        NSError *error = [NSError errorWithDomain:@"com.stackmob" code:0 userInfo:nil];
        failure(request, response, error, nil);
        
        [[theValue(completionBlockDidExecute) should] equal:theValue(1)];
    });
});

describe(@"countFromRangeHeader", ^{
    it(@"should return 0 given a nil rangeHeader and an empty array", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:nil results:[NSArray array]]] should] equal:[NSNumber numberWithInt:0]];
    });
    it(@"should return 1 given a nil rangeHeader and an array of size 1", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:nil results:[NSArray arrayWithObject:@"foo"]]] should] equal:[NSNumber numberWithInt:1]];
    });
    it(@"should return 3 given a nil rangeHeader and an array of size 3", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:nil results:[NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil]]] should] equal:[NSNumber numberWithInt:3]];
    });
    it(@"should return -1 given a gibberish rangeHeader", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:@"xfkvhf89olhlwa3s3nku921k," results:nil]] should] equal:[NSNumber numberWithInt:-1]];
    });
    it(@"should return -1 given a rangeHeader with too many bits", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:@"1-1/5/4," results:nil]] should] equal:[NSNumber numberWithInt:-1]];
    });
    it(@"should return -2 given a rangeHeader with a star", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:@"1-1/*," results:nil]] should] equal:[NSNumber numberWithInt:-1]];
    });
    it(@"should return 637 given a rangeHeader with that number in the count position", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:@"1-1/637," results:nil]] should] equal:[NSNumber numberWithInt:637]];
    });
});

SPEC_END
