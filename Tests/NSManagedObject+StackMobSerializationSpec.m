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
#import "StackMob.h"

@interface StackMobSerializationSpecUser : SMUserManagedObject

@end

@implementation StackMobSerializationSpecUser

@end

SPEC_BEGIN(NSManagedObject_StackMobSerializationSpec)

/*
describe(@"SMDictionarySerialiazation with cachemap entries", ^{
    
    "relationship_team" =     {
        
        "relationship_league" =         {
            "app_creation_date" = 1376511925959;
            fouls = 6;
            "full_timeouts" = 1;
            "game_length" = 480;
            "is_archived" = 0;
            "is_quarters" = 0;
            "league_id" = "5FA82460-0E2B-4671-889A-F3E3ADA72BEA";
            "maximum_games_allowed" = 100;
            "maximum_teams_allowed" = 25;
            name = matt6league;
            "relationship_games" =             (
            );
            "relationship_owner" =             {
                "age_string" = "High School";
                city = Sf;
                email = "matt@stackmob.com";
                "first_name" = Matt6;
                "has_logged_in" = 0;
                "hm_credit_money" = 20;
                "is_active" = 0;
                "last_name" = Matt6;
                "maximum_amount_of_leagues" = 1;
                "relationship_leagues" =                 (
                                                          1
                                                          );
                "sign_up_date" = 1376511899881;
                username = matt6;
            };
            "relationship_teams" =             (
                                                1
                                                );
            "team_deletions_remaining" = 3;
            "thirty_second_timeouts" = 32;
        };
        "relationship_players" =         (
                                          5,
                                          3,
                                          4,
                                          1,
                                          2
                                          );
        "relationship_season_lineups" =         (
        );
        "relationship_team_stats" =         (
        );
        "roster_adjustments_remaining" = 25;
        season = 1376512020636;
        "season_total_loss_margin" = 0;
        "season_total_victory_margin" = 0;
        "team_city" = Sf;
        "team_color" = "0.203922 0.596078 0.858824 1";
        "team_id" = "B140C32B-E7C4-417C-B562-F7FC93194151";
        "team_name" = matt61;
        wins = 0;
    };

    
    NSDictionary *preDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1], "first_name", [NSNumber numberWithBool:YES], "is_active", [NSNull null], "notes", @"6CED52DE-7D90-4942-8AE4-8076EEBDB61C", "player_id", @"PG", @"position", [NSArray array], @"relationship_linups", [NSArray array], @"relationship_player_stats", [NSDictionary dictionaryWithObjectsAndKeys:@"Matt6", @"head_coach", nil], @"relationship_teams", nil];
    
});
     */

describe(@"NSManagedObject_StackMobSerialization", ^{
    describe(@"-assignObjectId", ^{
        context(@"given an object with an id field matching its entity name", ^{
            __block NSManagedObject *map = nil;
            beforeEach(^{
                NSEntityDescription *mapEntity = [[NSEntityDescription alloc] init];
                [mapEntity setName:@"Map"];
                [mapEntity setManagedObjectClassName:@"Map"];
                
                NSAttributeDescription *objectId = [[NSAttributeDescription alloc] init];
                [objectId setName:@"map_id"];
                [objectId setAttributeType:NSStringAttributeType];
                [objectId setOptional:YES];
                
                [mapEntity setProperties:[NSArray arrayWithObject:objectId]];
                
                map = [[NSManagedObject alloc] initWithEntity:mapEntity insertIntoManagedObjectContext:nil];
            });
            context(@"when the object does not have an id", ^{
                it(@"creates a new object id", ^{
                    [[map assignObjectId] shouldNotBeNil];
                    [[map valueForKey:@"map_id"] shouldNotBeNil];
                });
            });
        });
        context(@"given an object without an identifiable id attribute", ^{
            __block NSManagedObject *model = nil;
            beforeEach(^{
                NSEntityDescription *incompleteEntity = [[NSEntityDescription alloc] init];
                [incompleteEntity setName:@"Incomplete"];
                [incompleteEntity setManagedObjectClassName:@"Incomplete"];
                
                model = [[NSManagedObject alloc] initWithEntity:incompleteEntity insertIntoManagedObjectContext:nil];
            });
            it(@"fails loudly", ^{
                [[theBlock(^{
                    [model assignObjectId];
                }) should] raise];
            });
        });
        context(@"given an object which defines a custom id attribute", ^{
            __block StackMobSerializationSpecUser *user = nil;
            __block SMClient *client = nil;
            beforeEach(^{
                client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
                NSEntityDescription *userEntity = [[NSEntityDescription alloc] init];
                [userEntity setName:@"User"];
                [userEntity setManagedObjectClassName:@"StackMobSerializationSpecUser"];
                
                NSAttributeDescription *username = [[NSAttributeDescription alloc] init];
                [username setName:@"username"];
                [username setAttributeType:NSStringAttributeType];
                [username setOptional:NO];
                
                [userEntity setProperties:[NSArray arrayWithObjects:username, nil]];
                
                user = [[StackMobSerializationSpecUser alloc] initWithEntity:userEntity insertIntoManagedObjectContext:nil];
            });
            context(@"when the object does not have an id", ^{
                it(@"creates a new object id", ^{
                    [[user assignObjectId] shouldNotBeNil];
                });
            });
        });
    });
    
    context(@"given a complex object graph", ^{
        __block NSDate *now = nil;
        __block NSManagedObject *hooman = nil;
        __block NSManagedObject *iMadeYouACookie = nil;
        __block NSManagedObject *kittenPhoto = nil;
        __block NSManagedObject *cookieTag = nil;
        __block NSManagedObject *foodTag = nil;
        beforeEach(^{
            
            //        
            //             ========
            //     --------| User |
            //     |     1 ========
            //     |          |1
            //     |          |
            //     |          |* lolcats
            //     |      ==========
            //     |      | LolCat |
            //     |      ==========
            //     |        |1  |1
            //     |        |   |
            //     |    -----   -----
            //     |    |           |
            //     |    |1 photo    |* tags
            //     | =========    =======
            //     | | Photo |    | Tag |
            //     | =========    =======
            //     |    |1
            //     ------ photographer
            //        
            
            now = [NSDate date];
            
            NSEntityDescription *lolCatEntity = [[NSEntityDescription alloc] init];
            [lolCatEntity setName:@"LolCat"];
            [lolCatEntity setManagedObjectClassName:@"LolCat"];
            
            //users
            NSEntityDescription *userEntity = [[NSEntityDescription alloc] init];
            [userEntity setName:@"User"];
            [userEntity setManagedObjectClassName:@"User"];
            
            NSAttributeDescription *userId = [[NSAttributeDescription alloc] init];
            [userId setName:@"user_id"];
            [userId setAttributeType:NSStringAttributeType];
            [userId setOptional:YES];
            
            NSRelationshipDescription *lolcats = [[NSRelationshipDescription alloc] init];
            [lolcats setName:@"lolcats"];
            [lolcats setDestinationEntity:lolCatEntity];
            
            [userEntity setProperties:[NSArray arrayWithObjects:userId, lolcats, nil]];
            
            //photos
            NSEntityDescription *photoEntity = [[NSEntityDescription alloc] init];
            [photoEntity setName:@"Photo"];
            [photoEntity setManagedObjectClassName:@"Photo"];
            
            NSAttributeDescription *photoId = [[NSAttributeDescription alloc] init];
            [photoId setName:@"photo_id"];
            [photoId setAttributeType:NSStringAttributeType];
            [photoId setOptional:YES];
            
            NSAttributeDescription *photoURL = [[NSAttributeDescription alloc] init];
            [photoURL setName:@"url"];
            [photoURL setAttributeType:NSStringAttributeType];
            [photoURL setOptional:NO];
            
            NSRelationshipDescription *photographer = [[NSRelationshipDescription alloc] init];
            [photographer setName:@"photographer"];
            [photographer setDestinationEntity:userEntity];
            [photographer setMaxCount:1];
            
            [photoEntity setProperties:[NSArray arrayWithObjects:photoId, photoURL, photographer, nil]];
            
            //tags
            NSEntityDescription *tagEntity = [[NSEntityDescription alloc] init];
            [tagEntity setName:@"Tag"];
            [tagEntity setManagedObjectClassName:@"Tag"];
            
            NSAttributeDescription *tagId = [[NSAttributeDescription alloc] init];
            [tagId setName:@"tag_id"];
            [tagId setAttributeType:NSStringAttributeType];
            [tagId setOptional:YES];
            
            [tagEntity setProperties:[NSArray arrayWithObjects:tagId, nil]];
            
            //lolcats
            NSAttributeDescription *objectId = [[NSAttributeDescription alloc] init];
            [objectId setName:@"lolcat_id"];
            [objectId setAttributeType:NSStringAttributeType];
            [objectId setOptional:YES];
            
            NSAttributeDescription *name = [[NSAttributeDescription alloc] init];
            [name setName:@"name"];
            [name setAttributeType:NSStringAttributeType];
            [name setOptional:NO];
            [name setDefaultValue:@"CAT"];
            
            NSAttributeDescription *caption = [[NSAttributeDescription alloc] init];
            [caption setName:@"caption"];
            [caption setAttributeType:NSStringAttributeType];
            [caption setOptional:NO];
            
            NSAttributeDescription *subcaption = [[NSAttributeDescription alloc] init];
            [subcaption setName:@"subcaption"];
            [subcaption setAttributeType:NSStringAttributeType];
            [subcaption setOptional:YES];
            
            NSAttributeDescription *captionedAt = [[NSAttributeDescription alloc] init];
            [captionedAt setName:@"captionedAt"];
            [captionedAt setAttributeType:NSDateAttributeType];
            [captionedAt setOptional:NO];
            
            NSAttributeDescription *transient = [[NSAttributeDescription alloc] init];
            [transient setName:@"transient"];
            [transient setAttributeType:NSUndefinedAttributeType];
            [transient setOptional:YES];
            
            NSRelationshipDescription *photo = [[NSRelationshipDescription alloc] init];
            [photo setName:@"photo"];
            [photo setDestinationEntity:photoEntity];
            [photo setMaxCount:1];
            
            NSRelationshipDescription *owner = [[NSRelationshipDescription alloc] init];
            [owner setName:@"owner"];
            [owner setDestinationEntity:userEntity];
            [owner setMaxCount:1];
            
            NSRelationshipDescription *tags = [[NSRelationshipDescription alloc] init];
            [tags setName:@"tags"];
            [tags setDestinationEntity:tagEntity];
            
            [lolCatEntity setProperties:[NSArray arrayWithObjects:objectId, name, caption, subcaption, captionedAt, transient, photo, owner, tags, nil]];
            
            //construct the managed object model
            NSManagedObjectModel *objectModel = [[NSManagedObjectModel alloc] init];
            
            [objectModel setEntities:[NSArray arrayWithObjects:photoEntity, lolCatEntity, nil]];
            
            hooman = [[NSManagedObject alloc] initWithEntity:userEntity insertIntoManagedObjectContext:nil];
            [hooman setValue:@"hooman" forKey:@"user_id"];
            iMadeYouACookie = [[NSManagedObject alloc] initWithEntity:lolCatEntity insertIntoManagedObjectContext:nil];
            kittenPhoto = [[NSManagedObject alloc] initWithEntity:photoEntity insertIntoManagedObjectContext:nil];
            cookieTag = [[NSManagedObject alloc] initWithEntity:tagEntity insertIntoManagedObjectContext:nil];
            [cookieTag setValue:[cookieTag assignObjectId] forKey:@"tag_id"];
            foodTag = [[NSManagedObject alloc] initWithEntity:tagEntity insertIntoManagedObjectContext:nil];
            [foodTag setValue:[foodTag assignObjectId] forKey:@"tag_id"];
            
            [kittenPhoto setValue:@"http://cutethings.example/kitten" forKey:@"url"];
            [kittenPhoto setValue:hooman forKey:@"photographer"];
            [kittenPhoto setValue:[kittenPhoto assignObjectId] forKey:@"photo_id"];
            
            [iMadeYouACookie setValue:kittenPhoto forKey:@"photo"];        
            [iMadeYouACookie setValue:@"I MADE YOU A COOKIE, BUT I EATED IT" forKey:@"caption"];
            [iMadeYouACookie setValue:now forKey:@"captionedAt"];
            [iMadeYouACookie setValue:[iMadeYouACookie assignObjectId] forKey:@"lolcat_id"];
            NSMutableSet *tagSet = [iMadeYouACookie mutableSetValueForKey:@"tags"];
            [tagSet addObject:cookieTag];
            [tagSet addObject:foodTag];
            
            NSMutableSet *lolcatsSet = [hooman mutableSetValueForKey:@"lolcats"];
            [lolcatsSet addObject:iMadeYouACookie];
        });
        
        describe(@"-SMDictionarySerialization:", ^{
            describe(@"properties", ^{
                __block NSDictionary *dictionary = nil;
                beforeEach(^{
                    dictionary = [[iMadeYouACookie SMDictionarySerialization:NO sendLocalTimestamps:NO cacheMap:nil] objectForKey:@"SerializedDict"];
                });
                /*
                it(@"includes nil properties", ^{
                    [[dictionary should] haveValue:[NSNull null] forKey:@"subcaption"];
                });
                 */
                it(@"assigns object ids", ^{
                    [[dictionary objectForKey:@"lolcat_id"] shouldNotBeNil];
                });
                it(@"does not include transient properties in the response", ^{
                    [[dictionary objectForKey:@"transient"] shouldBeNil];
                });        
            });
            describe(@"relationships", ^{
                __block NSDictionary *dictionary = nil;
                beforeEach(^{
                    dictionary = [[iMadeYouACookie SMDictionarySerialization:NO sendLocalTimestamps:NO cacheMap:nil] objectForKey:@"SerializedDict"];
                });
                /*
                it(@"includes nil relationships", ^{
                    [[[dictionary valueForKey:@"owner"] should] equal:[NSNull null]];
                });
                 */
                describe(@"circular relationships", ^{
                    it(@"survives circular references", ^{
                        [[[[[[hooman valueForKey:@"lolcats"] anyObject] valueForKey:@"photo"] valueForKey:@"photographer"] should] equal:hooman];
                        [[hooman SMDictionarySerialization:NO sendLocalTimestamps:NO cacheMap:nil] shouldNotBeNil];
                    });
                });
            });
        });
    });
    
});

describe(@"-userPrimaryKeyField", ^{
    __block NSEntityDescription *theEntity = nil;
    __block NSManagedObject *theObject = nil;
    context(@"With an entity that has a StackMob-like userPrimaryKeyField", ^{
        beforeEach(^{
            theEntity = [[NSEntityDescription alloc] init];
            [theEntity setName:@"Entity"];
            [theEntity setManagedObjectClassName:@"Entity"];
            
            NSAttributeDescription *entity_id = [[NSAttributeDescription alloc] init];
            [entity_id setName:@"entity_id"];
            [entity_id setAttributeType:NSStringAttributeType];
            
            NSAttributeDescription *name = [[NSAttributeDescription alloc] init];
            [name setName:@"name"];
            [name setAttributeType:NSStringAttributeType];
            
            [theEntity setProperties:[NSArray arrayWithObjects:entity_id, name, nil]];
            
            //construct the managed object model
            NSManagedObjectModel *objectModel = [[NSManagedObjectModel alloc] init];
            
            [objectModel setEntities:[NSArray arrayWithObjects:theEntity, nil]];
            
            theObject = [[NSManagedObject alloc] initWithEntity:theEntity insertIntoManagedObjectContext:nil];
        });
        it(@"Should return entity_id for userPrimaryKeyField", ^{
            [[[theObject primaryKeyField] should] equal:@"entity_id"];
        });
    });
    context(@"With an entity that has a CoreData-like userPrimaryKeyField", ^{
        beforeEach(^{
            theEntity = [[NSEntityDescription alloc] init];
            [theEntity setName:@"Entity"];
            [theEntity setManagedObjectClassName:@"Entity"];
            
            NSAttributeDescription *entityId = [[NSAttributeDescription alloc] init];
            [entityId setName:@"entityId"];
            [entityId setAttributeType:NSStringAttributeType];
            
            NSAttributeDescription *name = [[NSAttributeDescription alloc] init];
            [name setName:@"name"];
            [name setAttributeType:NSStringAttributeType];
            
            [theEntity setProperties:[NSArray arrayWithObjects:entityId, name, nil]];
            
            //construct the managed object model
            NSManagedObjectModel *objectModel = [[NSManagedObjectModel alloc] init];
            
            [objectModel setEntities:[NSArray arrayWithObjects:theEntity, nil]];
            
            theObject = [[NSManagedObject alloc] initWithEntity:theEntity insertIntoManagedObjectContext:nil];

        });
        it(@"Should return entityId for userPrimaryKeyField", ^{
            [[[theObject primaryKeyField] should] equal:@"entityId"];
        });
    });
    context(@"With an entity that adopts the SMModel protocol", ^{
        __block StackMobSerializationSpecUser *user = nil;
        __block SMClient *client = nil;
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
            NSEntityDescription *userEntity = [[NSEntityDescription alloc] init];
            [userEntity setName:@"User"];
            [userEntity setManagedObjectClassName:@"StackMobSerializationSpecUser"];
            
            NSAttributeDescription *username = [[NSAttributeDescription alloc] init];
            [username setName:@"username"];
            [username setAttributeType:NSStringAttributeType];
            [username setOptional:NO];
            
            [userEntity setProperties:[NSArray arrayWithObjects:username, nil]];
            
            user = [[StackMobSerializationSpecUser alloc] initWithEntity:userEntity insertIntoManagedObjectContext:nil];
        });
        it(@"Should return entityId for userPrimaryKeyField", ^{
            [[[user primaryKeyField] should] equal:@"username"];
        });
    });
    
});

describe(@"sendLocalTimestamps", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        [SMClient setDefaultClient:client];
        
        // CDS
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        
        // MOC
        moc = [cds contextForCurrentThread];
    });
    afterEach(^{
        
    });
    it(@"Does not include TS for full objects, no timestamps", ^{
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todo setValue:@"title" forKey:@"title"];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:[NSDate date] forKey:@"createddate"];
        [todo setValue:[NSDate date] forKey:@"lastmoddate"];
        
        NSDictionary *serializedDict = [todo SMDictionarySerialization:YES sendLocalTimestamps:NO cacheMap:nil];
        [[theValue([[[serializedDict objectForKey:@"SerializedDict"] allKeys] indexOfObject:@"createddate"]) should] equal:theValue(NSNotFound)];
        [[theValue([[[serializedDict objectForKey:@"SerializedDict"] allKeys] indexOfObject:@"lastmoddate"]) should] equal:theValue(NSNotFound)];
    });
    it(@"Does include TS for full objects, yes timestamps", ^{
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todo setValue:@"title" forKey:@"title"];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:[NSDate date] forKey:@"createddate"];
        [todo setValue:[NSDate date] forKey:@"lastmoddate"];
        
        NSDictionary *serializedDict = [todo SMDictionarySerialization:YES sendLocalTimestamps:YES cacheMap:nil];
        [[theValue([[[serializedDict objectForKey:@"SerializedDict"] allKeys] indexOfObject:@"createddate"]) shouldNot] equal:theValue(NSNotFound)];
        [[theValue([[[serializedDict objectForKey:@"SerializedDict"] allKeys] indexOfObject:@"lastmoddate"]) shouldNot] equal:theValue(NSNotFound)];
    });
    it(@"Does include TS for no full objects, no timestamps", ^{
        // This scenario for online (no serialize full objects)
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todo setValue:@"title" forKey:@"title"];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:[NSDate date] forKey:@"createddate"];
        [todo setValue:[NSDate date] forKey:@"lastmoddate"];
        
        NSDictionary *serializedDict = [todo SMDictionarySerialization:NO sendLocalTimestamps:NO cacheMap:nil];
        [[theValue([[[serializedDict objectForKey:@"SerializedDict"] allKeys] indexOfObject:@"createddate"]) shouldNot] equal:theValue(NSNotFound)];
        [[theValue([[[serializedDict objectForKey:@"SerializedDict"] allKeys] indexOfObject:@"lastmoddate"]) shouldNot] equal:theValue(NSNotFound)];
    });
    it(@"Does not include TS for no full objects, yes timestamps", ^{
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todo setValue:@"title" forKey:@"title"];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:[NSDate date] forKey:@"createddate"];
        [todo setValue:[NSDate date] forKey:@"lastmoddate"];
        
        NSDictionary *serializedDict = [todo SMDictionarySerialization:NO sendLocalTimestamps:YES cacheMap:nil];
        [[theValue([[[serializedDict objectForKey:@"SerializedDict"] allKeys] indexOfObject:@"createddate"]) shouldNot] equal:theValue(NSNotFound)];
        [[theValue([[[serializedDict objectForKey:@"SerializedDict"] allKeys] indexOfObject:@"lastmoddate"]) shouldNot] equal:theValue(NSNotFound)];
    });
});


SPEC_END
