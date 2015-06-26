//
//  ConfigurationViewController.m
//  BLEController
//
//  Created by Danny Volz on 6/10/15.
//  Copyright (c) 2015 Dan Volz. All rights reserved.
//

#import "ConfigurationViewController.h"

@interface ConfigurationViewController ()

@property (strong, nonatomic) IBOutlet UITextField *fillChamberPart1Time;
@property (strong, nonatomic) IBOutlet UITextField *fillChamberPart2Time;
@property (strong, nonatomic) IBOutlet UITextField *replaceChamberBottomTime;
@property (strong, nonatomic) IBOutlet UITextField *replaceChamberTopTime;
@property (strong, nonatomic) IBOutlet UITextField *emptyChamberTopTime;
@property (strong, nonatomic) IBOutlet UITextField *fillChamberTopTime;

@property (strong, nonatomic) NSArray *stages;
@property (strong, nonatomic) NSArray *times;


@end

@implementation ConfigurationViewController

//TODO: This whole file should be converted to a table view with each label per cell because this implementation doesn't scale well at all

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    [self initializeDefaultArrays];
    
    
    [self checkOrCreatePLIST];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}


- (void)initializeDefaultArrays {
    self.stages = [NSArray arrayWithObjects:
                   @"fillChamberPart1Time",
                   @"fillChamberPart2Time",
                   @"replaceChamberBottomTime",
                   @"replaceChamberTopTime",
                   @"emptyChamberTopTime",
                   @"fillChamberTopTime",
                   nil];
    self.times = [NSArray arrayWithObjects:
                  @25.0,
                  @35.0,
                  @45.0,
                  @45.0,
                  @20.0,
                  @35.0,
                  nil];
}


#pragma mark - Table View methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.stages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *tableIdentifier = @"ConfigurationCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableIdentifier];
    }
    
    cell.textLabel.text = [self.stages objectAtIndex:indexPath.row];
    
    UITextField *timeTextField = (UITextField *) [cell viewWithTag:102];
    
    NSMutableDictionary *data = [self checkOrCreatePLIST];

    timeTextField.text = [NSString stringWithFormat:@"%@", [data objectForKey:cell.textLabel.text]];
    
    return cell;
}



#pragma mark - Handling PLIST Creation/Existence Check

- (NSMutableDictionary *) getBioreactorDefaults {
    
    NSMutableDictionary *bioreactorPreferences;
    
    bioreactorPreferences = [[NSMutableDictionary alloc] init];
        
    for (NSString *stageName in self.stages) {
        [bioreactorPreferences setObject:[self.times objectAtIndex:[self.stages indexOfObject:stageName]] forKey:stageName];
    }
     
    
    return bioreactorPreferences;
}


- (NSString *)getPathForPLIST {
    //PLIST Variables
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"BioreactorPreferences.plist"];
    
    return path;
}

- (NSMutableDictionary *)checkOrCreatePLIST {
    //PLIST Variables
    NSString *path = [self getPathForPLIST];
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    
    // PLIST exists
    if ([fileManager fileExistsAtPath: path]) {

        data = [[NSMutableDictionary alloc] initWithContentsOfFile: path];
    }
    // PLIST does not exist
    else {
        data = [self getBioreactorDefaults];
        
        [data writeToFile: path atomically:YES];
    }
    
    return data;
}

- (void) saveBioreactorValueToPLIST:(NSNumber *)value atKey:(NSString *)key {
    NSString *path = [self getPathForPLIST];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableDictionary *data;

    
    if ([fileManager fileExistsAtPath: path]) {
        data = [[NSMutableDictionary alloc] initWithContentsOfFile: path];
        [data setObject:value forKey:key];
        
        [data writeToFile: path atomically:YES];

    }

}


#pragma mark - Label Editing
- (IBAction)didEditTimeLabel:(UITextField *)sender {
    NSNumber *newTime = [NSNumber numberWithFloat:[sender.text floatValue]];
    
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];

    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self saveBioreactorValueToPLIST:newTime atKey:cell.textLabel.text];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}


@end
