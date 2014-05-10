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
#import "StackMob.h"

SPEC_BEGIN(SMDataStoreSpec)

describe(@"Creating a Datastore instance", ^{
    __block SMDataStore *dataStore = nil;
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        dataStore = [[SMDataStore alloc] initWithAPIVersion:@"0" session:[client session]];
    });
    it(@"should get its oauth credentials from the provided oauthClient variable", ^{
        [dataStore.session.regularOAuthClient shouldNotBeNil];
        [[dataStore.session.regularOAuthClient.publicKey should] equal:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        [[dataStore.session.regularOAuthClient.baseURL should] equal:[NSURL URLWithString:@"http://api.stackmob.com"]];
        [[[dataStore.session.regularOAuthClient defaultValueForHeader:@"Accept"] should] equal:@"application/vnd.stackmob+json; version=0"];
    });
    it(@"should have an application API version", ^{
        [[dataStore.apiVersion should] equal:@"0"];
    });
});

describe(@"CRUD", ^{
    __block SMDataStore *dataStore = nil;
    beforeEach(^{
        SMClient *client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        dataStore = [[SMDataStore alloc] initWithAPIVersion:@"0" session:client.session];
        dataStore.session.regularOAuthClient = [SMOAuth2Client nullMock];
    });
    describe(@"-createObject:inSchema:onSuccess:onFailure:", ^{
        __block NSDictionary *objectToCreate = nil;
        beforeEach(^{
            objectToCreate = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"How to Write iOS Applications", @"title",
                              @"A. Developer", @"author",
                              nil];
        });
        context(@"given a valid schema and set of fields", ^{
            it(@"adds the request to the queue", ^{
                //NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://stackmob.com"]];
                //[[dataStore.session.regularOAuthClient should] receive:@selector(requestWithMethod:path:parameters:) andReturn:request];
                
                //AFJSONRequestOperation *operation = [[AFJSONRequestOperation alloc] init];
                //[[[SMJSONRequestOperation should] receiveAndReturn:operation] JSONRequestOperationWithRequest:request success:any() failure:any()];
                
                //[[[dataStore.session.regularOAuthClient should] receive] enqueueHTTPRequestOperation:operation];
                [dataStore createObject:objectToCreate inSchema:@"book" onSuccess:nil onFailure:nil];
            });
        });
        context(@"given a nil object", ^{
            it(@"should fail", ^{
                __block int failureBlockCalled = 0;
                __block int successBlockCalled = 0;
                [dataStore createObject:nil inSchema:@"book" onSuccess:^(NSDictionary *responseObject, NSString *schema){
                    successBlockCalled = 1;
                } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                    [error shouldNotBeNil];
                    __block BOOL equal = NO;
                    if ([error.domain isEqualToString:SMErrorDomain]) {
                        equal = YES;
                    }
                    [[theValue(equal) should] beYes];
                    [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
                    
                    [object shouldBeNil];
                    [[schema should] equal:@"book"];
                    failureBlockCalled = 1;
                }];
                [[theValue(successBlockCalled) should] equal:theValue(0)];
                [[theValue(failureBlockCalled) should] equal:theValue(1)];
            });
        });
        context(@"given a nil schema", ^{
            it(@"should fail", ^{
                __block int failureBlockCalled = 0;
                __block int successBlockCalled = 0;
                [dataStore createObject:objectToCreate inSchema:nil onSuccess:^(NSDictionary *responseObject, NSString *schema){
                    successBlockCalled = 1;
                } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                    [error shouldNotBeNil];
                    [[error.domain should] equal:SMErrorDomain];
                    [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
                    
                    [[object should] equal:objectToCreate];
                    [schema shouldBeNil];
                    failureBlockCalled = 1;
                }];
                [[theValue(successBlockCalled) should] equal:theValue(0)];
                [[theValue(failureBlockCalled) should] equal:theValue(1)];
            });
        });
    });
    describe(@"-readObject:inSchema:withPrimaryKey:onCompletion:", ^{
        context(@"given a valid schema and object id", ^{
            it(@"creates an OAuth signed READ request", ^{
                [[[dataStore.session.regularOAuthClient should] receive] requestWithMethod:@"GET" path:@"book/1234" parameters:nil];
                [dataStore readObjectWithId:@"1234" inSchema:@"book" onSuccess:nil onFailure:nil];
            });
            it(@"adds the request to the queue", ^{
                NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://stackmob.com"]];
                [[dataStore.session.regularOAuthClient should] receive:@selector(requestWithMethod:path:parameters:) andReturn:request];
                
                //AFJSONRequestOperation *operation = [[AFJSONRequestOperation alloc] init];
                //[[[SMJSONRequestOperation should] receiveAndReturn:operation] JSONRequestOperationWithRequest:request success:[KWAny any] failure:[KWAny any]];
                
                //[[[dataStore.session.regularOAuthClient should] receive] enqueueHTTPRequestOperation:operation];
                [dataStore readObjectWithId:@"1234" inSchema:@"book" onSuccess:nil onFailure:nil];
            });
        });
        context(@"given a nil object id", ^{
            it(@"should fail", ^{
                __block int failureBlockCalled = 0;
                __block int successBlockCalled = 0;
                [dataStore readObjectWithId:nil inSchema:@"book" onSuccess:^(NSDictionary *responseObject, NSString *schema){
                    successBlockCalled = 1;
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldNotBeNil];
                    [[error.domain should] equal:SMErrorDomain];
                    [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
                    
                    [objectId shouldBeNil];
                    [[schema should] equal:@"book"];
                    failureBlockCalled = 1;
                }];
                [[theValue(successBlockCalled) should] equal:theValue(0)];
                [[theValue(failureBlockCalled) should] equal:theValue(1)];
            });
        });
        context(@"given a nil schema", ^{
            it(@"should fail", ^{
                __block int failureBlockCalled = 0;
                __block int successBlockCalled = 0;
                [dataStore readObjectWithId:@"1234" inSchema:nil onSuccess:^(NSDictionary *responseObject, NSString *schema){
                    successBlockCalled = 1;
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldNotBeNil];
                    [[error.domain should] equal:SMErrorDomain];
                    [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
                    
                    [[objectId should] equal:@"1234"];
                    [schema shouldBeNil];
                    failureBlockCalled = 1;
                }];
                [[theValue(successBlockCalled) should] equal:theValue(0)];
                [[theValue(failureBlockCalled) should] equal:theValue(1)];
            });
        });
    });
    describe(@"-updateSchema:withFields:result:", ^{
        context(@"given a valid object id and schema", ^{
            __block NSDictionary *updatedFields = nil;
            beforeEach(^{
                updatedFields = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"New and Improved!", @"subtitle",
                                 nil];
            });
            it(@"adds the request to the queue", ^{
                NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://stackmob.com"]];
                [[dataStore.session.regularOAuthClient should] receive:@selector(requestWithMethod:path:parameters:) andReturn:request];
                
                //AFJSONRequestOperation *operation = [[AFJSONRequestOperation alloc] init];
                //[[[SMJSONRequestOperation should] receiveAndReturn:operation] JSONRequestOperationWithRequest:request success:[KWAny any] failure:[KWAny any]];
                
                //[[[dataStore.session.regularOAuthClient should] receive] enqueueHTTPRequestOperation:operation];
                [dataStore updateObjectWithId:@"1234" inSchema:@"book" update:updatedFields onSuccess:nil onFailure:nil];
            });
            context(@"given a nil object id", ^{
                it(@"should fail", ^{
                    __block int failureBlockCalled = 0;
                    __block int successBlockCalled = 0;
                    [dataStore updateObjectWithId:nil inSchema:@"book" update:updatedFields onSuccess:^(NSDictionary *responseObject, NSString *schema){
                        successBlockCalled = 1;
                    } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                        [error shouldNotBeNil];
                        [[error.domain should] equal:SMErrorDomain];
                        [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
                        
                        [[object should] equal:updatedFields];
                        [[schema should] equal:@"book"];
                        failureBlockCalled = 1;
                    }];
                    [[theValue(successBlockCalled) should] equal:theValue(0)];
                    [[theValue(failureBlockCalled) should] equal:theValue(1)];
                });
            });
            context(@"given a nil schema", ^{
                it(@"should fail", ^{
                    __block int failureBlockCalled = 0;
                    __block int successBlockCalled = 0;
                    [dataStore updateObjectWithId:@"1234" inSchema:nil update:updatedFields onSuccess:^(NSDictionary *responseObject, NSString *schema){
                        successBlockCalled = 1;
                    } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                        [error shouldNotBeNil];
                        [[error.domain should] equal:SMErrorDomain];
                        [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
                        
                        [[object should] equal:updatedFields];
                        [schema shouldBeNil];
                        failureBlockCalled = 1;
                    }];
                    [[theValue(successBlockCalled) should] equal:theValue(0)];
                    [[theValue(failureBlockCalled) should] equal:theValue(1)];
                });
            });
        });
    });
    
    describe(@"-deleteSchema:withFields:result:", ^{
        context(@"given a valid schema and object id", ^{
            it(@"creates an OAuth signed DELETE request", ^{
                [[[dataStore.session.regularOAuthClient should] receive] requestWithMethod:@"DELETE" path:@"book/1234" parameters:nil];
                [dataStore deleteObjectId:@"1234" inSchema:@"book" onSuccess:nil onFailure:nil];
            });
            it(@"adds the request to the queue", ^{
                NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://stackmob.com"]];
                [[dataStore.session.regularOAuthClient should] receive:@selector(requestWithMethod:path:parameters:) andReturn:request];
                
                //AFJSONRequestOperation *operation = [[AFJSONRequestOperation alloc] init];
                //[[[SMJSONRequestOperation should] receiveAndReturn:operation] JSONRequestOperationWithRequest:request success:[KWAny any] failure:[KWAny any]];
                
                //[[[dataStore.session.regularOAuthClient should] receive] enqueueHTTPRequestOperation:operation];
                [dataStore deleteObjectId:@"1234" inSchema:@"book" onSuccess:nil onFailure:nil];
            });
        });
        context(@"given a nil object id", ^{
            it(@"should fail", ^{
                __block int failureBlockCalled = 0;
                __block int successBlockCalled = 0;
                [dataStore deleteObjectId:nil inSchema:@"book" onSuccess:^(NSString *objectId, NSString *schema){
                    successBlockCalled = 1;
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldNotBeNil];
                    [[error.domain should] equal:SMErrorDomain];
                    [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
                    
                    [objectId shouldBeNil];
                    [[schema should] equal:@"book"];
                    failureBlockCalled = 1;
                }];
                [[theValue(successBlockCalled) should] equal:theValue(0)];
                [[theValue(failureBlockCalled) should] equal:theValue(1)];
            });
        });
        context(@"given a nil schema", ^{
            it(@"should fail", ^{
                __block int failureBlockCalled = 0;
                __block int successBlockCalled = 0;
                [dataStore deleteObjectId:@"1234" inSchema:nil onSuccess:^(NSString *objectId, NSString *schema){
                    successBlockCalled = 1;
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldNotBeNil];
                    [[error.domain should] equal:SMErrorDomain];
                    [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
                    
                    [[objectId should] equal:@"1234"];
                    [schema shouldBeNil];
                    failureBlockCalled = 1;
                }];
                [[theValue(successBlockCalled) should] equal:theValue(0)];
                [[theValue(failureBlockCalled) should] equal:theValue(1)];
            });
        });
    });
}); 

pending(@"updateAtomicCounter", ^{

});

describe(@"performing queries", ^{
    it(@"should set the request headers", ^{
        
    });
    it(@"should set the request parameters", ^{
    });
    context(@"when successful", ^{
        context(@"when the query returns multiple objects", ^{
            pending(@"passes an array of the resulting objects to the result block", ^{});    
            pending(@"does not pass an error object to the result block", ^{});
        });
        context(@"when the query returns no results", ^{
            pending(@"passes an empty array to the result block", ^{});
            pending(@"does not pass an error object to the result block", ^{});
        });
    });
    context(@"when unsuccessful", ^{
        pending(@"passes a nil array to the result block", ^{});
        pending(@"passes an error object to the result block", ^{});
    });        
});

describe(@"performing counts", ^{
    it(@"should set the request headers", ^{
        
    });
    it(@"should set the request parameters", ^{
    });
    context(@"when successful", ^{
        context(@"when the query returns multiple objects", ^{
            pending(@"passes an array of the resulting objects to the result block", ^{});    
            pending(@"does not pass an error object to the result block", ^{});
        });
        context(@"when the query returns no results", ^{
            pending(@"passes an empty array to the result block", ^{});
            pending(@"does not pass an error object to the result block", ^{});
        });
    });
    context(@"when unsuccessful", ^{
        pending(@"passes a nil array to the result block", ^{});
        pending(@"passes an error object to the result block", ^{});
    });        
});

describe(@"perform custom code request", ^{
    context(@"given a custom code request", ^{
        __block SMCustomCodeRequest *customCodeRequest = nil;
        __block SMClient *client = nil;
        __block SMDataStore *dataStore = nil;
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
            dataStore = [[SMDataStore alloc] initWithAPIVersion:@"0" session:[client session]];
            customCodeRequest = [[SMCustomCodeRequest alloc] initPostRequestWithMethod:@"method" body:@"body"];
        });
        it(@"should perform the request", ^{
            [[dataStore.session.regularOAuthClient should] receive:@selector(customCodeRequest:options:)];
            [[dataStore should] receive:@selector(queueCustomCodeRequest:customCodeRequestInstance:options:successCallbackQueue:failureCallbackQueue:onSuccess:onFailure:)];
            [dataStore performCustomCodeRequest:customCodeRequest onSuccess:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                
            } onFailure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                
            }];
        });
    });
});



SPEC_END
