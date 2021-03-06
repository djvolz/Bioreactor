//
//  BioreactorViewController.m
//  Bioreactor
//
//  Created by Danny Volz on 6/9/15.
//  Copyright (c) 2015 Dan Volz. All rights reserved.
//


#import "BioreactorViewController.h"



@interface BioreactorViewController ()

@property (nonatomic, strong) NSTimer *scheduleTimer;
@property (strong, nonatomic) IBOutlet UISegmentedControl *chamberSelectionSegmentedControl;
@property (strong, nonatomic) IBOutlet UIStepper *stageStepper;
@property (strong, nonatomic) IBOutlet UILabel *currentStageLabel;
@property (strong, nonatomic) IBOutlet UIProgressView *bioreactorProgress;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *sequenceActivityIndicator;
@property (strong, nonatomic) IBOutlet UISwitch *singleStageSwtich;
@property (nonatomic) NSInteger currentStage;

@property (strong, nonatomic) IBOutlet UIButton *startStop;
@property (nonatomic) NSMutableDictionary *bioreactorPreferences;

@property (strong, nonatomic) IBOutlet UIButton *startSequenceButton;
@property (nonatomic) NSMutableArray *currentPins;


@end

@implementation BioreactorViewController

uint8_t bio_total_pin_count  = 0;
uint8_t bio_pin_mode[128]    = {0};
uint8_t bio_pin_cap[128]     = {0};
uint8_t bio_pin_digital[128] = {0};
uint16_t bio_pin_analog[128]  = {0};
uint8_t bio_pin_pwm[128]     = {0};
uint8_t bio_pin_servo[128]   = {0};

uint8_t bio_init_done = 0;

@synthesize ble;
@synthesize protocol;

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.currentPins = [NSMutableArray array];

    
    
    NSLog(@"ControlView: viewDidLoad");
}

NSTimer *syncTimer;

-(void) syncTimeout:(NSTimer *)timer
{
    NSLog(@"Timeout: no response");
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:@"No response from the BLE Controller sketch."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    
    // disconnect it
    [ble.CM cancelPeripheralConnection:ble.activePeripheral];
}

-(void)viewDidAppear:(BOOL)animated
{
    NSLog(@"ControlView: viewDidAppear");
    
    self.bioreactorPreferences = [self checkOrCreatePLIST];

    
    syncTimer = [NSTimer scheduledTimerWithTimeInterval:(float)3.0 target:self selector:@selector(syncTimeout:) userInfo:nil repeats:NO];
    
    [protocol queryProtocolVersion];
}

-(void)viewDidDisappear:(BOOL)animated
{
    NSLog(@"ControlView: viewDidDisappear");
    
    bio_total_pin_count = 0;
    //    [tv reloadData];
    
    bio_init_done = 0;
    
//    [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void) processData:(uint8_t *) data length:(uint8_t) length
{
#if defined(CV_DEBUG)
    NSLog(@"ControlView: processData");
    NSLog(@"Length: %d", length);
#endif
    
    [protocol parseData:data length:length];
}

-(void) protocolDidReceiveProtocolVersion:(uint8_t)major Minor:(uint8_t)minor Bugfix:(uint8_t)bugfix
{
    NSLog(@"protocolDidReceiveProtocolVersion: %d.%d.%d", major, minor, bugfix);
    
    // get response, so stop timer
    [syncTimer invalidate];
    
    uint8_t buf[] = {'B', 'L', 'E'};
    [protocol sendCustomData:buf Length:3];
    
    [protocol queryTotalPinCount];
}

-(void) protocolDidReceiveTotalPinCount:(UInt8) count
{
    NSLog(@"protocolDidReceiveTotalPinCount: %d", count);
    
    bio_total_pin_count = count;
    [protocol queryPinAll];
}

-(void) protocolDidReceivePinCapability:(uint8_t)pin Value:(uint8_t)value
{
    NSLog(@"protocolDidReceivePinCapability");
    NSLog(@" Pin %d Capability: 0x%02X", pin, value);
    
    if (value == 0)
        NSLog(@" - Nothing");
    else
    {
        if (value & PIN_CAPABILITY_DIGITAL)
            NSLog(@" - DIGITAL (I/O)");
        if (value & PIN_CAPABILITY_ANALOG)
            NSLog(@" - ANALOG");
        if (value & PIN_CAPABILITY_PWM)
            NSLog(@" - PWM");
        if (value & PIN_CAPABILITY_SERVO)
            NSLog(@" - SERVO");
    }
    
    bio_pin_cap[pin] = value;
}

-(void) protocolDidReceivePinData:(uint8_t)pin Mode:(uint8_t)mode Value:(uint8_t)value
{
    //    NSLog(@"protocolDidReceiveDigitalData");
    //    NSLog(@" Pin: %d, mode: %d, value: %d", pin, mode, value);
    
    uint8_t _mode = mode & 0x0F;
    
    bio_pin_mode[pin] = _mode;
    if ((_mode == INPUT) || (_mode == OUTPUT))
        bio_pin_digital[pin] = value;
    else if (_mode == ANALOG)
        bio_pin_analog[pin] = ((mode >> 4) << 8) + value;
    else if (_mode == PWM)
        bio_pin_pwm[pin] = value;
    else if (_mode == SERVO)
        bio_pin_servo[pin] = value;
    
    [tv reloadData];
}

-(void) protocolDidReceivePinMode:(uint8_t)pin Mode:(uint8_t)mode
{
    NSLog(@"protocolDidReceivePinMode");
    
    if (mode == INPUT)
        NSLog(@" Pin %d Mode: INPUT", pin);
    else if (mode == OUTPUT)
        NSLog(@" Pin %d Mode: OUTPUT", pin);
    else if (mode == PWM)
        NSLog(@" Pin %d Mode: PWM", pin);
    else if (mode == SERVO)
        NSLog(@" Pin %d Mode: SERVO", pin);
    
    bio_pin_mode[pin] = mode;
    [tv reloadData];
}

-(void) protocolDidReceiveCustomData:(UInt8 *)data length:(UInt8)length
{
    // Handle your customer data here.
    for (int i = 0; i< length; i++)
        printf("0x%2X ", data[i]);
    printf("\n");
}




uint8_t M1   = 22;
uint8_t M2   = 23;
uint8_t M3   = 24;

uint8_t TV   = 27;
uint8_t TVex = 38;
uint8_t BV   = 29;
uint8_t BVex = 28;

float fillChamberPart1Time     ;
float fillChamberPart2Time     ;
float replaceChamberBottomTime ;
float replaceChamberTopTime    ;
float emptyChamberTopTime      ;
float fillChamberTopTime       ;



- (IBAction)selectChamberSegmentedControl:(UISegmentedControl *)sender {
    if ([sender selectedSegmentIndex] == 0)
    {
        TV   = 27;
        TVex = 38;
        BV   = 29;
        BVex = 28;
    } else if ([sender selectedSegmentIndex] == 1) {
        TV   = 25;
        TVex = 30;
        BV   = 31;
        BVex = 32;
    } else {
        TV   = 37;
        TVex = 34;
        BV   = 35;
        BVex = 36;
    }
    
}

- (IBAction)didTouchStartButton:(UIButton *)sender {
    [self startSequence];
    
    [self handleEndOfSequenceGUIElements:NO];
    
}

- (IBAction)didTouchResetButton:(UIButton *)sender {
    [self resetAll];
    
    [self handleEndOfSequenceGUIElements:YES];

}

- (IBAction)didTouchStageStepper:(UIStepper *)sender {
    switch ((int)sender.value) {
        case 0:
            self.currentStageLabel.text = [NSString stringWithFormat:@"Fill Top and Bottom Chamber"];
            break;
        case 1:
            self.currentStageLabel.text = [NSString stringWithFormat:@"Replace Chamber Bottom"];
            break;
        case 2:
            self.currentStageLabel.text = [NSString stringWithFormat:@"Replace Chamber Top"];
            break;
        case 3:
            self.currentStageLabel.text = [NSString stringWithFormat:@"Empty Chamber Top"];
            break;
        case 4:
            self.currentStageLabel.text = [NSString stringWithFormat:@"Fill Chamber Top (Backfill)"];
            break;
        case 5:
            self.currentStageLabel.text = [NSString stringWithFormat:@"Fill Chamber Bottom"];
            break;
        default:
            break;
    }
}


#pragma Chambers

- (void)switchPin:(uint8_t)pin toState:(uint8_t)state {
    if (state) {
        [self.currentPins addObject:@(pin)];
    } else {
        [self.currentPins removeObject:@(pin)];
    }
    
    NSLog(@"%@ : %@", [NSString stringWithFormat:@"%d", (uint8_t)pin], [NSString stringWithFormat:@"%d", (uint8_t)state]);

    [protocol digitalWrite:pin Value:state];
    bio_pin_digital[pin] = state;
}

- (void) resetAll {
    
    
    // Cancel the current timer
    [self.scheduleTimer invalidate];

    for (int i = 0; i < 70/*128*/; i++) {
//        [NSThread sleepForTimeInterval:0.01];
//        [protocol setPinMode:i Mode:OUTPUT];
        [NSThread sleepForTimeInterval:0.05];
        [self switchPin:i toState:LOW];
    }
}

- (void) startSequence {
    
    fillChamberPart1Time     = [[self.bioreactorPreferences objectForKey:@"fillChamberPart1Time"] floatValue];
    fillChamberPart2Time     = [[self.bioreactorPreferences objectForKey:@"fillChamberPart2Time"] floatValue];
    replaceChamberBottomTime = [[self.bioreactorPreferences objectForKey:@"replaceChamberBottomTime"] floatValue];
    replaceChamberTopTime    = [[self.bioreactorPreferences objectForKey:@"replaceChamberTopTime"] floatValue];
    emptyChamberTopTime      = [[self.bioreactorPreferences objectForKey:@"emptyChamberTopTime"] floatValue];
    fillChamberTopTime       = [[self.bioreactorPreferences objectForKey:@"fillChamberTopTime"] floatValue];
    
    
    switch ((int)self.stageStepper.value) {
        case 0:
            [self fillChamberStep1];
            break;
        case 1:
            [self replaceChamberBottomPart1];
            break;
        case 2:
            [self replaceChamberTopPart1];
            break;
        case 3:
            [self emptyChamberTopPart1];
            break;
        case 4:
            [self fillChamberTopPart1];
            break;
        case 5:
            [self fillChamberBottomPart1];
            break;
        default:
            [self fillChamberStep1];
            break;
    }
}









//Event	Fill Chamber 1						For filling chambers, there needs to be an option to choose between M1 and M2
- (void)fillChamberStep1 {
    self.currentStage = 0;
    
    self.bioreactorProgress.progress = 0;
    NSString *currentStage = [NSString stringWithFormat:@"Fill Top and Bottom Chamber"];
    NSLog(@"%@", currentStage);
    self.currentStageLabel.text = currentStage;
    
    
    // Step 1	ON	M1, BV, BVex
    [self switchPin:M1 toState:HIGH];
    [self switchPin:BV toState:HIGH];
    [self switchPin:BVex toState:HIGH];
    
    //Step 2	Pause 	Fill 25 sec
    [self createTimer];
}


- (void)fillChamberPart2:(NSTimer *)timer {
    self.currentStage = 1;

    
    float progress = (1.0/5.0)/3.0;
    self.bioreactorProgress.progress = progress;
    
    // Step 3	OFF	BV, BVex
    [self switchPin:BV toState:LOW];
    [self switchPin:BVex toState:LOW];
    
    //  Step 4	ON	TV
    [self switchPin:TV toState:HIGH];
    
    //  Step 5	Pause 	Fill 35 sec
    [self createTimer];

    
}


- (void)fillChamberPart3:(NSTimer *)timer {
    self.bioreactorProgress.progress = (1.0/5.0) * (2.0/3.0);
    
    // Step 6	OFF	M1, TV
    [self switchPin:M1 toState:LOW];
    [self switchPin:TV toState:LOW];
    
    
    if (!self.singleStageSwtich.on) {
        [self replaceChamberBottomPart1];
    } else {
        [self handleEndOfSequenceGUIElements:YES];
    }
}







//Event	Replace Chamber 1 Bottom				Replacing chambers needs to be using either M1 or M2 opposite of what it filled with. If M1 filled, then M2 would replace and vice versa
- (void) replaceChamberBottomPart1 {
    self.currentStage = 2;

    self.bioreactorProgress.progress = (1.0/5.0);
    NSString *currentStage = [NSString stringWithFormat:@"Replace Chamber Bottom"];
    NSLog(@"%@", currentStage);
    self.currentStageLabel.text = currentStage;

    
    // Step 1	ON	M2,BV,BVex
    [self switchPin:M2 toState:HIGH];
    [self switchPin:BV toState:HIGH];
    [self switchPin:BVex toState:HIGH];
    
    // Step 2	Pause 	Flush 45 Sec
    [self createTimer];
}

- (void)replaceChamberBottomPart2:(NSTimer *)timer {
    self.bioreactorProgress.progress = (1.0/5.0) + ((1.0/5.0)/2.0);

    // Step 3	OFF	M2,BV,BVex
    [self switchPin:M2 toState:LOW];
    [self switchPin:BV toState:LOW];
    [self switchPin:BVex toState:LOW];
    
    if (!self.singleStageSwtich.on) {
        [self replaceChamberTopPart1];
    } else {
        [self handleEndOfSequenceGUIElements:YES];
    }
}


//Event	Replace Chamber 1 Top							Replacing chambers needs to be using either M1 or M2 opposite of what it filled with. If M1 filled, then M2 replaces and vice versa
- (void) replaceChamberTopPart1 {
    self.currentStage = 3;

    self.bioreactorProgress.progress = (2.0/5.0);
    NSString *currentStage = [NSString stringWithFormat:@"Replace Chamber Top"];
    NSLog(@"%@", currentStage);
    self.currentStageLabel.text = currentStage;
    
    // Step 1	 ON	M2, TV, TVex
    [self switchPin:M2 toState:HIGH];
    [self switchPin:TV toState:HIGH];
    [self switchPin:TVex toState:HIGH];
    
    // Step 2	Pause 	Flush 45 Sec
    [self createTimer];
}

- (void)replaceChamberTopPart2:(NSTimer *)timer {
    self.bioreactorProgress.progress = (2.0/5.0) + ((1.0/5.0)/2.0);

    
    // Step 3	OFF	M2, TV1, TV1ex
    [self switchPin:M2 toState:LOW];
    [self switchPin:TV toState:LOW];
    [self switchPin:TVex toState:LOW];
    
    if (!self.singleStageSwtich.on) {
        [self emptyChamberTopPart1];
    } else {
        [self handleEndOfSequenceGUIElements:YES];
    }
}





//Event	Empty Chamber 1 Top				Emptying uses M3 all times
- (void) emptyChamberTopPart1 {
    self.currentStage = 4;

    self.bioreactorProgress.progress = (3.0/5.0);
    NSString *currentStage = [NSString stringWithFormat:@"Empty Chamber Top"];
    NSLog(@"%@", currentStage);
    self.currentStageLabel.text = currentStage;
    
    
    // Step 1	ON	M3, TV, TVex
    [self switchPin:M3 toState:HIGH];
    [self switchPin:TV toState:HIGH];
    [self switchPin:TVex toState:HIGH];
    
    // Step 2	Pause 	Empty 20 Sec
    [self createTimer];
}

- (void)emptyChamberTopPart2:(NSTimer *)timer {
    self.bioreactorProgress.progress = (3.0/5.0) + ((1.0/5.0)/2.0);
    
    // Step 3	OFF	M3, TV, TVex
    [self switchPin:M3 toState:LOW];
    [self switchPin:TV toState:LOW];
    [self switchPin:TVex toState:LOW];
    
    if (!self.singleStageSwtich.on) {
        [self fillChamberTopPart1];
    } else {
        [self handleEndOfSequenceGUIElements:YES];
    }
}






//Event	Fill Chamber 1 Top (Backfill)				For filling chambers, there needs to be an option to choose between M1 and M2
- (void) fillChamberTopPart1 {
    self.currentStage = 5;

    self.bioreactorProgress.progress = (4.0/5.0);
    NSString *currentStage = [NSString stringWithFormat:@"Fill Chamber Top (Backfill)"];
    NSLog(@"%@", currentStage);
    self.currentStageLabel.text = currentStage;
    
    // Step 1	ON	M1, TV
    [self switchPin:M1 toState:HIGH];
    [self switchPin:TV toState:HIGH];
    
    // Step 2	Pause 	Fill 35 Sec
    [self createTimer];
}

- (void)fillChamberTopPart2:(NSTimer *)timer {
    self.bioreactorProgress.progress = (5.0/5.0);
    
    // Step 3	OFF	M1, TV
    [self switchPin:M1 toState:LOW];
    [self switchPin:TV toState:LOW];
    
    [self handleEndOfSequenceGUIElements:YES];
}

//Event	Fill Chamber Bottom
- (void) fillChamberBottomPart1 {
    self.currentStage = 6;
    
    self.bioreactorProgress.progress = (5.0/5.0);
    NSString *currentStage = [NSString stringWithFormat:@"Fill Chamber Bottom"];
    NSLog(@"%@", currentStage);
    self.currentStageLabel.text = currentStage;
    
    // Step 1	ON	M1, TV
    [self switchPin:M1 toState:HIGH];
    [self switchPin:BV toState:HIGH];
    [self switchPin:BVex toState:HIGH];

    
    // Step 2	Pause 	Fill 35 Sec
    [self createTimer];
}

- (void)fillChamberBottomPart2:(NSTimer *)timer {
    self.bioreactorProgress.progress = (5.0/5.0);
    
    // Step 3	OFF	M1, TV
    [self switchPin:M1 toState:LOW];
    [self switchPin:BV toState:LOW];
    [self switchPin:BVex toState:LOW];

    
    [self handleEndOfSequenceGUIElements:YES];
}


#pragma mark - Handling PLIST Creation/Existence Check

- (NSMutableDictionary *) getBioreactorDefaults {
    
    NSMutableDictionary *bioreactorPreferences;
    
    
    NSNumber *fillChamberPart1Time     = [NSNumber numberWithFloat: 25.0];
    NSNumber *fillChamberPart2Time     = [NSNumber numberWithFloat: 35.0];
    NSNumber *replaceChamberBottomTime = [NSNumber numberWithFloat: 45.0];
    NSNumber *replaceChamberTopTime    = [NSNumber numberWithFloat: 45.0];
    NSNumber *emptyChamberTopTime      = [NSNumber numberWithFloat: 20.0];
    NSNumber *fillChamberTopTime       = [NSNumber numberWithFloat: 35.0];
    
    bioreactorPreferences = [[NSMutableDictionary alloc] init];
    
//    Stage *stage = [[Stage alloc] init];
//    
//    stage = [self setupStagewithName:@"fillChamberPart1Time" andTime:[NSNumber numberWithFloat: 25.0]];
    
    [bioreactorPreferences setObject: fillChamberPart1Time     forKey:@"fillChamberPart1Time"];
    [bioreactorPreferences setObject: fillChamberPart2Time     forKey:@"fillChamberPart2Time"];
    [bioreactorPreferences setObject: replaceChamberBottomTime forKey:@"replaceChamberBottomTime"];
    [bioreactorPreferences setObject: replaceChamberTopTime    forKey:@"replaceChamberTopTime"];
    [bioreactorPreferences setObject: emptyChamberTopTime      forKey: @"emptyChamberTopTime"];
    [bioreactorPreferences setObject: fillChamberTopTime       forKey:@"fillChamberTopTime"];
    
    return bioreactorPreferences;
}

//- (Stage *)setupStagewithName:(NSString *)name andTime:(NSNumber *)time {
//    Stage *stage = [[Stage alloc] init];
//
//}

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










#pragma mark - Timer Handling

-(IBAction)clicked:(UIButton *)sender
{
    if ([self.startStop.titleLabel.text isEqualToString:@"Start"]) {
        [self.startStop setTitle:@"Pause" forState:UIControlStateNormal];
        
        [self createTimer];
        
        
    } else if ([self.startStop.titleLabel.text isEqualToString:@"Pause"]) {
        [self.startStop setTitle:@"Resume" forState:UIControlStateNormal];
        [self.startStop setTitleColor:[UIColor colorWithRed:0/255 green:0/255 blue:255/255 alpha:1.0] forState:UIControlStateNormal];
        
        for (NSNumber *pin in self.currentPins) {
            [protocol digitalWrite:(uint8_t)[pin unsignedCharValue] Value:LOW];
            bio_pin_digital[(uint8_t)[pin unsignedCharValue]] = LOW;
            NSLog(@"%@ : LOW", [NSString stringWithFormat:@"%d", (uint8_t)[pin unsignedCharValue]]);

        }
        


        pauseStart = [NSDate dateWithTimeIntervalSinceNow:0];
        previousFireDate = [self.scheduleTimer fireDate];
        NSLog(@"pauseStart %@", pauseStart);
        NSLog(@"previousFireDate %@", previousFireDate);
        
        [self.scheduleTimer setFireDate:[NSDate distantFuture]];
        
    } else if ([self.startStop.titleLabel.text isEqualToString:@"Resume"])
    {
        [self.startStop setTitle:@"Pause" forState:UIControlStateNormal];
        
        for (NSNumber *pin in self.currentPins) {
            [protocol digitalWrite:(uint8_t)[pin unsignedCharValue] Value:HIGH];
            bio_pin_digital[(uint8_t)[pin unsignedCharValue]] = HIGH;
            NSLog(@"%@ : HIGH", [NSString stringWithFormat:@"%d", (uint8_t)[pin unsignedCharValue]]);
        }
        
        float pauseTime = -1*[pauseStart timeIntervalSinceNow];
        NSLog(@"newFireDate %@", [NSDate dateWithTimeInterval:pauseTime sinceDate:previousFireDate]);
        [self.scheduleTimer setFireDate:[NSDate dateWithTimeInterval:pauseTime sinceDate:previousFireDate]];
    }
}




- (void)createTimer {
    NSLog(@"Current date: %@", [NSDate date]);
    switch (self.currentStage) {
        case 0:
            self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:fillChamberPart1Time
                                                                  target:self
                                                                selector:@selector(fillChamberPart2:)
                                                                userInfo:nil
                                                                 repeats:NO];
            NSLog(@"Time: %f", fillChamberPart1Time);
            break;
        case 1:
            self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:fillChamberPart2Time
                                                                  target:self
                                                                selector:@selector(fillChamberPart3:)
                                                                userInfo:nil
                                                                 repeats:NO];
            NSLog(@"Time: %f", fillChamberPart2Time);
            break;
        case 2:
            self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:replaceChamberBottomTime
                                                                  target:self
                                                                selector:@selector(replaceChamberBottomPart2:)
                                                                userInfo:nil
                                                                 repeats:NO];
            NSLog(@"Time: %f", replaceChamberBottomTime);

            break;
        case 3:
            self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:replaceChamberTopTime
                                                                  target:self
                                                                selector:@selector(replaceChamberTopPart2:)
                                                                userInfo:nil
                                                                 repeats:NO];
            NSLog(@"Time: %f", replaceChamberTopTime);

            break;
        case 4:
            self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:emptyChamberTopTime
                                                                  target:self
                                                                selector:@selector(emptyChamberTopPart2:)
                                                                userInfo:nil
                                                                 repeats:NO];
            NSLog(@"Time: %f", emptyChamberTopTime);

            break;
        case 5:
            self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:fillChamberTopTime
                                                                  target:self
                                                                selector:@selector(fillChamberTopPart2:)
                                                                userInfo:nil
                                                                 repeats:NO];
            NSLog(@"Time: %f", fillChamberTopTime);
            
            // Fill chamber bottom has the same time as fill chamber top
        case 6:
            self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:fillChamberTopTime
                                                                  target:self
                                                                selector:@selector(fillChamberBottomPart2:)
                                                                userInfo:nil
                                                                 repeats:NO];
            NSLog(@"Time: %f", fillChamberTopTime);

            break;
        default:
            break;
    }
}






#pragma mark - Helper Functions

- (void)handleEndOfSequenceGUIElements:(BOOL)isEnd {
    if (!isEnd) {
        self.startSequenceButton.hidden = YES;
        self.singleStageSwtich.enabled = NO;
        self.stageStepper.hidden = YES;
        self.chamberSelectionSegmentedControl.hidden = YES;
        self.navigationItem.hidesBackButton = YES;
        self.navigationController.navigationBarHidden = YES;


        [self.startStop setTitle:@"Pause" forState:UIControlStateNormal];

        self.startStop.hidden = NO;
        [self.sequenceActivityIndicator startAnimating];
        
    } else {
        self.startSequenceButton.hidden = NO;
        self.singleStageSwtich.enabled = YES;
        self.stageStepper.hidden = NO;
        self.chamberSelectionSegmentedControl.hidden = NO;
        self.navigationItem.hidesBackButton = NO;
        self.navigationController.navigationBarHidden = NO;




        self.startStop.hidden = YES;
        [self.sequenceActivityIndicator stopAnimating];
    }
}


@end
