//
//  Stage.h
//  Bioreactor
//
//  Created by Dan Volz on 6/12/15 (on a delayed flight to Frankfurt).
//  Copyright (c) 2015 Dan Volz. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Stage : NSObject

@property (nonatomic, strong) NSString *name; // name of exercise
@property (nonatomic, assign) NSUInteger timeRequired;
@property (nonatomic, copy)   NSString *displayName;

@end
