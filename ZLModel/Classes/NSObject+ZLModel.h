//
//  NSObject+ZLModel.h
//  ZLModel
//
//  Created by richiezhl on 10/21/2021.
//  Copyright (c) 2021 richiezhl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/**
 归档的实现
 */
#define ZLCodingImplementation \
- (instancetype)initWithCoder:(NSCoder *)coder { \
self = [super init]; \
if (self) { \
    [self zl_coderDecode:coder];\
} \
return self; \
} \
\
- (void)encodeWithCoder:(NSCoder *)aCoder { \
    [self zl_coderEncode:aCoder];\
}

@interface NSObject (ZLModel)
+ (NSDateFormatter *)zl_dateFormatter;
/**
 *  交换两个方法
 *
 *  @param originalSelector 原始方法
 *  @param swizzledSelector 替换后的方法
 */
+ (void)zl_swizzleSelector:(SEL)originalSelector withAnotherSelector:(SEL)swizzledSelector;
/**
 *  字典转模型
 *
 *  @param dic 字典
 *
 *  @return 模型
 */
+ (instancetype)zl_objectFromDictionary:(NSDictionary *)dic;
/**
 *  字典数组转模型数组
 *
 *  @param objectArray 字典数组
 *
 *  @return 模型数组
 */
+ (NSMutableArray *)zl_objectArrayFromArray:(NSArray *)objectArray;
/**
 *  json字符串转模型
 *
 *  @param string json字符串
 *
 *  @return 模型
 */
+ (instancetype)zl_objectFromJsonString:(NSString *)string;
/**
 *  模型转字典
 *
 *  @return 字典
 */
- (NSDictionary *)zl_toDictionary;
/**
 *  模型数组转字典数组
 *
 *  @param objectArray 模型数组
 *
 *  @return 字典数组
 */
- (NSMutableArray *)zl_arrayWithObjectArray:(NSArray *)objectArray;
/**
 *  模型转json
 *
 *  @return json数据
 */
- (NSData *)zl_toJSONData;
- (NSString *)zl_toJSONString;
/**
 *  字典转模型时，模型中某属性是数组时，属性名及这个数组中的模型Class形成key-value键值对
 *
 *  @return 数组模型属性名及这个数组中的模型Class
 */
+ (NSDictionary<NSString *, Class> *)zl_objectClassInArray;
/**
 *  归档序列化与反序列化
 *
 *  @param aCoder 传入NSCoding的NSCoder对象
 */
- (void)zl_coderEncode:(NSCoder *)aCoder;
- (void)zl_coderDecode:(NSCoder *)aCoder;
/**
 *  格式化日期,请在相应类的NSOBject load方式里设置
 *
 *  @param string 格式化日期字符串
 */
+ (void)zl_setDateFormatString:(NSString *)string;
+ (NSString *)zl_dateFormatString;

@end
