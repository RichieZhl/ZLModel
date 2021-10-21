//
//  ZLViewController.m
//  ZLModel
//
//  Created by richiezhl on 10/21/2021.
//  Copyright (c) 2021 richiezhl. All rights reserved.
//

#import "ZLViewController.h"
#import <ZLModel/NSObject+ZLModel.h>

@class RootData;
@class RootDataRoutes;

@interface Root : NSObject

@property (nonatomic, assign) int status;

@property (nonatomic, copy) NSString *message;

@property (nonatomic, strong) id errorCodes;

@property (nonatomic, strong) RootData *data;

@end

@implementation Root

@synthesize status = _status;

@synthesize message = _message;

@synthesize errorCodes = _errorCodes;

@synthesize data = _data;

ZLCodingImplementation

@end


@interface RootData : NSObject

@property (nonatomic, copy) NSDate *deploy_time;

@property (nonatomic, strong) NSMutableArray<RootDataRoutes *> *routes;

@end

@implementation RootData

@synthesize deploy_time = _deploy_time;

@synthesize routes = _routes;

+ (NSDictionary *)zl_objectClassInArray {
    return @{@"routes": @"RootDataRoutes"};
}

+ (void)initialize {
    [[self class] zl_setDateFormatString:@"yyyy-MM-dd HH:mm:ss"];
}

ZLCodingImplementation

@end


@interface RootDataRoutes : NSObject

@property (nonatomic, copy) NSString *remote_file;

@property (nonatomic, strong) id properties;

@property (nonatomic, strong) id vendor_file;

@property (nonatomic, copy) NSString *uri;

@property (nonatomic, copy) NSString *version;

@end

@implementation RootDataRoutes

@synthesize remote_file = _remote_file;

@synthesize properties = _properties;

@synthesize vendor_file = _vendor_file;

@synthesize uri = _uri;

@synthesize version = _version;

ZLCodingImplementation

@end


@interface TestSysUpper : NSObject

@property (nonatomic, assign) long ID;

@property (nonatomic, copy) NSString *DESCRIPTION;

@end

@implementation TestSysUpper

@end

@interface ZLViewController ()

@end

@implementation ZLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSString *jsonStr = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"https://aresapi.qianmi.com/api/map?pid=1&eid=2&platform=android&sv=11&gray=0"] encoding:NSUTF8StringEncoding error:nil];
//    NSLog(@"%@", jsonStr);
    
    Root *root = [Root zl_objectFromJsonString:jsonStr];
    NSLog(@"%@", root.zl_toJSONString);
    
    [NSKeyedArchiver archiveRootObject:root toFile:@"/Users/lylaut/Desktop/root.dat"];
    
    Root *t = [NSKeyedUnarchiver unarchiveObjectWithFile:@"/Users/lylaut/Desktop/root.dat"];
    NSLog(@"%@", t.data.deploy_time);
    
    NSDictionary *tDic = @{@"id": @11234341235, @"description": @"asdfdsfasf"};
    TestSysUpper *su = [TestSysUpper zl_objectFromDictionary:tDic];
    NSLog(@"%@", su.zl_toJSONString);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
