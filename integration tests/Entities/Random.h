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
#import <CoreData/CoreData.h>


@interface Random : NSManagedObject

@property (nonatomic, retain) NSNumber * done;
@property (nonatomic, retain) id geopoint;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * randomId;
@property (nonatomic, retain) NSString * server_id;
@property (nonatomic, retain) NSDate * time;
@property (nonatomic, retain) NSNumber * yearBorn;
@property (nonatomic, retain) NSDate * createddate;
@property (nonatomic, retain) NSDate * lastmoddate;

@end
