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
#import "SMIntegrationTestHelpers.h"

SPEC_BEGIN(CRUDTests)


describe(@"CRUD", ^{
    __block SMDataStore *dataStore = nil;
    beforeEach(^{
        dataStore = [SMIntegrationTestHelpers dataStore];
        [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:@"api.stackmob.com"];
    });
    it(@"should successfully create a Datastore", ^{
        [dataStore shouldNotBeNil];
    });
    
    context(@"creating a new book object", ^{
        __block NSDictionary *newBook = nil;
        __block NSString *newBookTitle = nil;
        beforeEach(^{
            newBookTitle = [NSString stringWithFormat:@"Twilight part %ld", random() % 10000];
            NSDictionary *book = [NSDictionary dictionaryWithObjectsAndKeys:
                                  newBookTitle, @"title",
                                  @"Rabid Fan", @"author",
                                  nil];
            
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore createObject:book inSchema:@"book" onSuccess:^(NSDictionary *object, NSString *schema) {
                    newBook = object;
                    syncReturn(semaphore);
                    NSLog(@"Created %@", object);
                } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                    NSLog(@"Failed to create a new %@: %@", schema, error);
                    syncReturn(semaphore);
                }];
            });
            
            [newBook shouldNotBeNil];
            
            sleep(SLEEP_TIME);
        });
        afterEach(^{
            [dataStore deleteObjectId:[newBook objectForKey:@"book_id"] inSchema:@"book" onSuccess:^(NSString *objectId, NSString *schema) {
                NSLog(@"Deleted %@", objectId);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                NSLog(@"Failed to delete %@", [newBook objectForKey:@"book_id"]);
            }];
            newBook = nil;
            
            sleep(SLEEP_TIME);
        });
        it(@"creates a new book object", ^{
            [newBook shouldNotBeNil];
            [[[newBook objectForKey:@"title"] should] equal:newBookTitle];
            [[newBook objectForKey:@"book_id"] shouldNotBeNil];
            [[newBook objectForKey:@"lastmoddate"] shouldNotBeNil];
            [[newBook objectForKey:@"createddate"] shouldNotBeNil];
        });
        context(@"when reading the new book object", ^{
            __block NSDictionary *readBook = nil;
            beforeEach(^{
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore readObjectWithId:[newBook objectForKey:@"book_id"] inSchema:@"book" onSuccess:^(NSDictionary *object, NSString *schema) {
                        readBook = object;
                        NSLog(@"Read %@", object);
                        syncReturn(semaphore);
                    } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                        NSLog(@"failed to read the object with error: %@", error);
                        syncReturn(semaphore);
                    }]; 
                });
            });
            
            [readBook shouldNotBeNil];
            
            it(@"returns the object's attributes", ^{
                [[readBook should] equal:newBook]; 
            });
        });
        context(@"updating the new object", ^{
            __block NSDictionary *updatedBook = nil;
            __block NSDictionary *updatedFields = nil;
            beforeEach(^{
                updatedFields = [NSDictionary dictionaryWithObjectsAndKeys:@"Coolest Author Ever", @"author", nil];
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore updateObjectWithId:[newBook objectForKey:@"book_id"] inSchema:@"book" update:updatedFields onSuccess:^(NSDictionary *object, NSString *schema) {
                        updatedBook = object;
                        NSLog(@"updated %@", object);
                        syncReturn(semaphore);
                    } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                        NSLog(@"failed to update the object with error: %@", error);
                        syncReturn(semaphore);
                    }]; 
                });
                
                [updatedBook shouldNotBeNil];
                
                sleep(SLEEP_TIME);
                 
            });
            it(@"updates the object's attributes", ^{
                [[[updatedBook objectForKey:@"book_id"] should] equal:[newBook objectForKey:@"book_id"]];
                [[[updatedBook objectForKey:@"author"] should] equal:@"Coolest Author Ever"];
            });
        });
    });
    context(@"deleting the new book", ^{
        __block NSDictionary *newBook = nil;
        __block NSString *newBookTitle = nil;
        beforeEach(^{
            newBookTitle = [NSString stringWithFormat:@"Twilight part %ld", random() % 10000];
            NSDictionary *book = [NSDictionary dictionaryWithObjectsAndKeys:
                                  newBookTitle, @"title",
                                  @"Rabid Fan", @"author",
                                  nil];
            
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore createObject:book inSchema:@"book" onSuccess:^(NSDictionary *object, NSString *schema) {
                    newBook = object;
                    syncReturn(semaphore);
                    NSLog(@"Created %@", object);
                } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                    NSLog(@"Failed to create a new %@: %@", schema, error);
                    syncReturn(semaphore);
                }];
            });
            
            [newBook shouldNotBeNil];
            
            sleep(SLEEP_TIME);
        });
        
        __block int deleteSucceeded = 0;
        it(@"deletes the object", ^{
            deleteSucceeded = 0;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore deleteObjectId:[newBook objectForKey:@"book_id"] inSchema:@"book" onSuccess:^(NSString *objectId, NSString *schema) {
                    NSLog(@"deleted %@", objectId);
                    deleteSucceeded = 1;
                    syncReturn(semaphore);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    NSLog(@"failed to delete the object with error: %@", error);
                    syncReturn(semaphore);
                }];
            });
            
            [theValue(deleteSucceeded) shouldNotBeNil];
            [[theValue(deleteSucceeded) should] equal:theValue(1)];
            
            sleep(SLEEP_TIME);
        });
    });
    context(@"CRUD with non-lowercase schema name", ^{
        __block NSDictionary *newBook = nil;
        __block NSString *newBookTitle = nil;
        __block NSDictionary *book = nil;
        __block NSString *returnedSchema = nil;
        __block NSString *objectId;
        beforeEach(^{
            newBookTitle = [NSString stringWithFormat:@"Twilight part %ld", random() % 10000];
            returnedSchema = nil;
            newBook = nil;
        });
        it(@"Should create given non-lowercase schema name", ^{
            book = [NSDictionary dictionaryWithObjectsAndKeys:
                    newBookTitle, @"title",
                    @"Rabid Fan", @"author",
                    nil];
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore createObject:book inSchema:@"Book" onSuccess:^(NSDictionary *object, NSString *schema) {
                    newBook = object;
                    returnedSchema = schema;
                    objectId = [object objectForKey:@"book_id"];
                    NSLog(@"Created %@", object);
                    syncReturn(semaphore);
                } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                    NSLog(@"Failed to create a new %@: %@", schema, error);
                    newBook = nil;
                    syncReturn(semaphore);
                }];
            });
            [newBook shouldNotBeNil];
            [[returnedSchema should] equal:@"Book"];
            
            sleep(SLEEP_TIME);
        });
        it(@"Should read given non-lowercase schema name", ^{
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore readObjectWithId:objectId inSchema:@"Book" onSuccess:^(NSDictionary *object, NSString *schema) {
                    newBook = object;
                    returnedSchema = schema;
                    NSLog(@"Read %@", object);
                    syncReturn(semaphore);
                } onFailure:^(NSError *error, NSString *objectID, NSString *schema) {
                    NSLog(@"Failed to read %@: %@", objectID, error);
                    newBook = nil;
                    syncReturn(semaphore);
                }];
            });
            [newBook shouldNotBeNil];
            [[returnedSchema should] equal:@"Book"];
        });
        it(@"Should update given non-lowercase schema name", ^{
            book = [NSDictionary dictionaryWithObjectsAndKeys:
                    newBookTitle, @"title",
                    @"Rabid Fan Not", @"author",
                    nil];
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore updateObjectWithId:objectId inSchema:@"Book" update:book onSuccess:^(NSDictionary *object, NSString *schema) {
                    newBook = object;
                    returnedSchema = schema;
                    NSLog(@"Updated %@", object);
                    syncReturn(semaphore);
                } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                    NSLog(@"Failed to update %@: %@", schema, error);
                    newBook = nil;
                    syncReturn(semaphore);
                }];
            });
            [newBook shouldNotBeNil];
            [[returnedSchema should] equal:@"Book"];
            
            sleep(SLEEP_TIME);
        });
        it(@"Should delete given non-lowercase schema name", ^{
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore deleteObjectId:objectId inSchema:@"Book" onSuccess:^(NSString *objectID, NSString *schema) {
                    returnedSchema = schema;
                    NSLog(@"Deleted %@", objectID);
                    syncReturn(semaphore);
                } onFailure:^(NSError *error, NSString *objectID, NSString *schema) {
                    NSLog(@"Failed to delete %@: %@", schema, error);
                    syncReturn(semaphore);
                }];
            });
            [[returnedSchema should] equal:@"Book"];
            
            sleep(SLEEP_TIME);
        });

    });
});

describe(@"CRUD with GeoPoints", ^{
    __block SMDataStore *dataStore = nil;
    __block SMGeoPoint *point = nil;
    __block NSDictionary *anObject = nil;
    
    beforeEach(^{;
        dataStore = [SMIntegrationTestHelpers dataStore];
        [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:@"api.stackmob.com"];
        
        // Fisherman's Wharf
        NSNumber *lat = [NSNumber numberWithDouble:37.810317];
        NSNumber *lon = [NSNumber numberWithDouble:-122.418167];
        point = [SMGeoPoint geoPointWithLatitude:lat longitude:lon];
        
        NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:@"StackMob", @"name", point, @"geopoint", nil];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [dataStore createObject:args inSchema:@"random" onSuccess:^(NSDictionary *object, NSString *schema) {
                anObject = object;
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [dataStore deleteObjectId:[anObject objectForKey:@"random_id"] inSchema:@"random" onSuccess:^(NSString *objectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                syncReturn(semaphore);
            }];
        });
        anObject = nil;
        
        sleep(SLEEP_TIME);
    });
    it(@"Saves SMGeoPoint without error", ^{
        [anObject shouldNotBeNil];
    });
    it(@"Reads SMGeoPoints correctly", ^{
        
        SMGeoPoint *geopoint = [anObject objectForKey:@"geopoint"];
        
        [[geopoint.latitude should] equal:point.latitude];
        [[geopoint.longitude should] equal:point.longitude];
    });
});

describe(@"read value containing special chartacters", ^{
    __block SMClient *client = nil;
    __block NSString *objId = @"matt+matt@matt.com";
    __block NSString *primaryKey = @"blog_id";
    __block NSString *schemaName = @"blog";
    __block NSString *fieldKey = @"blogname";
    __block NSString *fieldValue = @"coolblog";
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *createDict = [NSDictionary dictionaryWithObjectsAndKeys:objId, primaryKey, fieldValue, fieldKey, nil];
            [[client dataStore] createObject:createDict inSchema:schemaName onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object objectForKey:fieldKey] should] equal:fieldValue];
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:objId inSchema:schemaName onSuccess:^(NSString *objectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
    });
    it(@"reads and updates the value with special characters", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] readObjectWithId:objId inSchema:schemaName onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object objectForKey:fieldKey] should] equal:fieldValue];
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *updateDict = [NSDictionary dictionaryWithObjectsAndKeys:@"c*oo^l$blog", fieldKey, nil];
            [[client dataStore] updateObjectWithId:objId inSchema:schemaName update:updateDict onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object objectForKey:fieldKey] should] equal:@"c*oo^l$blog"];
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
    });
    
});

describe(@"read value containing special chartacters in schema with permissions", ^{
    __block SMClient *client = nil;
    __block NSString *objId = @"matt+mat@matt.com";
    __block NSString *primaryKey = @"blog2_id";
    __block NSString *schemaName = @"blog2";
    __block NSString *fieldKey = @"blogname";
    __block NSString *fieldValue = @"coolblog";
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [client setUserSchema:@"user3"];
        // create user 3
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *userDict = [NSDictionary dictionaryWithObjectsAndKeys:objId, @"username", @"1234", @"password", nil];
            [[client dataStore] createObject:userDict inSchema:@"user3" onSuccess:^(NSDictionary *object, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
        
        // login user3
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client loginWithUsername:objId password:@"1234" onSuccess:^(NSDictionary *result) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        // create blog2
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *createDict = [NSDictionary dictionaryWithObjectsAndKeys:objId, primaryKey, fieldValue, fieldKey, nil];
            [[client dataStore] createObject:createDict inSchema:schemaName onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object objectForKey:fieldKey] should] equal:fieldValue];
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        
        // logout user3
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client logoutOnSuccess:^(NSDictionary *result) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        // delete blog2
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:objId inSchema:schemaName onSuccess:^(NSString *objectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
        
        // delete user3
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:objId inSchema:@"user3" onSuccess:^(NSString *objectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
    });
    it(@"reads and updates the value with special characters", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] readObjectWithId:objId inSchema:schemaName onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object objectForKey:fieldKey] should] equal:fieldValue];
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *updateDict = [NSDictionary dictionaryWithObjectsAndKeys:@"c*ool$blog", fieldKey, nil];
            [[client dataStore] updateObjectWithId:objId inSchema:schemaName update:updateDict onSuccess:^(NSDictionary *object, NSString *schema) {
                [[[object objectForKey:fieldKey] should] equal:@"c*ool$blog"];
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
    });
    
});

describe(@"setExpandDepth", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
    });
    it(@"Works with 1-1 read", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
            [[client dataStore] readObjectWithId:@"1234" inSchema:@"expanddepthtest" options:options onSuccess:^(NSDictionary *object, NSString *schema)
             {
                 int value = 0;
                 if ([[[object objectForKey:@"child"] class] isSubclassOfClass:[NSDictionary class]]) {
                     value = 1;
                 }
                 [[theValue(value) should] equal:theValue(1)];
                 [[[[object objectForKey:@"child"] objectForKey:@"name"] should] equal:@"bob"];
                 syncReturn(semaphore);
             } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                 [error shouldBeNil];
                 syncReturn(semaphore);
             }];
        });
    });
    
     it(@"Works with 1-many read", ^{
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
             SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
             [[client dataStore] readObjectWithId:@"5678" inSchema:@"expanddepthtest" options:options onSuccess:^(NSDictionary *object, NSString *schema)
             {
                NSLog(@"the object is %@", object);
                 [[theValue([[object objectForKey:@"children"] count]) should] equal:theValue(3)];
                 int value = 0;
                 if ([[[object objectForKey:@"children"] class] isSubclassOfClass:[NSArray class]]) {
                     value = 1;
                 }
                 [[theValue(value) should] equal:theValue(1)];
                 value = 0;
                 if ([[[[object objectForKey:@"children"] objectAtIndex:0] class] isSubclassOfClass:[NSDictionary class]]) {
                     value = 1;
                 }
                 [[theValue(value) should] equal:theValue(1)];
                 syncReturn(semaphore);
             } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                 [error shouldBeNil];
                 syncReturn(semaphore);
             }];
         });
     });
     
    
     it(@"Works with 1-1 and 1-many general queries", ^{
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
             SMQuery *query = [[SMQuery alloc] initWithSchema:@"expanddepthtest"];
             SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
             [[client dataStore] performQuery:query options:options onSuccess:^(NSArray *results)
             {
                 for(NSDictionary *dictionary in results) {
                     if([dictionary objectForKey:@"child"]){
                         int value = 0;
                         if ([[[dictionary objectForKey:@"child"] class] isSubclassOfClass:[NSDictionary class]]) {
                             value = 1;
                         }
                         [[theValue(value) should] equal:theValue(1)];
                         [[[[dictionary objectForKey:@"child"] objectForKey:@"name"] should] equal:@"bob"];
                         
                     }
                     else if ([dictionary objectForKey:@"children"]){
                         [[theValue([[dictionary objectForKey:@"children"] count]) should] equal:theValue(3)];
                         int value = 0;
                         if ([[[dictionary objectForKey:@"children"] class] isSubclassOfClass:[NSArray class]]) {
                             value = 1;
                         }
                         [[theValue(value) should] equal:theValue(1)];
                         value = 0;
                         if ([[[[dictionary objectForKey:@"children"] objectAtIndex:0] class] isSubclassOfClass:[NSDictionary class]]) {
                             value = 1;
                         }
                         [[theValue(value) should] equal:theValue(1)];
                     }
                 }
                  syncReturn(semaphore);
             } onFailure:^(NSError *error) {
                 
                  [error shouldBeNil];
                  syncReturn(semaphore);
             }];
         });
     });
     it(@"Works with 1-1 query", ^{
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
             SMQuery *query = [[SMQuery alloc] initWithSchema:@"expanddepthtest"];
             [query where:@"expanddepthtest_id" isEqualTo:@"1234"];
             SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
             [[client dataStore] performQuery:query options:options onSuccess:^(NSArray *results)
              {
                  NSDictionary *dictionary = [results objectAtIndex:0];
                  int value = 0;
                  if ([[[dictionary objectForKey:@"child"] class] isSubclassOfClass:[NSDictionary class]]) {
                      value = 1;
                  }
                  [[theValue(value) should] equal:theValue(1)];
                  [[[[dictionary objectForKey:@"child"] objectForKey:@"name"] should] equal:@"bob"];
                  syncReturn(semaphore);
              } onFailure:^(NSError *error) {
                  
                  [error shouldBeNil];
                  syncReturn(semaphore);
              }];
         });
     });
    it(@"Works with 1-many query", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            SMQuery *query = [[SMQuery alloc] initWithSchema:@"expanddepthtest"];
            [query where:@"expanddepthtest_id" isEqualTo:@"5678"];
            SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
            [[client dataStore] performQuery:query options:options onSuccess:^(NSArray *results)
             {
                 NSDictionary *dictionary = [results objectAtIndex:0];
                 [[theValue([[dictionary objectForKey:@"children"] count]) should] equal:theValue(3)];
                 int value = 0;
                 if ([[[dictionary objectForKey:@"children"] class] isSubclassOfClass:[NSArray class]]) {
                     value = 1;
                 }
                 [[theValue(value) should] equal:theValue(1)];
                 
                 value = 0;
                 if ([[[[dictionary objectForKey:@"children"] objectAtIndex:0] class] isSubclassOfClass:[NSDictionary class]]) {
                     value = 1;
                 }
                 [[theValue(value) should] equal:theValue(1)];
                 syncReturn(semaphore);
             } onFailure:^(NSError *error) {
                 
                 [error shouldBeNil];
                 syncReturn(semaphore);
             }];
        });
    });
    it(@"throws an exception when attempting post method", ^{
        SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
        NSDictionary *toCreate = [NSDictionary dictionaryWithObjectsAndKeys:@"1234", @"expanddepthtest_id", nil];
        [[theBlock(^{
            [[client dataStore] createObject:toCreate inSchema:@"expanddepthtest" options:options onSuccess:^(NSDictionary *object, NSString *schema)
             {
                 // Doesn't matter
             } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                 [error shouldNotBeNil];
                 [[theValue([error code]) should] equal:theValue(SMErrorInvalidArguments)];
             }];
        }) should] raiseWithReason:@"Expand depth is not supported for creates or updates.  Please check your requests and edit accordingly."];
        
    });
    
    it(@"throws an exception when attempting post method", ^{
        SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
        NSDictionary *toCreate = [NSDictionary dictionaryWithObjectsAndKeys:@"1234", @"expanddepthtest_id", nil];
        [[theBlock(^{
            [[client dataStore] updateObjectWithId:@"1234" inSchema:@"expanddepthtest" update:toCreate options:options onSuccess:^(NSDictionary *object, NSString *schema)
             {
                 // Doesn't matter
             } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
                 [error shouldNotBeNil];
                 [[theValue([error code]) should] equal:theValue(SMErrorInvalidArguments)];
             }];
        }) should] raiseWithReason:@"Expand depth is not supported for creates or updates.  Please check your requests and edit accordingly."];
    });
});




SPEC_END
