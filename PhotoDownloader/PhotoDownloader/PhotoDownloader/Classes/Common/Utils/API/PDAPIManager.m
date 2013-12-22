//
//  PDAPIManager.m
//  PhotoDownloader
//
//  Created by Kohei Tabata on 2013/12/21.
//  Copyright (c) 2013年 Kohei Tabata. All rights reserved.
//

#import "PDAPIManager.h"

#import "AFNetworkReachabilityManager.h"

@implementation PDAPIManager

+ (PDAPIManager *)sharedManager
{
    static PDAPIManager *_sharedManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.datamarket.azure.com/Bing/Search/"]];
    });
    return _sharedManager;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if (self  = [super initWithBaseURL:url])
    {
        self.requestSerializer = [AFJSONRequestSerializer serializer];
    }
    
    
    return self;
}

- (void)setUserName:(NSString *)userName password:(NSString *)password
{
    [self.requestSerializer clearAuthorizationHeader];
    [self.requestSerializer setAuthorizationHeaderFieldWithUsername:userName password:password];
}

@end