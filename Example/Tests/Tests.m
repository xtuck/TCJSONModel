//
//  TCModelTests.m
//  TCModelTests
//
//  Created by xtuck on 06/07/2020.
//  Copyright (c) 2020 xtuck. All rights reserved.
//

@import XCTest;
#import "NSObject+TCModel.h"
#import "MJStudent.h"
#import "MJBag.h"
#import "JSWeiboModel.h"

@interface YYTestNestUser : NSObject
@property uint64_t uid;
@property NSString *name;
@end
@implementation YYTestNestUser
@end

@interface YYTestNestRepo : NSObject
@property uint64_t repoID;
@property NSString *name;
@property YYTestNestUser *user;
@end
@implementation YYTestNestRepo
@end

@interface Tests : XCTestCase

@end

@implementation Tests


- (void)testWbModel {
    
}

- (void)testKeyMapping {
    // 1.定义一个字典
    NSDictionary *dict = @{
                           @"id" : @"20",
                           @"desciption" : @"好孩子",
                           @"name" : @{
                                   @"newName" : @"lufy",
                                   @"oldName" : @"kitty",
                                   @"info" : @[
                                           @"test-data",
                                           @{@"nameChangedTime" : @"2013-08-07"}
                                           ]
                                   },
                           @"other" : @{
                                   @"bag" : @{
                                           @"name" : @"小书包",
                                           @"price" : @100.7
                                           }
                                   }
                           };
    
    // 2.将字典转为MJStudent模型
    MJStudent *stu =[MJStudent tc_modelFromKeyValues:dict error:nil];
    
    // 3.检测MJStudent模型的属性
    XCTAssert([stu.ID isEqual:@"20"]);
    XCTAssert([stu.desc isEqual:@"好孩子"]);
//    XCTAssert([stu.otherName isEqual:@"lufy"]);
    XCTAssert([stu.nowName isEqual:@"lufy"]);
    XCTAssert([stu.oldName isEqual:@"kitty"]);
//    XCTAssert([stu.nameChangedTime isEqual:@"2013-08-07"]);
    XCTAssert([stu.bag.name isEqual:@"小书包"]);
    XCTAssert(stu.bag.price == 100.7);
}

- (void)test {
    NSString *json = @"{\"repoID\":1234,\"name\":\"YYModel\",\"user\":{\"uid\":5678,\"name\":\"ibireme\"}}";
    YYTestNestRepo *repo = [YYTestNestRepo tc_modelFromKeyValues:json error:nil];
    XCTAssert(repo.repoID == 1234);
    XCTAssert([repo.name isEqualToString:@"YYModel"]);
    XCTAssert(repo.user.uid == 5678);
    XCTAssert([repo.user.name isEqualToString:@"ibireme"]);
    
    NSDictionary *jsonObject = [repo tc_toDictionary];
    XCTAssert([((NSString *)jsonObject[@"name"]) isEqualToString:@"YYModel"]);
    XCTAssert([((NSString *)((NSDictionary *)jsonObject[@"user"])[@"name"]) isEqualToString:@"ibireme"]);
    
    [repo tc_mergeFromDictionary:@{@"name" : @"YYImage", @"user" : @{@"name": @"bot"}} error:nil];
    XCTAssert(repo.repoID == 1234);
    XCTAssert([repo.name isEqualToString:@"YYImage"]);
    XCTAssert(repo.user.uid == 5678);
    XCTAssert([repo.user.name isEqualToString:@"bot"]);
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end

