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
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "Person.h"
#import "Superpower.h"
#import "SMTestProperties.h"

SPEC_BEGIN(SMIncrementalStoreTest)

describe(@"with fixtures", ^{
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    
    __block NSManagedObjectContext *moc = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    
    
    beforeEach(^{
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
        
        sleep(SLEEP_TIME);
        
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers registerForMOCNotificationsWithContext:moc];
    });
    
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        
        sleep(SLEEP_TIME);
        
        [SMCoreDataIntegrationTestHelpers removeObserversrForMOCNotificationsWithContext:moc];
    });
    
    
    describe(@"save requests", ^{
        __block NSArray *people;
        __block NSInteger beforeInsert;
        __block NSInteger afterInsert;
        
        describe(@"insert", ^{
            
            it(@"inserts an object", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    people = results;
                    beforeInsert = [people count];
                    DLog(@"beforeInsert is %ld", (long)beforeInsert);
                }];
                NSManagedObject *sean = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
                [sean setValue:@"Sean" forKey:@"first_name"];
                [sean setValue:@"Smith" forKey:@"last_name"];
                [sean setValue:@"StackMob" forKey:@"company"];
                [sean setValue:[NSNumber numberWithInt:15] forKey:@"armor_class"];
                [sean assignObjectId];
                DLog(@"inserted objects before save %@", [moc insertedObjects]);
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                DLog(@"inserted objects after save are %@", [moc insertedObjects]);
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    people = results;
                    afterInsert = [people count];
                    DLog(@"afterInsert is %ld", (long)afterInsert);
                    [[theValue(afterInsert) should] equal:theValue(beforeInsert + 1)];
                }];
            });
            
            it(@"inserts an object with a one-to-one relationship", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                // create person
                NSManagedObject *sean = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
                [sean setValue:@"Bob" forKey:@"first_name"];
                [sean setValue:@"Bobberson" forKey:@"last_name"];
                [sean setValue:@"StackMob" forKey:@"company"];
                [sean setValue:[NSNumber numberWithInt:15] forKey:@"armor_class"];
                [sean assignObjectId];
                
                
                // create superpower
                NSManagedObject *invisibility = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
                [invisibility setValue:@"invisibility" forKey:@"name"];
                [invisibility setValue:[NSNumber numberWithInt:7] forKey:@"level"];
                [invisibility assignObjectId];
                
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                                
                //link superpower to person
                [sean setValue:invisibility forKey:@"superpower"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                __block NSManagedObject *person;
                __block NSManagedObject *superpower;
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"last_name = 'Bobberson'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                    person = [results objectAtIndex:0];
                    NSString *personId = [person valueForKey:@"person_id"];
                    NSString *personSuperpowerPersonId = [[[person valueForKey:@"superpower"] valueForKey:@"person"] valueForKey:@"person_id"];
                    [[theValue(personId) should] equal:theValue(personSuperpowerPersonId)];
                    
                }];
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                    superpower = [results objectAtIndex:0];
                    NSString *superpowerId = [superpower valueForKey:@"superpower_id"];
                    NSString *superpowerPersonSuperpowerId = [[[superpower valueForKey:@"person"] valueForKey:@"superpower"] valueForKey:@"superpower_id"];
                    [[theValue(superpowerId) should] equal:theValue(superpowerPersonSuperpowerId)];
                    
                }];
                
                // TODO MAKE SYNC
                [[[SMIntegrationTestHelpers defaultClient] dataStore] deleteObjectId:[superpower SMObjectId] inSchema:[superpower SMSchema] onSuccess:^(NSString *objectId, NSString *schema) {
                    DLog(@"Deleted superpower");
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    DLog(@"Did not delete superpower with error userInfo %@", [error userInfo]);
                }];
                
                sleep(SLEEP_TIME);
            });


            it(@"inserts/updates an object with a one-to-many relationship", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                
                // create person
                NSManagedObject *sean = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
                [sean setValue:@"Bob" forKey:@"first_name"];
                [sean setValue:@"Bobberson" forKey:@"last_name"];
                [sean setValue:@"StackMob" forKey:@"company"];
                [sean setValue:[NSNumber numberWithInt:15] forKey:@"armor_class"];
                [sean assignObjectId];
                // create 2 interests
                NSManagedObject *basketball = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
                [basketball setValue:@"basketball" forKey:@"name"];
                [basketball setValue:[NSNumber numberWithInt:10] forKey:@"years_involved"];
                [basketball assignObjectId];
                
                NSManagedObject *tennis = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
                [tennis setValue:@"tennis" forKey:@"name"];
                [tennis setValue:[NSNumber numberWithInt:3] forKey:@"years_involved"];
                [tennis assignObjectId];
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // link the two
                //[moc refreshObject:sean mergeChanges:YES];
                [basketball setValue:sean forKey:@"person"];
                [tennis setValue:sean forKey:@"person"];
                
                //[sean addBasketballObject:basketball];
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                [sean setValue:@"Sean" forKey:@"first_name"];
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // fetch and check
                __block NSString *seanId = [sean valueForKey:[sean primaryKeyField]];
                __block NSString *bbId = [basketball valueForKey:[basketball primaryKeyField]];
                __block NSString *tennisId = [tennis valueForKey:[tennis primaryKeyField]];
                
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"last_name = 'Bobberson'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                    Person *result = [results objectAtIndex:0];
                    [[[result valueForKey:@"person_id"] should] equal:seanId];
                    [[[result objectID] should] equal:[sean objectID]];
                    NSSet *interests = [result valueForKey:@"interests"];
                    [[theValue([interests count]) should] equal:[NSNumber numberWithInt:2]];
                    [interests enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                        NSString *objName = [obj valueForKey:@"name"];
                        if ([objName isEqualToString:@"basketball"]) {
                            [[[obj valueForKey:@"interest_id"] should] equal:bbId];
                        } else if ([objName isEqualToString:@"tennis"]) {
                            [[[obj valueForKey:@"interest_id"] should] equal:tennisId];
                        }
                    }];
                    
                }];
                
                predicate = [NSPredicate predicateWithFormat:@"name = 'basketball'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                    NSManagedObject *result = [results objectAtIndex:0];
                    [[[result valueForKey:@"interest_id"] should] equal:bbId];
                    [[[result objectID] should] equal:[basketball objectID]];
                    [[[[result valueForKey:@"person"] valueForKey:@"person_id"] should] equal:seanId];
                }];

                // TODO MAKE SYNC
                [[[SMIntegrationTestHelpers defaultClient] dataStore] deleteObjectId:[basketball SMObjectId] inSchema:[basketball SMSchema] onSuccess:^(NSString *objectId, NSString *schema) {
                    DLog(@"Deleted basketball");
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    DLog(@"Did not delete basketball with error userInfo %@",[error userInfo]);
                }];
                
                sleep(SLEEP_TIME);
                
                [[[SMIntegrationTestHelpers defaultClient] dataStore] deleteObjectId:[tennis SMObjectId] inSchema:[tennis SMSchema] onSuccess:^(NSString *objectId, NSString *schema) {
                    DLog(@"Deleted tennis");
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    DLog(@"Did not delete tennis with error userInfo %@",[error userInfo]);
                }];
                
                sleep(SLEEP_TIME);
                
            });
            
            it(@"inserts/updates an object with a many-to-many relationship", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                // make 2 person objects
                NSManagedObject *bob = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
                [bob setValue:@"Bob" forKey:@"first_name"];
                [bob setValue:@"Bobberson" forKey:@"last_name"];
                [bob setValue:@"StackMob" forKey:@"company"];
                [bob setValue:[NSNumber numberWithInt:15] forKey:@"armor_class"];
                [bob assignObjectId];
                
                NSManagedObject *jack = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
                [jack setValue:@"Jack" forKey:@"first_name"];
                [jack setValue:@"Jackerson" forKey:@"last_name"];
                [jack setValue:@"StackMob" forKey:@"company"];
                [jack setValue:[NSNumber numberWithInt:20] forKey:@"armor_class"];
                [jack assignObjectId];
                
                // make 2 favorite objects
                NSManagedObject *blueBottle = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:moc];
                [blueBottle setValue:@"coffee" forKey:@"genre"];
                [blueBottle assignObjectId];
                
                NSManagedObject *batman = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:moc];
                [batman setValue:@"movies" forKey:@"genre"];
                [batman assignObjectId];
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // link bob to each of the favorites
                NSMutableSet *set = [NSMutableSet set];
                [set addObject:blueBottle];
                [set addObject:batman];
                [bob setValue:set forKey:@"favorites"];
                [jack setValue:set forKey:@"favorites"];
                
                // link each favorite to jack (for vareity)
                
                //[[batman valueForKey:@"persons"] unionSet:[NSSet setWithObject:jack]];
                //[[blueBottle valueForKey:@"persons"] unionSet:[NSSet setWithObject:jack]];
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // fetch and check
                __block NSString *batmanId = [batman valueForKey:[batman primaryKeyField]];
                __block NSString *blueBottleId = [blueBottle valueForKey:[blueBottle primaryKeyField]];
                __block NSString *bobId = [bob valueForKey:[bob primaryKeyField]];
                __block NSString *jackId = [jack valueForKey:[jack primaryKeyField]];
                
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"last_name = 'Bobberson'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                    Person *result = [results objectAtIndex:0];
                    [[[result valueForKey:@"person_id"] should] equal:bobId];
                    [[[result objectID] should] equal:[bob objectID]];
                    NSSet *favorites = [result valueForKey:@"favorites"];
                    [[theValue([favorites count]) should] equal:[NSNumber numberWithInt:2]];
                    [favorites enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                        NSString *objGenre = [obj valueForKey:@"genre"];
                        if ([objGenre isEqualToString:@"movies"]) {
                            [[[obj valueForKey:@"favorite_id"] should] equal:batmanId];
                        } else if ([objGenre isEqualToString:@"coffee"]) {
                            [[[obj valueForKey:@"favorite_id"] should] equal:blueBottleId];
                        }
                    }];
                    
                }];
                
                predicate = [NSPredicate predicateWithFormat:@"last_name = 'Jackerson'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                    Person *result = [results objectAtIndex:0];
                    [[[result valueForKey:@"person_id"] should] equal:jackId];
                    [[[result objectID] should] equal:[jack objectID]];
                    NSSet *favorites = [result valueForKey:@"favorites"];
                    [[theValue([favorites count]) should] equal:[NSNumber numberWithInt:2]];
                    [favorites enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                        NSString *objGenre = [obj valueForKey:@"genre"];
                        if ([objGenre isEqualToString:@"movies"]) {
                            [[[obj valueForKey:@"favorite_id"] should] equal:batmanId];
                        } else if ([objGenre isEqualToString:@"coffee"]) {
                            [[[obj valueForKey:@"favorite_id"] should] equal:blueBottleId];
                        }
                    }];
                    
                }];
                
                predicate = [NSPredicate predicateWithFormat:@"genre = 'movies'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeFavoriteFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                    NSManagedObject *result = [results objectAtIndex:0];
                    [[[result valueForKey:@"favorite_id"] should] equal:batmanId];
                    [[[result objectID] should] equal:[batman objectID]];
                    NSSet *persons = [result valueForKey:@"persons"];
                    [[theValue([persons count]) should] equal:[NSNumber numberWithInt:2]];
                    [persons enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                        NSString *objLastName = [obj valueForKey:@"last_name"];
                        if ([objLastName isEqualToString:@"Bobberson"]) {
                            [[[obj valueForKey:@"person_id"] should] equal:bobId];
                        } else if ([objLastName isEqualToString:@"Jackerson"]) {
                            [[[obj valueForKey:@"person_id"] should] equal:jackId];
                        }
                    }];
                    
                }];
                
                predicate = [NSPredicate predicateWithFormat:@"genre = 'coffee'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeFavoriteFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                    NSManagedObject *result = [results objectAtIndex:0];
                    [[[result valueForKey:@"favorite_id"] should] equal:blueBottleId];
                    [[[result objectID] should] equal:[blueBottle objectID]];
                    NSSet *persons = [result valueForKey:@"persons"];
                    [[theValue([persons count]) should] equal:[NSNumber numberWithInt:2]];
                    [persons enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                        NSString *objLastName = [obj valueForKey:@"last_name"];
                        if ([objLastName isEqualToString:@"Bobberson"]) {
                            [[[obj valueForKey:@"person_id"] should] equal:bobId];
                        } else if ([objLastName isEqualToString:@"Jackerson"]) {
                            [[[obj valueForKey:@"person_id"] should] equal:jackId];
                        }
                    }];
                    
                }];
                
                
                
                // delete objects
                [[[SMIntegrationTestHelpers defaultClient] dataStore] deleteObjectId:[blueBottle SMObjectId] inSchema:[blueBottle SMSchema] onSuccess:^(NSString *objectId, NSString *schema) {
                    DLog(@"Deleted blueBottle");
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    DLog(@"Did not delete blueBottle with error userInfo %@",[error userInfo]);
                }];
                
                sleep(SLEEP_TIME);
                
                [[[SMIntegrationTestHelpers defaultClient] dataStore] deleteObjectId:[batman SMObjectId] inSchema:[batman SMSchema] onSuccess:^(NSString *objectId, NSString *schema) {
                    DLog(@"Deleted batman");
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    DLog(@"Did not delete batman with error userInfo %@",[error userInfo]);
                }];
                
                sleep(SLEEP_TIME);
                
            });

        });
        
        describe(@"update", ^{
            it(@"updates an object", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    people = results;
                }];
                
                
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousUpdate:moc withObject:[[people objectAtIndex:0] objectID] andBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    DLog(@"Executed syncronous update");
                }];
                
                sleep(SLEEP_TIME);
                
                NSLog(@"updated objects after update %@", [moc updatedObjects]);
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[[results objectAtIndex:0] should] haveValue:[NSNumber numberWithInt:20] forKey:@"armor_class"];
                }];
            });
        });
        
        describe(@"delete", ^{
            
            it(@"deletes objects from StackMob", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    people = results;
                    DLog(@"people after first fetch is %@", people);
                }];
                [SMCoreDataIntegrationTestHelpers executeSynchronousDelete:moc withObject:[[people objectAtIndex:0] objectID] andBlock:^(NSError *error) {
                    DLog(@"Executed syncronous delete");
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    DLog(@"people after second fetch is %@", results);
                    [[results should] haveCountOf:2];
                    [[[results objectAtIndex:0] should] haveValue:@"Vaznaian" forKey:@"last_name"];
                    [[[results objectAtIndex:1] should] haveValue:@"Williams" forKey:@"last_name"];
                }];
            });
            
            it(@"deletes objects with relationships", ^{
                //SM_CORE_DATA_DEBUG = YES;
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                __block Person *firstPerson;
                __block NSString *firstPersonName;
                __block int countOfPeopleBeforeDelete;
                __block int countOfPeopleAfterDelete;
                // grab a person
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    countOfPeopleBeforeDelete = [results count];
                    firstPerson = [results objectAtIndex:0];
                    firstPersonName = [firstPerson valueForKey:@"first_name"];
                    DLog(@"people after first fetch is %@", people);
                }];
                
                // add an interest
                NSManagedObject *batman = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:moc];
                [batman setValue:@"movies" forKey:@"genre"];
                [batman assignObjectId];
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // link the interest to the person
                NSSet *aSet = [NSSet setWithObject:firstPerson];
                [batman setValue:aSet forKey:@"persons"];
                
                // save
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // delete the person
                [SMCoreDataIntegrationTestHelpers executeSynchronousDelete:moc withObject:[firstPerson objectID] andBlock:^(NSError *error) {
                    DLog(@"Executed syncronous delete");
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // make sure everything is cool
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    DLog(@"people after second fetch is %@", results);
                    countOfPeopleAfterDelete = [results count];
                    [[theValue(countOfPeopleAfterDelete) should] equal:theValue(countOfPeopleBeforeDelete - 1)];
                }];
                
                [[[SMIntegrationTestHelpers defaultClient] dataStore] deleteObjectId:[batman SMObjectId] inSchema:[batman SMSchema] onSuccess:^(NSString *objectId, NSString *schema) {
                    DLog(@"Deleted batman");
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    DLog(@"Did not delete batman with error userInfo %@",[error userInfo]);
                }];
                
                sleep(SLEEP_TIME);
                
            });
        });
        
        describe(@"retreiving an object with to-many relationships as faults", ^{
            it(@"cache insert and new relationship for objectID return the correct things", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                __block Person *firstPerson;
                __block NSString *firstPersonName;
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    firstPerson = [results objectAtIndex:0];
                    firstPersonName = [firstPerson valueForKey:@"first_name"];
                }];
                
                
                NSManagedObject *basketball = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
                [basketball setValue:@"basketball" forKey:@"name"];
                [basketball setValue:[NSNumber numberWithInt:10] forKey:@"years_involved"];
                [basketball assignObjectId];
                
                NSManagedObject *tennis = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
                [tennis setValue:@"tennis" forKey:@"name"];
                [tennis setValue:[NSNumber numberWithInt:3] forKey:@"years_involved"];
                [tennis assignObjectId];
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // link the two
                [basketball setValue:firstPerson forKey:@"person"];
                [tennis setValue:firstPerson forKey:@"person"];

                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"first_name = %@", firstPersonName];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                    [[theValue([results count]) should] equal:[NSNumber numberWithInt:1]];
                }];
                
                // update and save
                [firstPerson setValue:@"Cool" forKey:@"last_name"];
                
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    if (error != nil) {
                        DLog(@"Error userInfo is %@", [error userInfo]);
                        [error shouldBeNil];
                    }
                }];
                
                sleep(SLEEP_TIME);
                
                // delete objects
                [[[SMIntegrationTestHelpers defaultClient] dataStore] deleteObjectId:[basketball SMObjectId] inSchema:[basketball SMSchema] onSuccess:^(NSString *objectId, NSString *schema) {
                    DLog(@"Deleted basketball");
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    DLog(@"Did not delete basketball with error userInfo %@", [error userInfo]);
                }];
                
                sleep(SLEEP_TIME);
                
                [[[SMIntegrationTestHelpers defaultClient] dataStore] deleteObjectId:[tennis SMObjectId] inSchema:[tennis SMSchema] onSuccess:^(NSString *objectId, NSString *schema) {
                    DLog(@"Deleted tennis");
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    [error shouldBeNil];
                    DLog(@"did not delete tennis with error userInfo %@", [error userInfo]);
                }];
                
                sleep(SLEEP_TIME);

            });
                        
        });
        
    });
});

describe(@"Testing CRUD on an entity with camelCase property names", ^{
    __block NSManagedObjectContext *moc = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObject *camelCaseObject = nil;
    beforeEach(^{
        //SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        camelCaseObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [camelCaseObject setValue:@"new" forKey:@"name"];
        [camelCaseObject setValue:@"1234" forKey:@"server_id"];
        [camelCaseObject setValue:[NSNumber numberWithInt:1900] forKey:@"yearBorn"];
        [camelCaseObject assignObjectId];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        NSError *theerror = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&theerror];
        [theerror shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [moc deleteObject:obj];
        }];
        if ([moc hasChanges]) {
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                if (error != nil) {
                    DLog(@"Error userInfo is %@", [error userInfo]);
                    [error shouldBeNil];
                }
            }];
            
            sleep(SLEEP_TIME);
        }
        
    });
    
    it(@"Will successfully read with a predicate", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"yearBorn == 1900"];
        [fetchRequest setPredicate:predicate];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
        }];
    });
    
    it(@"Will successfully read with a sort descriptor", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *anotherRandom = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [anotherRandom setValue:@"another" forKey:@"name"];
        [anotherRandom setValue:@"1234" forKey:@"server_id"];
        [anotherRandom setValue:[NSNumber numberWithInt:2012] forKey:@"yearBorn"];
        [anotherRandom assignObjectId];
        
        NSManagedObject *yetAnotherRandom = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [yetAnotherRandom setValue:@"yetAnother" forKey:@"name"];
        [yetAnotherRandom setValue:@"1234" forKey:@"server_id"];
        [yetAnotherRandom setValue:[NSNumber numberWithInt:1800] forKey:@"yearBorn"];
        [yetAnotherRandom assignObjectId];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        sleep(SLEEP_TIME);
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"yearBorn" ascending:YES]]];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(3)];
            [[[[results objectAtIndex:0] valueForKey:@"yearBorn"] should] equal:theValue(1800)];
            [[[[results objectAtIndex:1] valueForKey:@"yearBorn"] should] equal:theValue(1900)];
            [[[[results objectAtIndex:2] valueForKey:@"yearBorn"] should] equal:theValue(2012)];
        }];
        
        
        [moc deleteObject:anotherRandom];
        [moc deleteObject:yetAnotherRandom];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        sleep(SLEEP_TIME);
        
    });
    
    it(@"Will save without error after update", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [camelCaseObject setValue:[NSNumber numberWithInt:2000] forKey:@"yearBorn"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        sleep(SLEEP_TIME);
        
    });
     
});

describe(@"test camel case with relationships", ^{
    __block NSManagedObjectContext *moc = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObject *todo = nil;
    __block NSManagedObject *category = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
    });
    it(@"Should pass for one-to-one", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        
        [todo assignObjectId];
        [todo setValue:@"Hello One-To-One" forKey:@"title"];
        
        category = [NSEntityDescription insertNewObjectForEntityForName:@"Category" inManagedObjectContext:moc];
        
        [category assignObjectId];
        [category setValue:@"Work" forKey:@"name"];
        
        
        NSError *error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"You created a Todo and Category object!");
        }
        
        sleep(SLEEP_TIME);
        
        [todo setValue:category forKey:@"category"];
        
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"You created a relationship between the Todo and Category Object!");
        }
        
        sleep(SLEEP_TIME);
        
        [moc deleteObject:todo];
        [moc deleteObject:category];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *saveError) {
            if (saveError != nil) {
                DLog(@"Error userInfo is %@", [saveError userInfo]);
                [saveError shouldBeNil];
            }
        }];
        
        sleep(SLEEP_TIME);
    });
});

describe(@"Updating existing object relationship fields to nil", ^{
    __block NSManagedObjectContext *moc = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block Person *person = nil;
    __block Superpower *superpower = nil;
    __block NSManagedObject *interest = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
    });
    it(@"passes for one-to-one", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // create person and superpower
        person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person assignObjectId];
        
        superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
        [superpower assignObjectId];
        
        // save
        NSError *error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        // set relationship and save
        [person setValue:superpower forKey:@"superpower"];
        
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        // set relationship to nil and save
        [person setValue:nil forKey:@"superpower"];
        
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        // delete objects and save
        [moc deleteObject:person];
        [moc deleteObject:superpower];
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
    });
    it(@"passes for one-to-many", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // create person and superpower
        person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person assignObjectId];
        
        interest = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
        [interest assignObjectId];
        
        // save
        NSError *error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        // set relationship and save
        [person setValue:[NSSet setWithObject:interest] forKey:@"interests"];
        
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        // set relationship to nil and save
        [person setValue:nil forKey:@"interests"];
        
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        // delete objects and save
        [moc deleteObject:person];
        [moc deleteObject:interest];
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
    });
});

describe(@"can update a field to null", ^{
    __block NSManagedObjectContext *moc = nil;
    __block Person *person = nil;
    __block Superpower *superpower = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        person = nil;
        superpower = nil;
    });
    it(@"updates", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person assignObjectId];
        [person setValue:[NSNumber numberWithInt:3] forKey:@"armor_class"];
        
        // save
        NSError *error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        [person setValue:nil forKey:@"armor_class"];
        
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        // delete objects and save
        [moc deleteObject:person];
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }

        sleep(SLEEP_TIME);
        
    });
    it(@"updates with relationships, too", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person assignObjectId];
        [person setValue:[NSNumber numberWithInt:3] forKey:@"armor_class"];
        
        superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
        [superpower assignObjectId];
        
        // save
        NSError *error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        // set relationship and save
        [person setValue:superpower forKey:@"superpower"];
        [person setValue:nil forKey:@"armor_class"];
        
        
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
        
        error = nil;
        
        // delete objects and save
        [moc deleteObject:person];
        [moc deleteObject:superpower];
        error = nil;
        if (![moc saveAndWait:&error]) {
            DLog(@"There was an error! %@", error);
            [error shouldBeNil];
        }
        else {
            DLog(@"Saved");
        }
        
        sleep(SLEEP_TIME);
    });
    
});


describe(@"Delete propagation with Cascade Rule", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        //SM_CORE_DATA_DEBUG = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        testProperties = nil;
        SM_CACHE_ENABLED = NO;
    });
    it(@"properly propagates on standard delete online", ^{
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1 assignObjectId];
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo2 assignObjectId];
        
        [person setValue:[NSSet setWithObjects:todo1, todo2, nil] forKey:@"todos"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        sleep(SLEEP_TIME);
                
        // Check cache map
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[lcMapResults objectForKey:@"Person"] should] haveCountOf:1];
        [[[lcMapResults objectForKey:@"Todo"] should] haveCountOf:2];
        
        // Delete person
        [testProperties.moc deleteObject:person];
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        sleep(SLEEP_TIME);
        
                
        lcMapResults = nil;
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:0];
    });
    it(@"properly propagates on standard delete offline", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1 assignObjectId];
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo2 assignObjectId];
        
        [person setValue:[NSSet setWithObjects:todo1, todo2, nil] forKey:@"todos"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        // Check cache map
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[lcMapResults objectForKey:@"Person"] should] haveCountOf:1];
        [[[lcMapResults objectForKey:@"Todo"] should] haveCountOf:2];
        
        // Check dirty queue
        __block NSDictionary *dqResults = nil;
        NSURL *dqURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:testProperties.client.publicKey];
        dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
        
        [dqResults shouldNotBeNil];
        [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:3];
        [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];
        
        // Delete person
        [testProperties.moc deleteObject:person];
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        lcMapResults = nil;
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:0];
        
        dqResults = nil;
        dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
        
        [dqResults shouldNotBeNil];
        [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];

    });
    it(@"properly propagates on standard delete offline, insert+update", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1 assignObjectId];
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo2 assignObjectId];
        
        [person setValue:[NSSet setWithObjects:todo1, todo2, nil] forKey:@"todos"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        // Check cache map
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[lcMapResults objectForKey:@"Person"] should] haveCountOf:1];
        [[[lcMapResults objectForKey:@"Todo"] should] haveCountOf:2];
        
        // Check dirty queue
        __block NSDictionary *dqResults = nil;
        NSURL *dqURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:testProperties.client.publicKey];
        dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
        
        [dqResults shouldNotBeNil];
        [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:3];
        [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];
        
        // Update object
        [person setValue:@"Person" forKey:@"first_name"];
        
        // Check cache map
        lcMapResults = nil;
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[lcMapResults objectForKey:@"Person"] should] haveCountOf:1];
        [[[lcMapResults objectForKey:@"Todo"] should] haveCountOf:2];
        
        // Check dirty queue
        dqResults = nil;
        dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
        
        [dqResults shouldNotBeNil];
        [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:3];
        [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];
        
        // Delete person
        [testProperties.moc deleteObject:person];
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        lcMapResults = nil;
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:0];
        
        dqResults = nil;
        dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
        
        [dqResults shouldNotBeNil];
        [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];
        
    });
});
describe(@"delete propagates on manual purge", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        NSError *error = nil;
        NSArray *personResults = [testProperties.moc executeFetchRequestAndWait:personFetch error:&error];
        [error shouldBeNil];
        [personResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        SM_CACHE_ENABLED = NO;
    });
    it(@"properly propagates on purge by cache ID, online", ^{
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person setValue:@"1234" forKey:[person primaryKeyField]];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1 setValue:@"1234" forKey:[todo1 primaryKeyField]];
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo2 setValue:@"5678" forKey:[todo2 primaryKeyField]];
        
        [person setValue:[NSSet setWithObjects:todo1, todo2, nil] forKey:@"todos"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        // Check cache map
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[lcMapResults objectForKey:@"Person"] should] haveCountOf:1];
        [[[lcMapResults objectForKey:@"Todo"] should] haveCountOf:2];
        
        // Delete person
        [testProperties.cds purgeCacheOfObjectsWithEntityName:@"Person"];
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_enter(group);
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
        dispatch_after(time, queue, ^{
            lcMapResults = nil;
            lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
            [lcMapResults shouldNotBeNil];
            [[lcMapResults should] haveCountOf:0];
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"properly propagates on purge by cache ID, offline", ^{
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person setValue:@"1234" forKey:[person primaryKeyField]];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1 setValue:@"1234" forKey:[todo1 primaryKeyField]];
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo2 setValue:@"5678" forKey:[todo2 primaryKeyField]];
        
        [person setValue:[NSSet setWithObjects:todo1, todo2, nil] forKey:@"todos"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        // Check cache map
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[lcMapResults objectForKey:@"Person"] should] haveCountOf:1];
        [[[lcMapResults objectForKey:@"Todo"] should] haveCountOf:2];
        
        // Check dirty queue
        __block NSDictionary *dqResults = nil;
        NSURL *dqURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:testProperties.client.publicKey];
        dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
        
        [dqResults shouldNotBeNil];
        [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:3];
        [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];
        
        // Delete person
        [testProperties.cds purgeCacheOfObjectsWithEntityName:@"Person"];
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_enter(group);
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
        dispatch_after(time, queue, ^{
            lcMapResults = nil;
            lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
            [lcMapResults shouldNotBeNil];
            [[lcMapResults should] haveCountOf:0];
            
            // Check dirty queue
            dqResults = nil;
            dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
            
            [dqResults shouldNotBeNil];
            [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:0];
            [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
            [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"properly propagates on purge by stackmob info, online", ^{
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person setValue:@"1234" forKey:[person primaryKeyField]];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1 setValue:@"1234" forKey:[todo1 primaryKeyField]];
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo2 setValue:@"5678" forKey:[todo2 primaryKeyField]];
        
        [person setValue:[NSSet setWithObjects:todo1, todo2, nil] forKey:@"todos"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        // Check cache map
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[lcMapResults objectForKey:@"Person"] should] haveCountOf:1];
        [[[lcMapResults objectForKey:@"Todo"] should] haveCountOf:2];
        
        // Delete person
        [testProperties.cds purgeCacheOfManagedObjectID:[person objectID]];
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_enter(group);
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
        dispatch_after(time, queue, ^{
            lcMapResults = nil;
            lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
            [lcMapResults shouldNotBeNil];
            [[lcMapResults should] haveCountOf:0];
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"properly propagates on purge by stackmob info, offline", ^{
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person setValue:@"1234" forKey:[person primaryKeyField]];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1 setValue:@"1234" forKey:[todo1 primaryKeyField]];
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo2 setValue:@"5678" forKey:[todo2 primaryKeyField]];
        
        [person setValue:[NSSet setWithObjects:todo1, todo2, nil] forKey:@"todos"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        // Check cache map
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[lcMapResults objectForKey:@"Person"] should] haveCountOf:1];
        [[[lcMapResults objectForKey:@"Todo"] should] haveCountOf:2];
        
        // Check dirty queue
        __block NSDictionary *dqResults = nil;
        NSURL *dqURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:testProperties.client.publicKey];
        dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
        
        [dqResults shouldNotBeNil];
        [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:3];
        [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
        [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];
        
        // Delete person
        [testProperties.cds purgeCacheOfManagedObjectID:[person objectID]];
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_enter(group);
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
        dispatch_after(time, queue, ^{
            lcMapResults = nil;
            lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
            [lcMapResults shouldNotBeNil];
            [[lcMapResults should] haveCountOf:0];
            
            // Check dirty queue
            dqResults = nil;
            dqResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dqURL path]];
            
            [dqResults shouldNotBeNil];
            [[[dqResults objectForKey:@"SMDirtyInsertedObjectKeys"] should] haveCountOf:0];
            [[[dqResults objectForKey:@"SMDirtyUpdatedObjectKeys"] should] haveCountOf:0];
            [[[dqResults objectForKey:@"SMDirtyDeletedObjectKeys"] should] haveCountOf:0];
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });

});

SPEC_END
