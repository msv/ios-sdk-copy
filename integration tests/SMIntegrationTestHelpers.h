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

#import <Foundation/Foundation.h>

#import "StackMob.h"
#import "StackMobPush.h"
#import "Synchronization.h"

#define SM_TEST_API_VERSION @"0"
#define SM_TEST_API_BASEURL @"http://api.stackmob.com"
#define TEST_CUSTOM_CODE 0
#define SLEEP_TIME 3
#define CHECK_RECEIVE_SELECTORS 0 

#define DLog(fmt, ...) NSLog((@"Performing %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface NSURLRequest(Private)
+(void)setAllowsAnyHTTPSCertificate:(BOOL)inAllow forHost:(NSString *)inHost;
@end

@interface SMIntegrationTestHelpers : NSObject

+ (SMClient *)defaultClient;
+ (SMPushClient *)defaultPushClient;
+ (SMDataStore *)dataStore;

+ (NSDictionary *)loadFixturesNamed:(NSArray *)fixtureNames;
+ (void)destroyAllForFixturesNamed:(NSArray *)fixtureNames;

+ (NSArray *)loadFixture:(NSString *)fixtureName; 
+ (void)destroyFixture:(NSString *)fixtureName;

+ (BOOL)createUser:(NSString *)username password:(NSString *)password dataStore:(SMDataStore *)dataStore;
+ (BOOL)deleteUser:(NSString *)username dataStore:(SMDataStore *)dataStore;

@end
