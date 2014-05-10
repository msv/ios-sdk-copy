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
#import "SMUserSession.h"
#import "SMOAuth2Client.h"

// TODO ADD TEST CASE THAT PORT IS SIGNED CORRECTLY

SPEC_BEGIN(SMURLRedirectSpec)

describe(@"init with one host and port, then init with different host and same port", ^{
    __block SMClient *client = nil;
    __block NSString *defaultHostsPath = nil;
    __block NSString *redirectedHostsPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        defaultHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        redirectedHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"should save the new host/port to current and default values", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" httpHost:@"api.staging.stackmob.com:8080" httpsHost:@"api.staging.stackmob.com:4343" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        NSDictionary *defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        if ([[defaultHosts objectForKey:@"http"] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[defaultHosts objectForKey:@"https"] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!redirectedHosts) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // New host
        client = [[SMClient alloc] initWithAPIVersion:@"0" httpHost:@"random.staging.stackmob.com:8080" httpsHost:@"securerandom.staging.stackmob.com:4343" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"random.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"securerandom.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        if ([[defaultHosts objectForKey:@"http"] isEqualToString:@"random.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[defaultHosts objectForKey:@"https"] isEqualToString:@"securerandom.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!redirectedHosts) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        
    });
});

describe(@"init with one host and port, then init with same host and different port", ^{
    __block SMClient *client = nil;
    __block NSString *defaultHostsPath = nil;
    __block NSString *redirectedHostsPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        defaultHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        redirectedHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"should save the new host/port to current and default values", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" httpHost:@"api.staging.stackmob.com:8080" httpsHost:@"api.staging.stackmob.com:4343" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        NSDictionary *defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        if ([[defaultHosts objectForKey:@"http"] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[defaultHosts objectForKey:@"https"] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!redirectedHosts) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // New host
        client = [[SMClient alloc] initWithAPIVersion:@"0" httpHost:@"api.staging.stackmob.com:4567" httpsHost:@"api.staging.stackmob.com:3434" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com:4567"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com:3434"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        if ([[defaultHosts objectForKey:@"http"] isEqualToString:@"api.staging.stackmob.com:4567"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[defaultHosts objectForKey:@"https"] isEqualToString:@"api.staging.stackmob.com:3434"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!redirectedHosts) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        
    });
});

describe(@"init with one host, then init again with different host", ^{
    __block SMClient *client = nil;
    __block NSString *defaultHostsPath = nil;
    __block NSString *redirectedHostsPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        defaultHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        redirectedHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"should save the new host to current and default values", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        NSDictionary *defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        if ([[defaultHosts objectForKey:@"http"] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[defaultHosts objectForKey:@"https"] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!redirectedHosts) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // New host
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"random.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"random.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"random.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        if ([[defaultHosts objectForKey:@"http"] isEqualToString:@"random.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[defaultHosts objectForKey:@"https"] isEqualToString:@"random.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!redirectedHosts) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        
    });
});

describe(@"init with one host/port, then redirect to different port, same host", ^{
    __block SMClient *client = nil;
    __block NSString *defaultHostsPath = nil;
    __block NSString *redirectedHostsPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        defaultHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        redirectedHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"should update current and defaults to new host, and wipe redirects", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com:8080" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // redirect http
        [client setRedirectedAPIHost:@"api.staging.stackmob.com:4343" port:nil scheme:@"http" permanent:YES];
        
        // redirect https
        [client setRedirectedAPIHost:@"api.staging.stackmob.com:4343" port:nil scheme:@"https" permanent:YES];
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // init again
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com:8080" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        NSDictionary *defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        if ([[defaultHosts objectForKey:@"http"] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[defaultHosts objectForKey:@"https"] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        //redirect
        
        if ([[redirectedHosts objectForKey:@"http"] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[redirectedHosts objectForKey:@"https"] isEqualToString:@"api.staging.stackmob.com:4343"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
    });
});

describe(@"init with one host, get a redirect, init again with different host", ^{
    __block SMClient *client = nil;
    __block NSString *defaultHostsPath = nil;
    __block NSString *redirectedHostsPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        defaultHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        redirectedHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"should update current and defaults to new host, and wipe redirects", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // redirect http
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"http" permanent:YES];
        
        // redirect https
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"https" permanent:YES];
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // init with new host
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"random.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        if ([[client.session getHttpHost] isEqualToString:@"random.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"random.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;

        NSDictionary *defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        if ([[defaultHosts objectForKey:@"http"] isEqualToString:@"random.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[defaultHosts objectForKey:@"https"] isEqualToString:@"random.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!redirectedHosts) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
    });
});

describe(@"init with one host, get a redirect, init again with same host", ^{
    __block SMClient *client = nil;
    __block NSString *defaultHostsPath = nil;
    __block NSString *redirectedHostsPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        defaultHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        redirectedHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"should keep the redirected host", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // redirect http
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"http" permanent:YES];
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // init again
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // redirect https
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"https" permanent:YES];
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // init again, should all be mattsmells
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
    });
});

describe(@"First time initializing client", ^{
    __block SMClient *client = nil;
    __block NSString *defaultHostsPath = nil;
    __block NSString *redirectedHostsPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        defaultHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        redirectedHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultHostsPath];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectedHostsPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"should update init in-memory values", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!client.session.regularOAuthClient.baseURL.port) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!client.session.secureOAuthClient.baseURL.port) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.tokenClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (!client.session.tokenClient.baseURL.port) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
    });
    it(@"should update default values", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        NSDictionary *defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        
        __block BOOL theValue = NO;
        
        if (defaultHosts) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([defaultHosts valueForKey:@"http"] && [[defaultHosts valueForKey:@"http"] isEqualToString:@"api.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([defaultHosts valueForKey:@"https"] && [[defaultHosts valueForKey:@"https"] isEqualToString:@"api.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
    });
    it(@"should not update redirect values", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        __block BOOL theValue = NO;
        
        if (!redirectedHosts) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        
    });
    it(@"should update init in-memory values, with port", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com:8080" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.regularOAuthClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:8080]]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.secureOAuthClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:8080]]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.tokenClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.tokenClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:8080]]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
    });
    it(@"should update default values, with port", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com:8080" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        NSDictionary *defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        
        __block BOOL theValue = NO;
        
        if (defaultHosts) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([defaultHosts valueForKey:@"http"] && [[defaultHosts valueForKey:@"http"] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([defaultHosts valueForKey:@"https"] && [[defaultHosts valueForKey:@"https"] isEqualToString:@"api.staging.stackmob.com:8080"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
    });
    it(@"should not update redirect values, with port", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com:8080" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        __block BOOL theValue = NO;
        
        if (!redirectedHosts) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        
    });
});

describe(@"initializing with one host, getting a permanent redirect, then updating the app with a new host, should update", ^{
    __block SMClient *client = nil;
    __block NSString *hostRedirectPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        hostRedirectPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"should clear the defaults and use the updated host", ^{
        
        // init client with api.staging
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL localValue = NO;
        
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // redirect client to mattsmells.staging
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"http" permanent:YES];
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"https" permanent:YES];
        
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // re-initialize client, should be mattsmells.staging
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // re-initialize client with new host, should be changed to that
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"mattreallysmells.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        if ([[client.session getHttpHost] isEqualToString:@"mattreallysmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattreallysmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
    });
});

describe(@"permanent redirect", ^{
    __block SMClient *client = nil;
    __block NSString *hostRedirectPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        publicKey = @"12345678-9123-4567-8912-345678912345";
        
        hostRedirectPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"persists the host to user defaults", ^{
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"http" permanent:YES];
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"https" permanent:YES];
        
        NSDictionary *host = [[NSUserDefaults standardUserDefaults] objectForKey:hostRedirectPath];
        
        BOOL localValue = NO;
        
        if ([[host objectForKey:@"http"] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[host objectForKey:@"https"] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.tokenClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
    });
    it(@"persists the port and host to user defaults, http", ^{
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:[NSNumber numberWithInt:4567] scheme:@"http" permanent:YES];
        
        NSDictionary *host = [[NSUserDefaults standardUserDefaults] objectForKey:hostRedirectPath];
        
        BOOL localValue = NO;
        
        if ([[host objectForKey:@"http"]isEqualToString:@"mattsmells.staging.stackmob.com:4567"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (![host objectForKey:@"https"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com:4567"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // scheme is http, regular oauth client should be updated
        if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"] && [client.session.regularOAuthClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:4567]]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // Secure oauth clients are untouched
        if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"] && !client.session.secureOAuthClient.baseURL.port) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.tokenClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"] && !client.session.tokenClient.baseURL.port) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
    });
    it(@"persists the port and host to user defaults, http", ^{
        [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:[NSNumber numberWithInt:4567] scheme:@"https" permanent:YES];
        
        NSDictionary *host = [[NSUserDefaults standardUserDefaults] objectForKey:hostRedirectPath];
        
        BOOL localValue = NO;
        
        if ([[host objectForKey:@"https"]isEqualToString:@"mattsmells.staging.stackmob.com:4567"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if (![host objectForKey:@"http"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattsmells.staging.stackmob.com:4567"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"api.staging.stackmob.com"]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // scheme is https, secure oauth client should be updated
        if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"] && [client.session.secureOAuthClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:4567]]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        if ([client.session.tokenClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"] && [client.session.tokenClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:4567]]) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
        
        // reg oauth clients are untouched
        if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"] && !client.session.regularOAuthClient.baseURL.port) {
            localValue = YES;
        }
        
        [[theValue(localValue) should] beYes];
        localValue = NO;
    });
});

describe(@"after permanent redirect", ^{
    __block SMClient *client = nil;
    __block NSString *hostRedirectPath = nil;
    __block NSString *publicKey = nil;
    beforeEach(^{
        publicKey = @"12345678-9123-4567-8912-345678912345";
        hostRedirectPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        
        [[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"mattsmells.staging.stackmob.com", @"http", @"mattsmells.staging.stackmob.com", @"https", nil] forKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"host is initialized with proper host", ^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL theValue = NO;
        
        if ([[client.session getHttpHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([[client.session getHttpsHost] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.tokenClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
    });
    it(@"with an http port assigned, client are initialized properly", ^{
        NSDictionary *newRedirect = [NSDictionary dictionaryWithObjectsAndKeys:@"mattsmells.staging.stackmob.com:4567", @"http", nil];
        [[NSUserDefaults standardUserDefaults] setObject:newRedirect forKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL theValue = NO;
        
        if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.regularOAuthClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:4567]]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.tokenClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if (!client.session.secureOAuthClient.baseURL.port && !client.session.tokenClient.baseURL.port) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        
    });
    it(@"with an https port assigned, client are initialized properly", ^{
        NSDictionary *newRedirect = [NSDictionary dictionaryWithObjectsAndKeys:@"mattsmells.staging.stackmob.com:7654", @"https", nil];
        [[NSUserDefaults standardUserDefaults] setObject:newRedirect forKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
        
        BOOL theValue = NO;
        
        if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"api.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.tokenClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.secureOAuthClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:7654]]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        if ([client.session.tokenClient.baseURL.port isEqualToNumber:[NSNumber numberWithInt:7654]]) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
        theValue = NO;
        
        theValue = NO;
        if (!client.session.regularOAuthClient.baseURL.port) {
            theValue = YES;
        }
        
        [[theValue(theValue) should] beYes];
    });
});

 describe(@"redirects with 302, then 301", ^{
     __block SMClient *client = nil;
     __block NSString *hostRedirectPath = nil;
     __block NSString *publicKey = nil;
     beforeEach(^{
         publicKey = @"12345678-9123-4567-8912-345678912345";
 
         hostRedirectPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
 
         [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
         [[NSUserDefaults standardUserDefaults] synchronize];
 
         client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
         [SMClient setDefaultClient:client];
     });
     afterEach(^{
         [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
         [[NSUserDefaults standardUserDefaults] synchronize];
     });
     it(@"should be persisted", ^{
         [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"http"permanent:NO];
         [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"https"permanent:NO];
 
         NSDictionary *host = [[NSUserDefaults standardUserDefaults] objectForKey:hostRedirectPath];
         BOOL hostIsNil = NO;
         if (!host) {
             hostIsNil = YES;
         }
         [[theValue(hostIsNil) should] beYes];
 
         // check local values
         BOOL localValue = NO;
 
 
         if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
             localValue = YES;
         }
 
         [[theValue(localValue) should] beYes];
         localValue = NO;
 
         if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
             localValue = YES;
         }
 
         [[theValue(localValue) should] beYes];
         localValue = NO;
 
         if ([client.session.tokenClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
             localValue = YES;
         }
 
         [[theValue(localValue) should] beYes];
         localValue = NO;
 
         // permanent redirect this time
         [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"http"permanent:YES];
         [client setRedirectedAPIHost:@"mattsmells.staging.stackmob.com" port:nil scheme:@"https"permanent:YES];
 
         host = [[NSUserDefaults standardUserDefaults] objectForKey:hostRedirectPath];
 
         localValue = NO;
 
         if ([[host objectForKey:@"http"] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
             localValue = YES;
         }
 
        [[theValue(localValue) should] beYes];
         localValue = NO;
         
         if ([[host objectForKey:@"https"] isEqualToString:@"mattsmells.staging.stackmob.com"]) {
             localValue = YES;
         }
         
         [[theValue(localValue) should] beYes];
         localValue = NO;
 
         if ([client.session.regularOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
             localValue = YES;
         }
 
         [[theValue(localValue) should] beYes];
         localValue = NO;
 
         if ([client.session.secureOAuthClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
             localValue = YES;
         }
 
         [[theValue(localValue) should] beYes];
         localValue = NO;
 
         if ([client.session.tokenClient.baseURL.host isEqualToString:@"mattsmells.staging.stackmob.com"]) {
             localValue = YES;
         }
 
         [[theValue(localValue) should] beYes];
         localValue = NO;
     });
 });



SPEC_END


