/*
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
#import "SMNetworkReachabilityHelper.h"
#import "SMIntegrationTestHelpers.h"

SPEC_BEGIN(RelationshipsSpec)

describe(@"Create objects", ^{
    __block SMDataStore *dataStore;
    beforeAll(^{
        dataStore = [SMIntegrationTestHelpers dataStore];
    });
    afterAll(^{
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        __block NSArray *todos = nil;
        
        SMQuery *todoQuery = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [dataStore performQuery:todoQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            todos = results;
            [todos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"todo_id"] inSchema:@"todo" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dataStore = nil;
        
        sleep(SLEEP_TIME);
    });
    it(@"creates multiple objects at once", ^{
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        __block NSMutableArray *todos = [NSMutableArray array];
        for (int i = 0; i < 5; i++) {
            [todos addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"title", @"title", nil]];
        }
        
        dispatch_group_enter(group);
        [dataStore createObjects:todos inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            [[succeeded should] haveCountOf:5];
            [[failed should] haveCountOf:0];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSArray *objects, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        SMQuery *todosQuery = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [dataStore performCount:todosQuery options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSNumber *count) {
            [[count should] equal:theValue(5)];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    it(@"fails when objects are nil", ^{
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [dataStore createObjects:nil inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSArray *objects, NSString *schema) {
            [error shouldNotBeNil];
            [[theValue([error code]) should] equal:theValue(SMErrorInvalidArguments)];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
    });
    it(@"fails when schema is nil", ^{
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        __block NSMutableArray *todos = [NSMutableArray array];
        for (int i = 0; i < 5; i++) {
            [todos addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"title", @"title", nil]];
        }
        
        dispatch_group_enter(group);
        [dataStore createObjects:todos inSchema:nil options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSArray *objects, NSString *schema) {
            [error shouldNotBeNil];
            [[theValue([error code]) should] equal:theValue(SMErrorInvalidArguments)];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
    });
});

describe(@"Upsert", ^{
    __block SMDataStore *dataStore;
    beforeAll(^{
        dataStore = [SMIntegrationTestHelpers dataStore];
    });
    afterAll(^{
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        __block NSArray *todos = nil;
        __block NSArray *categories = nil;
        __block NSArray *favorites = nil;
        
        SMQuery *todoQuery = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [dataStore performQuery:todoQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            todos = results;
            [todos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"todo_id"] inSchema:@"todo" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        SMQuery *categoryQuery = [[SMQuery alloc] initWithSchema:@"category"];
        dispatch_group_enter(group);
        [dataStore performQuery:categoryQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            categories = results;
            [categories enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"category_id"] inSchema:@"category" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        SMQuery *favoriteQuery = [[SMQuery alloc] initWithSchema:@"favorite"];
        dispatch_group_enter(group);
        [dataStore performQuery:favoriteQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            favorites = results;
            [favorites enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"favorite_id"] inSchema:@"favorite" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dataStore = nil;
        
        sleep(SLEEP_TIME);
    });
    it(@"Create new todo and category", ^{
        // Create category object. We can specify a manual primary key if we wish, otherwise one will be automatically assigned when it's created.
        NSDictionary *categoryObject = [NSDictionary dictionaryWithObjectsAndKeys:@"Home Projects", @"name", nil];
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", categoryObject, @"category", nil];
        
        // Correlate the key "category" to the StackMob "category" schema
        SMRequestOptions *options = [SMRequestOptions options];
        [options associateKey:@"category" withSchema:@"category"];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            // Result will contain the entire todo object, as well as the entire nested category object.
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
    });
    it(@"Create new todo and category with existing headers", ^{
        
        // Create category object. We can specify a manual primary key if we wish, otherwise one will be automatically assigned when it's created.
        NSDictionary *categoryObject = [NSDictionary dictionaryWithObjectsAndKeys:@"Home Projects", @"name", nil];
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", categoryObject, @"category", nil];
        
        // Correlate the key "category" to the StackMob "category" schema
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"something", @"someheader", nil]];
        [options associateKey:@"category" withSchema:@"category"];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            // Result will contain the entire todo object, as well as the entire nested category object.
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
    });
    it(@"Create new todo and update existing category", ^{
        // Create category object. We can specify a manual primary key if we wish, otherwise one will be automatically assigned when it's created.
        NSDictionary *categoryObject = [NSDictionary dictionaryWithObjectsAndKeys:@"Home Projects", @"name", @"1234", @"genre", nil];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        __block NSString *categoryId = nil;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:categoryObject inSchema:@"category" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            categoryId = [object valueForKey:@"category_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            NSDictionary *categoryUpdate = [NSDictionary dictionaryWithObjectsAndKeys:@"Updated Name", @"name", categoryId, @"category_id", nil];
            
            NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", categoryUpdate, @"category", nil];
            
            // Correlate the key "category" to the StackMob "category" schema
            SMRequestOptions *options = [SMRequestOptions options];
            [options associateKey:@"category" withSchema:@"category"];
            
            success = NO;
            timeout = YES;
            
            dispatch_group_enter(group);
            // Execute request
            [dataStore createObject:todoObject inSchema:@"todo" options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[[object valueForKey:@"category"] objectForKey:@"name"] should] equal:@"Updated Name"];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
    });
    it(@"Create new todo and update existing category, one to many", ^{
        // Create category object. We can specify a manual primary key if we wish, otherwise one will be automatically assigned when it's created.
        NSDictionary *categoryObject = [NSDictionary dictionaryWithObjectsAndKeys:@"Home Projects", @"name", @"1234", @"genre", nil];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        __block NSString *categoryId = nil;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:categoryObject inSchema:@"category" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            categoryId = [object valueForKey:@"category_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            NSDictionary *categoryUpdate = [NSDictionary dictionaryWithObjectsAndKeys:@"Updated Name", @"name", categoryId, @"category_id", nil];
            
            NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", [NSArray arrayWithObject:categoryUpdate], @"categories", nil];
            
            // Correlate the key "category" to the StackMob "category" schema
            SMRequestOptions *options = [SMRequestOptions options];
            [options associateKey:@"categories" withSchema:@"category"];
            
            success = NO;
            timeout = YES;
            
            dispatch_group_enter(group);
            // Execute request
            [dataStore createObject:todoObject inSchema:@"todo" options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[[[object valueForKey:@"categories"] lastObject] objectForKey:@"name"] should] equal:@"Updated Name"];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
    });
    it(@"Create new todo and update existing category with relationship to other entity", ^{
        // Create category object. We can specify a manual primary key if we wish, otherwise one will be automatically assigned when it's created.
        NSDictionary *categoryObject = [NSDictionary dictionaryWithObjectsAndKeys:@"Home Projects", @"name", nil];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        __block NSString *categoryId = nil;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:categoryObject inSchema:@"category" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            categoryId = [object valueForKey:@"category_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            NSDictionary *favoriteObject = [NSDictionary dictionaryWithObjectsAndKeys:@"My Favorites", @"genre", nil];
            NSDictionary *categoryUpdate = [NSDictionary dictionaryWithObjectsAndKeys:@"Updated Name", @"name", categoryId, @"category_id", favoriteObject, @"favorite", nil];
            
            NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", [NSArray arrayWithObject:categoryUpdate], @"categories", nil];
            
            // Correlate the key "category" to the StackMob "category" schema
            SMRequestOptions *options = [SMRequestOptions options];
            [options associateKey:@"categories" withSchema:@"category"];
            [options associateKey:@"categories.favorite" withSchema:@"favorite"];
            
            success = NO;
            timeout = YES;
            
            dispatch_group_enter(group);
            // Execute request
            [dataStore createObject:todoObject inSchema:@"todo" options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                NSDictionary *categoryResult = [[object valueForKey:@"categories"] lastObject];
                [[[categoryResult objectForKey:@"name"] should] equal:@"Updated Name"];
                [[[[categoryResult objectForKey:@"favorite"] objectForKey:@"genre"] should] equal:@"My Favorites"];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
    });
    it(@"Update existing todo and update existing category", ^{
        __block NSString *todoId = nil;
        __block NSString *catId = nil;
        
        // Create category object. We can specify a manual primary key if we wish, otherwise one will be automatically assigned when it's created.
        NSDictionary *categoryObject = [NSDictionary dictionaryWithObjectsAndKeys:@"Home Projects", @"name", nil];
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", categoryObject, @"category", nil];
        
        // Correlate the key "category" to the StackMob "category" schema
        SMRequestOptions *options = [SMRequestOptions options];
        [options associateKey:@"category" withSchema:@"category"];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            // Result will contain the entire todo object, as well as the entire nested category object.
            todoId = [object objectForKey:@"todo_id"];
            catId = [[object objectForKey:@"category"] objectForKey:@"category_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            NSDictionary *categoryUpdate = [NSDictionary dictionaryWithObjectsAndKeys:catId, @"category_id", @"updated name", @"name", nil];
            NSDictionary *todoUpdate = [NSDictionary dictionaryWithObjectsAndKeys:todoId, @"todo_id", @"updated title", @"title", categoryUpdate, @"category", nil];
            
            success = NO;
            timeout = YES;
            
            SMRequestOptions *options2 = [SMRequestOptions options];
            [options2 associateKey:@"category" withSchema:@"category"];
            
            dispatch_group_enter(group);
            // Execute request
            [dataStore createObject:todoUpdate inSchema:@"todo" options:options2 successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                // Result will contain the entire todo object, as well as the entire nested category object.
                [[[object objectForKey:@"title"] should] equal:@"updated title"];
                [[[[object objectForKey:@"category"] objectForKey:@"name"] should] equal:@"updated name"];
                success = YES;
                timeout = NO; 
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
    });
  
});

describe(@"Create and append", ^{
    __block SMDataStore *dataStore;
    beforeAll(^{
        dataStore = [SMIntegrationTestHelpers dataStore];
    });
    afterAll(^{
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        __block NSArray *todos = nil;
        __block NSArray *categories = nil;
        
        SMQuery *todoQuery = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [dataStore performQuery:todoQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            todos = results;
            [todos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"todo_id"] inSchema:@"todo" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        SMQuery *categoryQuery = [[SMQuery alloc] initWithSchema:@"category"];
        dispatch_group_enter(group);
        [dataStore performQuery:categoryQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            categories = results;
            [categories enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"category_id"] inSchema:@"category" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dataStore = nil;
        
        sleep(SLEEP_TIME);
    });
    it(@"Appends categories sucessfully", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *primaryKey = nil;
        SMRequestOptions *options = [SMRequestOptions options];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            primaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSDictionary *category1 = [NSDictionary dictionaryWithObjectsAndKeys:@"category1", @"name", nil];
            NSDictionary *category2 = [NSDictionary dictionaryWithObjectsAndKeys:@"category2", @"name", nil];
            NSArray *categories = [NSArray arrayWithObjects:category1, category2, nil];
            
            dispatch_group_enter(group);
            [dataStore createAndAppendRelatedObjects:categories toObjectWithId:primaryKey inSchema:@"todo" relatedField:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
                [[succeeded should] haveCountOf:2];
                [[failed should] haveCountOf:0];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
        
    });
    it(@"Fails smoothly", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *primaryKey = nil;
        SMRequestOptions *options = [SMRequestOptions options];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            primaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSDictionary *category1 = [NSDictionary dictionaryWithObjectsAndKeys:@"category1", @"name", @"1234", @"category_id", nil];
            NSDictionary *category2 = [NSDictionary dictionaryWithObjectsAndKeys:@"category2", @"name", @"5678", @"category_id", nil];
            NSDictionary *category3 = [NSDictionary dictionaryWithObjectsAndKeys:@"category3", @"name", @"1234", @"category_id", nil];
            NSArray *categories = [NSArray arrayWithObjects:category1, category2, category3, nil];
            
            dispatch_group_enter(group);
            // createAndAppendRelatedObjects: toObject: inSchema: relatedField:
            [dataStore createAndAppendRelatedObjects:categories toObjectWithId:primaryKey inSchema:@"todo" relatedField:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
                [[succeeded should] haveCountOf:2];
                [[failed should] haveCountOf:1];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
        
    });
    it(@"failure callback when objects are nil", ^{
        __block NSString *primaryKey = @"1234";
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        [dataStore createAndAppendRelatedObjects:nil toObjectWithId:primaryKey inSchema:@"todo" relatedField:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            [error shouldNotBeNil];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];

    });
    it(@"failure callback when primary key are nil", ^{
        __block NSString *primaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        NSArray *objects = [NSArray array];
        
        dispatch_group_enter(group);
        [dataStore createAndAppendRelatedObjects:objects toObjectWithId:primaryKey inSchema:@"todo" relatedField:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            [error shouldNotBeNil];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
    });
    it(@"failure callback when schema are nil", ^{
        __block NSString *primaryKey = @"1234";
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        NSArray *objects = [NSArray array];
        
        dispatch_group_enter(group);
        [dataStore createAndAppendRelatedObjects:objects toObjectWithId:primaryKey inSchema:nil relatedField:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            [error shouldNotBeNil];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
    });
    it(@"failure callback when field are nil", ^{
        __block NSString *primaryKey = @"1234";
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        NSArray *objects = [NSArray array];
        
        dispatch_group_enter(group);
        [dataStore createAndAppendRelatedObjects:objects toObjectWithId:primaryKey inSchema:@"todo" relatedField:nil options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            [error shouldNotBeNil];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
    });
});

describe(@"Append Values", ^{
    __block SMDataStore *dataStore;
    beforeAll(^{
        dataStore = [SMIntegrationTestHelpers dataStore];
    });
    afterAll(^{
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        __block NSArray *todos = nil;
        __block NSArray *categories = nil;
        
        SMQuery *todoQuery = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [dataStore performQuery:todoQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            todos = results;
            [todos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"todo_id"] inSchema:@"todo" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        SMQuery *categoryQuery = [[SMQuery alloc] initWithSchema:@"category"];
        dispatch_group_enter(group);
        [dataStore performQuery:categoryQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            categories = results;
            [categories enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"category_id"] inSchema:@"category" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dataStore = nil;
        
        sleep(SLEEP_TIME);
    });
    it(@"Appends realtionship categories sucessfully", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        __block NSString *categoryPK1 = nil;
        __block NSString *categoryPK2 = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSDictionary *category1 = [NSDictionary dictionaryWithObjectsAndKeys:@"category1", @"name", nil];
            NSDictionary *category2 = [NSDictionary dictionaryWithObjectsAndKeys:@"category2", @"name", nil];
            
            dispatch_group_enter(group);
            [dataStore createObject:category1 inSchema:@"category" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                categoryPK1 = [object valueForKey:@"category_id"];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_enter(group);
            [dataStore createObject:category2 inSchema:@"category" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                categoryPK2 = [object valueForKey:@"category_id"];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
            
            // Append categories and update todo
            success = NO;
            timeout = YES;
            
            NSArray *categories = [NSArray arrayWithObjects:categoryPK1, categoryPK2, nil];
            dispatch_group_enter(group);
            [dataStore appendObjects:categories toObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object valueForKey:@"categories"] should] haveCountOf:2];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
        
    });
    it(@"Appends values to array field sucessfully", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            
            dispatch_group_enter(group);
            [dataStore appendObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:5], [NSNumber numberWithInt:7], [NSNumber numberWithInt:9], [NSNumber numberWithInt:11], nil] toObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"array_field" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object valueForKey:@"array_field"] should] haveCountOf:4];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
        
    });
    it(@"Does not duplicate relationships", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        __block NSString *categoryPK1 = nil;
        __block NSString *categoryPK2 = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSDictionary *category1 = [NSDictionary dictionaryWithObjectsAndKeys:@"category1", @"name", nil];
            NSDictionary *category2 = [NSDictionary dictionaryWithObjectsAndKeys:@"category2", @"name", nil];
            
            dispatch_group_enter(group);
            [dataStore createObject:category1 inSchema:@"category" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                categoryPK1 = [object valueForKey:@"category_id"];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_enter(group);
            [dataStore createObject:category2 inSchema:@"category" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                categoryPK2 = [object valueForKey:@"category_id"];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
            
            // Append categories and update todo
            success = NO;
            timeout = YES;
            
            NSArray *categories = [NSArray arrayWithObjects:categoryPK1, categoryPK2, categoryPK2, nil];
            dispatch_group_enter(group);
            [dataStore appendObjects:categories toObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object valueForKey:@"categories"] should] haveCountOf:2];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
        
    });
    it(@"Duplicates when values are added to an array", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            
            dispatch_group_enter(group);
            [dataStore appendObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:5], [NSNumber numberWithInt:5], [NSNumber numberWithInt:7], [NSNumber numberWithInt:9], [NSNumber numberWithInt:11], nil] toObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"array_field" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object valueForKey:@"array_field"] should] haveCountOf:5];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
        
    });
    it(@"Failure with nil values", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            
            dispatch_group_enter(group);
            [dataStore appendObjects:nil toObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"array_field" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldNotBeNil];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
        
    });
    it(@"Failure with nil primary key", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            
            dispatch_group_enter(group);
            [dataStore appendObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:3], [NSNumber numberWithInt:6], nil] toObjectWithId:nil inSchema:@"todo" field:@"array_field" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldNotBeNil];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
        
    });
    it(@"Failure with nil schema", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            
            dispatch_group_enter(group);
            [dataStore appendObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:3], [NSNumber numberWithInt:6], nil] toObjectWithId:todoPrimaryKey inSchema:nil field:@"array_field" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldNotBeNil];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
        
    });
    it(@"Failure with nil field", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            
            dispatch_group_enter(group);
            [dataStore appendObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:3], [NSNumber numberWithInt:6], nil] toObjectWithId:todoPrimaryKey inSchema:@"todo" field:nil options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldNotBeNil];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
        
    });
});

describe(@"Delete Existing Values", ^{
    __block SMDataStore *dataStore;
    beforeAll(^{
        dataStore = [SMIntegrationTestHelpers dataStore];
    });
    afterAll(^{
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        __block NSArray *todos = nil;
        __block NSArray *categories = nil;
        
        SMQuery *todoQuery = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [dataStore performQuery:todoQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            todos = results;
            [todos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"todo_id"] inSchema:@"todo" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        SMQuery *categoryQuery = [[SMQuery alloc] initWithSchema:@"category"];
        dispatch_group_enter(group);
        [dataStore performQuery:categoryQuery options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            categories = results;
            [categories enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [dataStore deleteObjectId:[obj valueForKey:@"category_id"] inSchema:@"category" options:nil successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dataStore = nil;
        
        sleep(SLEEP_TIME);
    });
    it(@"Deletes related references and objects sucessfully", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        __block NSString *categoryPK1 = nil;
        __block NSString *categoryPK2 = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSDictionary *category1 = [NSDictionary dictionaryWithObjectsAndKeys:@"category1", @"name", nil];
            NSDictionary *category2 = [NSDictionary dictionaryWithObjectsAndKeys:@"category2", @"name", nil];
            NSArray *categories = [NSArray arrayWithObjects:category1, category2, nil];
            dispatch_group_enter(group);
            [dataStore createAndAppendRelatedObjects:categories toObjectWithId:todoPrimaryKey inSchema:@"todo" relatedField:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
                categoryPK1 = [succeeded objectAtIndex:0];
                categoryPK2 = [succeeded objectAtIndex:1];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
            
            // Append categories and update todo
            success = NO;
            timeout = YES;
            
            NSArray *categoryPrimaryKeys = [NSArray arrayWithObjects:categoryPK1, categoryPK2, nil];
            dispatch_group_enter(group);
            [dataStore deleteObjects:categoryPrimaryKeys fromObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"categories" cascadeDelete:YES options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^() {
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
            
            // Fetch on category should come back emtpy
            success = NO;
            timeout = YES;
            
            SMQuery *categoryQuery = [[SMQuery alloc] initWithSchema:@"category"];
            dispatch_group_enter(group);
            [dataStore performQuery:categoryQuery options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
                [[results should] haveCountOf:0];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
            
            
        }
        
    });
    it(@"Deletes related references sucessfully", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        __block NSString *categoryPK1 = nil;
        __block NSString *categoryPK2 = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        sleep(SLEEP_TIME);
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSDictionary *category1 = [NSDictionary dictionaryWithObjectsAndKeys:@"category1", @"name", nil];
            NSDictionary *category2 = [NSDictionary dictionaryWithObjectsAndKeys:@"category2", @"name", nil];
            NSArray *categories = [NSArray arrayWithObjects:category1, category2, nil];
            dispatch_group_enter(group);
            [dataStore createAndAppendRelatedObjects:categories toObjectWithId:todoPrimaryKey inSchema:@"todo" relatedField:@"categories" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
                categoryPK1 = [succeeded objectAtIndex:0];
                categoryPK2 = [succeeded objectAtIndex:1];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
            
            // Append categories and update todo
            success = NO;
            timeout = YES;
            
            NSArray *categoryPrimaryKeys = [NSArray arrayWithObjects:categoryPK1, categoryPK2, nil];
            dispatch_group_enter(group);
            [dataStore deleteObjects:categoryPrimaryKeys fromObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"categories" cascadeDelete:NO options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^() {
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
            
            // Fetch on category should come back emtpy
            success = NO;
            timeout = YES;
            
            SMQuery *categoryQuery = [[SMQuery alloc] initWithSchema:@"category"];
            dispatch_group_enter(group);
            [dataStore performQuery:categoryQuery options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
                [[results should] haveCountOf:2];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            sleep(SLEEP_TIME);
        }
        
    });
    /*
    it(@"Deletes related objects from array successfully", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        __block NSString *categoryPK1 = nil;
        __block NSString *categoryPK2 = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            success = NO;
            timeout = YES;
            
            dispatch_group_enter(group);
            [dataStore appendObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:30], [NSNumber numberWithInt:32], nil] toObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"lucky_numbers" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
                categoryPK1 = [[object objectForKey:@"lucky_numbers"] objectAtIndex:0];
                categoryPK2 = [[object objectForKey:@"lucky_numbers"] objectAtIndex:1];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSArray *objects, NSString *schema) {
                // Handle error
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
            
            // Append categories and update todo
            success = NO;
            timeout = YES;
            
            NSArray *luckyNumbersToDelete = [NSArray arrayWithObjects:[NSNumber numberWithInt:30], [NSNumber numberWithInt:32], nil];
            dispatch_group_enter(group);
            [dataStore deleteObjects:luckyNumbersToDelete fromObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"lucky_numbers" cascadeDelete:NO options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^() {
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSArray *objects, NSString *schema) {
                [error shouldBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
        
    });
     */
    it(@"Failure with nil values", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            success = NO;
            timeout = YES;

            dispatch_group_enter(group);
            [dataStore deleteObjects:nil fromObjectWithId:todoPrimaryKey inSchema:@"todo" field:@"categories" cascadeDelete:NO options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^() {
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldNotBeNil];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
    });
        
    it(@"Failure with nil primary key", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSArray *categoryPrimaryKeys = [NSArray array];
            dispatch_group_enter(group);
            [dataStore deleteObjects:categoryPrimaryKeys fromObjectWithId:nil inSchema:@"todo" field:@"categories" cascadeDelete:NO options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^() {
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldNotBeNil];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
    });
    it(@"Failure with nil schema", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSArray *categoryPrimaryKeys = [NSArray array];
            dispatch_group_enter(group);
            [dataStore deleteObjects:categoryPrimaryKeys fromObjectWithId:todoPrimaryKey inSchema:nil field:@"categories" cascadeDelete:NO options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^() {
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                success = YES;
                [error shouldNotBeNil];
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
        
    });
    it(@"Failure with nil field", ^{
        
        NSDictionary *todoObject = [NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil];
        __block NSString *todoPrimaryKey = nil;
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        __block BOOL success = NO;
        __block BOOL timeout = YES;
        
        dispatch_group_enter(group);
        // Execute request
        [dataStore createObject:todoObject inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            todoPrimaryKey = [object valueForKey:@"todo_id"];
            success = YES;
            timeout = NO;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            // Handle error
            [error shouldBeNil];
            timeout = NO;
            dispatch_group_leave(group);
        }];
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 45);
        dispatch_group_wait(group, time);
        
        [[theValue(success) should] beYes];
        [[theValue(timeout) should] beNo];
        
        if (success) {
            success = NO;
            timeout = YES;
            
            NSArray *categoryPrimaryKeys = [NSArray array];
            dispatch_group_enter(group);
            [dataStore deleteObjects:categoryPrimaryKeys fromObjectWithId:todoPrimaryKey inSchema:@"todo" field:nil cascadeDelete:NO options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^() {
                timeout = NO;
                dispatch_group_leave(group);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldNotBeNil];
                success = YES;
                timeout = NO;
                dispatch_group_leave(group);
            }];
            
            dispatch_group_wait(group, time);
            
            [[theValue(success) should] beYes];
            [[theValue(timeout) should] beNo];
        }
    
    });
    
});


SPEC_END