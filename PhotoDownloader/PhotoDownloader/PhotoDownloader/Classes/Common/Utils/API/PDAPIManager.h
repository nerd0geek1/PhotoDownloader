//
//  PDAPIManager.h
//  PhotoDownloader
//
//  Created by Kohei Tabata on 2013/12/21.
//  Copyright (c) 2013年 Kohei Tabata. All rights reserved.
//

#import "AFHTTPRequestOperationManager.h"

@interface PDAPIManager : AFHTTPRequestOperationManager

+ (PDAPIManager *)sharedManager;

- (void)setUserName:(NSString *)userName password:(NSString *)password;

@end