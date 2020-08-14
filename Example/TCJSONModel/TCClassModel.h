//
//  TCClassModel.h
//  TCJSONModel_Example
//
//  Created by fengunion on 2020/8/14.
//  Copyright © 2020 xtuck. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCStudentModel.h"
#import "NSObject+TCJSONModel.h"

@interface TCClassModel : NSObject

@property (nonatomic,copy) NSString *cname;

@property (nonatomic,strong) NSArray<TCStudentModel *><TCRequired> *students;

@end
