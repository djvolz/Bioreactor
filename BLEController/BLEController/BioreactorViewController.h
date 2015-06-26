//
//  BioreactorViewController.h
//  Bioreactor
//
//  Created by Danny Volz on 6/9/15.
//  Copyright (c) 2015 Dan Volz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RBLProtocol.h"
#import "BLE.h"

@interface BioreactorViewController : UIViewController <ProtocolDelegate>
{
    IBOutlet UITableView *tv;
    NSDate *pauseStart, *previousFireDate;

}

@property (strong, nonatomic) BLE *ble;
@property (strong, nonatomic) RBLProtocol *protocol;


@end
