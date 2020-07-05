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
    //TEST
    NSString *str = @"1232131";
    NSString *str2 = [str substringToIndex:0];
    NSString *str3 = [str substringFromIndex:str.length-1];
    NSString *str4 = [str substringWithRange:NSMakeRange(0, 0)];

    if (str2) {
        NSLog(@"str2 %@",str2);
    }
    if (str3) {
        NSLog(@"str3 %@",str3);
    }
    if (str4) {
        NSLog(@"str4 %@",str4);
    }

    
    NSUInteger start = [str rangeOfString:@"["].location;
    NSUInteger start2 = [str rangeOfString:@"1"].location;
    
    if (start2<start) {
        NSLog(@"start2 start %ld,%ld",start2,start);
    }
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"weibo" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSTimeInterval begin, end;
        begin = CACurrentMediaTime();
        JSWeiboStatus *md = [JSWeiboStatus tc_modelFromKeyValues:json error:nil];
        end = CACurrentMediaTime();
        printf("\nJSON --> model :            %8.2f   ", (end - begin) * 1000);
        
        begin = CACurrentMediaTime();
        NSDictionary *json2 = [md tc_toDictionary];
        end = CACurrentMediaTime();
        printf("\nmodel --> json :            %8.2f   ", (end - begin) * 1000);

        begin = CACurrentMediaTime();
        JSWeiboStatus *md2 = [md tc_copy:nil];
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
