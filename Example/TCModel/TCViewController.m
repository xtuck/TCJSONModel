//
//  TCViewController.m
//  TCModel
//
//  Created by xtuck on 06/07/2020.
//  Copyright (c) 2020 xtuck. All rights reserved.
//

#import "TCViewController.h"
#import "JSWeiboModel.h"

@interface TCViewController ()

@end

@implementation TCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"weibo" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSTimeInterval begin, end;
        begin = CACurrentMediaTime();
        JSWeiboStatus *md = [[JSWeiboStatus alloc] initWithDictionaryTC:json error:nil];
        end = CACurrentMediaTime();
        printf("\nJSON --> model :            %8.2f   ", (end - begin) * 1000);
        
        begin = CACurrentMediaTime();
        NSDictionary *json2 = [md tc_toDictionary];
        end = CACurrentMediaTime();
        printf("\nmodel --> json :            %8.2f   ", (end - begin) * 1000);

        begin = CACurrentMediaTime();
        JSWeiboStatus *md2 = [md copyJM:nil];
        end = CACurrentMediaTime();
        printf("\nmodel copy mode :            %8.2f   ", (end - begin) * 1000);
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
