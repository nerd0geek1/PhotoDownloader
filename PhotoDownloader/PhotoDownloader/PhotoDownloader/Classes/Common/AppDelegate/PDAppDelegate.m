//
//  PDAppDelegate.m
//  PhotoDownloader
//
//  Created by Kohei Tabata on 2013/12/18.
//  Copyright (c) 2013年 Kohei Tabata. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "PDAppDelegate.h"
#import "PDAPIManager.h"
#import "PDConstants.h"

@interface PDAppDelegate ()<NSTableViewDataSource>
{
    IBOutlet NSView *_searchResultView;
    IBOutlet NSTextField *_hitCountLabel;
    IBOutlet NSTextField *_downloadStatusLabel;
    IBOutlet NSTableView *_tableView;
    IBOutlet NSTextField *_keywordField;
    IBOutlet NSTextField *_downloadCountField;
    IBOutlet NSPathControl *_pathControl;
    
    NSString *_saveImageDirectoryPath;
    NSMutableArray *_searchResultArray;
    
    NSInteger _totalRequestCount;
    NSInteger _currentRequestCount;
    
    NSInteger _downloadedFilesCount;
    NSInteger _improperDataFileCount;
    NSInteger _downloadFailedFilesCount;
}

@end

@implementation PDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSString *desktopPath = [[[[NSProcessInfo processInfo] environment] objectForKey:@"HOME"] stringByAppendingPathComponent:@"Desktop"];
    _saveImageDirectoryPath = desktopPath;
    [_pathControl setURL:[NSURL fileURLWithPath:desktopPath]];
}



#pragma mark ---UIButton Touch Handler---
- (IBAction)updateListButtonTouchHandler:(id)sender
{
    if (_keywordField.stringValue.length && _downloadCountField.stringValue.length)
    {
        if ([self _isDigit:_downloadCountField.stringValue])
        {
            [self _updateSearchResult];
        }
        else
        {
            [self _showAlertModalWithMessageText:@"エラー" text:@"ダウンロード数に数値以外の値が入力されています。"];
        }
    }
    else
    {
        [self _showAlertModalWithMessageText:@"エラー" text:@"キーワード、ダウンロード数の少なくとも一方が未入力です。"];
    }
}

- (IBAction)specifyDestinationToSaveButtonTouchHandler:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanCreateDirectories:YES];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            _saveImageDirectoryPath = [openPanel URL].absoluteString;
            [_pathControl setURL:[openPanel URL]];
        }
    }];
}

- (IBAction)downloadButtonTouchHandler:(id)sender
{
    for (NSString *url in _searchResultArray)
    {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.f];
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            if (!connectionError)
            {
                if (data.length)
                {
                    NSURL *imageUrl = [NSURL URLWithString:[_saveImageDirectoryPath stringByAppendingPathComponent:[url lastPathComponent]]];
                    [data writeToURL:imageUrl atomically:YES];
                    [_searchResultArray removeObject:url];
                    [_tableView reloadData];
                    _downloadedFilesCount++;
                }
                else
                {
                    [_searchResultArray removeObject:url];
                    [_tableView reloadData];
                    _improperDataFileCount++;
                }
            }
            else
            {
                _downloadFailedFilesCount++;
                TRACE(@"error:%@", connectionError);
            }
            [_downloadStatusLabel setStringValue:[NSString stringWithFormat:@"ダウンロード完了:%lu　不正データ:%lu　ダウンロード失敗:%lu", _downloadedFilesCount, _improperDataFileCount, _downloadFailedFilesCount]];
        }];
    }
}



#pragma mark ---NSTableView DataSource Methods---
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _searchResultArray.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return _searchResultArray[row];
}



#pragma mark ---Private Methods---
- (BOOL)_isDigit:(NSString *)text
{
    NSCharacterSet *digitCharSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    
    NSScanner *aScanner = [NSScanner localizedScannerWithString:text];
    [aScanner setCharactersToBeSkipped:nil];
    
    [aScanner scanCharactersFromSet:digitCharSet intoString:NULL];
    return [aScanner isAtEnd];
}

- (void)_updateSearchResult
{
    _searchResultArray = [NSMutableArray array];
    _currentRequestCount = 0;
    _totalRequestCount = 0;
    _downloadedFilesCount = 0;
    _improperDataFileCount = 0;
    _downloadFailedFilesCount = 0;
    
    [[PDAPIManager sharedManager] setUserName:kBingSearchAPIPrimaryAccountKey password:kBingSearchAPIPrimaryAccountKey];
    
    NSDictionary *params;
    if ([_downloadCountField.stringValue integerValue] < 50)
    {
        params = @{@"Query" : [NSString stringWithFormat:@"'%@'", _keywordField.stringValue], @"$format" : @"json", @"$top" : _downloadCountField.stringValue};
        [self _sendSearchRequestWithParams:params];
        _totalRequestCount = 1;
    }
    else
    {
        NSInteger requestCount = [_downloadCountField.stringValue integerValue] / 50;
        _totalRequestCount = requestCount;
        for (int i = 0; i < requestCount; i++)
        {
            params = @{@"Query" : [NSString stringWithFormat:@"'%@'", _keywordField.stringValue], @"$format" : @"json", @"$skip" : @(i * 50)};
            [self _sendSearchRequestWithParams:params];
        }
    }
}

- (void)_sendSearchRequestWithParams:(NSDictionary *)params
{
    [[PDAPIManager sharedManager] GET:@"Image" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        _currentRequestCount++;
        
        NSDictionary *responseDictionary = responseObject[@"d"];
        NSArray *resultsArray = responseDictionary[@"results"];
        
        for (NSDictionary *result in resultsArray)
        {
            if ([kImageExtensions containsObject:[result[@"MediaUrl"] pathExtension]])
            {
                [_searchResultArray addObject:result[@"MediaUrl"]];
            }
        }
        
        if (_searchResultArray.count)
        {
            [_searchResultView setHidden:NO];
            [_tableView reloadData];
            
            if (_totalRequestCount == _currentRequestCount)
            {
                [_hitCountLabel setStringValue:[NSString stringWithFormat:@"検索結果(確定):%lu件", _searchResultArray.count]];
            }
            else
            {
                [_hitCountLabel setStringValue:[NSString stringWithFormat:@"検索結果(暫定):%lu件", _searchResultArray.count]];
            }
        }
        else
        {
            [_searchResultView setHidden:YES];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self _showAlertModalWithMessageText:@"エラー" text:error.userInfo.description];
    }];
}

- (void)_showAlertModalWithMessageText:(NSString *)messageText text:(NSString *)text
{
    NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", text];
    [alert runModal];
}

@end