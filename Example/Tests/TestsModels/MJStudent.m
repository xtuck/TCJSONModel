//
//  MJStudent.m
//  MJExtensionExample
//
//  Created by MJ Lee on 15/1/5.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "MJStudent.h"
#import "NSObject+TCJSONModel.h"

@implementation MJStudent

+ (NSDictionary *)tc_propertyNameDictionaryKey {
    return @{
            @"ID" : @"id",
            @"desc" : @"desciption",
            @"oldName" : @"name.oldName",
            @"nowName" : @"name.newName",
    //        @"otherName" : @[@"otherName", @"name.newName", @"name.oldName"],//不支持花里胡哨
    //        @"nameChangedTime" : @"name.info[0].nameChangedTime",   //不支持数组路径
            @"bag" : @"other.bag"
        };
}

@end
