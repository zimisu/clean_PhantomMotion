//
//  JoystickTestViewController.m
//  DJISdkDemo
//
//  Copyright © 2015 DJI. All rights reserved.
//
/**
 *  This file demonstrates how to use the advanced set of methods in DJIFlightController to control the aircraft and how to start the 
 *  simulator. 
 *
 *  Through DJIFlightController,user can make the aircraft enter the virtual stick mode. In this mode, SDK gives the flexibility for user to control the aircraft just like controlling it using the joystick. There are different combinations to control the aircraft in the
 *  virtual stick mode. In this sample, we will control the horizontal movement by velocity. For more information about the virtual stick, 
 *  please refer to the Get Started page on http://developer.dji.com.
 *
 *  Through the simulator object in DJIFlightController, user can test the flight controller interfaces and Mission Manager without PC. In
 *  this sample, we will start/stop the simulator and display the aircraft's state during the simulation.
 *
 */
#import "FCVirtualStickViewController.h"
#import "FCVirtualStickView.h"
#import "DemoUtility.h"

@interface FCVirtualStickViewController ()

@property(nonatomic, weak) IBOutlet FCVirtualStickView* joystickLeft;
@property(nonatomic, weak) IBOutlet FCVirtualStickView* joystickRight;
@property(nonatomic, weak) IBOutlet UIButton* coordinateSys;

@property (weak, nonatomic) IBOutlet UIButton *enableVirtualStickButton;
@property (weak, nonatomic) IBOutlet UIButton *startLeapmotion;

@property (weak, nonatomic) IBOutlet UIButton *simulatorButton;
@property (weak, nonatomic) IBOutlet UILabel *simulatorStateLabel;
@property (weak, nonatomic) IBOutlet UITextView *logFiled;
@property (weak, nonatomic) IBOutlet UILabel *logLabel0;
@property (weak, nonatomic) IBOutlet UILabel *logLabel1;
@property (weak, nonatomic) IBOutlet UILabel *logLabel2;
@property (weak, nonatomic) IBOutlet UILabel *logLabel3;
@property (assign, nonatomic) BOOL isSimulatorOn;
@property (assign, nonatomic) BOOL leapmotionEnable;

-(IBAction) onEnterVirtualStickControlButtonClicked:(id)sender;
-(IBAction) onExitVirtualStickControlButtonClicked:(id)sender;
-(IBAction) onTakeoffButtonClicked:(id)sender;
-(IBAction) onCoordinateSysButtonClicked:(id)sender;
- (IBAction)onSimulatorButtonClicked:(id)sender;
-(IBAction) onStartLeapmotion:(id)sender;

@end

@implementation FCVirtualStickViewController
{
    float mXVelocity;
    float mYVelocity;
    float mYaw;
    float mThrottle;
}

- (void)getLeapmotionData {
    // HTTP GET: get data from leapmotion server
    if (!self.leapmotionEnable) return;
    NSURL *url = [NSURL URLWithString:@"http://172.20.10.2:2333/file.txt"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:nil
                                                     error:nil];
    NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    
    [self.logFiled setText:str];
    
    NSArray *pos = [str componentsSeparatedByString:@":"];
    
    @try {
        if ([pos count]) {
            float k = 0.2;
//            self.logLabel0.text = pos[0];
//            self.logLabel1.text = pos[1];
//            self.logLabel2.text = pos[2];
//            self.logLabel3.text = pos[3];
            mYVelocity = [pos[0] floatValue] * 20;
            mXVelocity = [pos[1] floatValue] * 20;
            mYaw = [pos[2] floatValue] * 30;
            mThrottle = [pos[3] floatValue] * 2;
            [self updateJoystick];
        }
    } @catch (NSException *exception) {
        
    } @finally {
        // set timeout
        if (self.leapmotionEnable) {
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.2);
            dispatch_after(delay, dispatch_get_main_queue(), ^(void){
                [self getLeapmotionData];
            });
        }
    }
    
}

- (void)onStartLeapmotion:(id)sender {
    if (!self.leapmotionEnable) {
        self.leapmotionEnable = YES;
        [self.startLeapmotion setTitle:@"Finish Leapmotion" forState:UIControlStateNormal];
        
        [self getLeapmotionData];
    } else {
        [self.startLeapmotion setTitle:@"Start Leapmotion" forState:UIControlStateNormal];
        self.leapmotionEnable = NO;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver: self
                           selector: @selector (onStickChanged:)
                               name: @"StickChanged"
                             object: nil];
    
    
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc) {
        fc.rollPitchControlMode = DJIVirtualStickFlightCoordinateSystemGround;
    }
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc && fc.simulator) {
        self.isSimulatorOn = fc.simulator.isSimulatorStarted;
        [self updateSimulatorUI];
        
        [fc.simulator addObserver:self forKeyPath:@"isSimulatorStarted" options:NSKeyValueObservingOptionNew context:nil];
        [fc.simulator setDelegate:self];
    }
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.leapmotionEnable = NO;
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc && fc.simulator) {
        [fc.simulator removeObserver:self forKeyPath:@"isSimulatorStarted"];
        [fc.simulator setDelegate:nil];
    }
}

-(IBAction) onExitVirtualStickControlButtonClicked:(id)sender
{
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc) {
        [fc disableVirtualStickControlModeWithCompletion:^(NSError * _Nullable error) {
            if (error){
                ShowResult(@"Exit Virtual Stick Mode: %@", error.debugDescription);
            } else{
                ShowResult(@"Exit Virtual Stick Mode:Succeeded");
            }
        }];
    }
    else
    {
        ShowResult(@"Component not exist.");
    }
}
    
-(IBAction) onEnterVirtualStickControlButtonClicked:(id)sender
{
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc) {
        fc.yawControlMode = DJIVirtualStickYawControlModeAngularVelocity;
        fc.rollPitchControlMode = DJIVirtualStickRollPitchControlModeVelocity;
        
        [fc enableVirtualStickControlModeWithCompletion:^(NSError *error) {
            if (error) {
                ShowResult(@"Enter Virtual Stick Mode:%@", error.description);
            }
            else
            {
                ShowResult(@"Enter Virtual Stick Mode:Succeeded");
            }
        }];
    }
    else
    {
        ShowResult(@"Component not exist.");
    }
}

-(IBAction) onTakeoffButtonClicked:(id)sender
{
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc) {
        [fc takeoffWithCompletion:^(NSError *error) {
            if (error) {
                ShowResult(@"Takeoff:%@", error.description);
            } else {
                ShowResult(@"Takeoff Success. ");
            }
        }];
    }
    else
    {
        ShowResult(@"Component not exist.");
    }
}

-(IBAction) onCoordinateSysButtonClicked:(id)sender
{
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc) {
        if (fc.rollPitchCoordinateSystem == DJIVirtualStickFlightCoordinateSystemGround) {
            fc.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystemBody;
            [_coordinateSys setTitle:NSLocalizedString(@"CoordinateSys:Body", @"") forState:UIControlStateNormal ];
        }
        else
        {
            fc.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystemGround;
            [_coordinateSys setTitle:NSLocalizedString(@"CoordinateSys:Ground", @"") forState:UIControlStateNormal];
        }
    }
    else
    {
        ShowResult(@"Component not exist.");
    }
}

- (IBAction)onSimulatorButtonClicked:(id)sender {
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc && fc.simulator) {
        if (!self.isSimulatorOn) {
            // The initial aircraft's position in the simulator.
            CLLocationCoordinate2D location = CLLocationCoordinate2DMake(22, 113);
            [fc.simulator startSimulatorWithLocation:location updateFrequency:20 GPSSatellitesNumber:10 withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    ShowResult(@"Start simulator error:%@", error.description);
                } else {
                    ShowResult(@"Start simulator succeeded.");
                }
            }];
        }
        else {
            [fc.simulator stopSimulatorWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    ShowResult(@"Stop simulator error:%@", error.description);
                } else {
                    ShowResult(@"Stop simulator succeeded.");
                }
            }];
        }
    }
}

- (void)onStickChanged:(NSNotification*)notification
{
    NSDictionary *dict = [notification userInfo];
    NSValue *vdir = [dict valueForKey:@"dir"];
    CGPoint dir = [vdir CGPointValue];
    
    FCVirtualStickView* joystick = (FCVirtualStickView*)notification.object;
    if (joystick) {
        if (joystick == self.joystickLeft) {
            [self setThrottle:dir.y andYaw:dir.x];
        }
        else
        {
            // To consist with the physical remote controller, the negative Y axis (push up) of the virtual stick is mapped to
            // the X direction of the coordinate (body or ground). The X axis (push right) is mapped to the Y direction of the
            // coordinate (body or ground).
            // If the developer wants to use the angle mode to control the horizontal movement, the mapping between the virtual
            // stick and the aircraft coordinate will be different. 
            [self setXVelocity:-dir.y andYVelocity:dir.x];
        }
    }
}

-(void) setThrottle:(float)y andYaw:(float)x
{
    mThrottle = y * -2;
    mYaw = x * 30;
    
    [self updateJoystick];
}

-(void) setXVelocity:(float)x andYVelocity:(float)y {
    mXVelocity = x * DJIVirtualStickRollPitchControlMaxVelocity;
    mYVelocity = y * DJIVirtualStickRollPitchControlMaxVelocity;
    [self updateJoystick];
}

-(void) updateJoystick
{
    // In rollPitchVelocity mode, the pitch property in DJIVirtualStickFlightControlData represents the Y direction velocity.
    // The roll property represents the X direction velocity.

    DJIVirtualStickFlightControlData ctrlData = {0};
    ctrlData.pitch = mYVelocity;
    ctrlData.roll = mXVelocity;
    ctrlData.yaw = mYaw;
    ctrlData.verticalThrottle = mThrottle;
//    self.logLabel0.text = [NSString stringWithFormat:@"%f", ctrlData.roll];
//    self.logLabel1.text = [NSString stringWithFormat:@"%f", ctrlData.pitch];
//    self.logLabel2.text = [NSString stringWithFormat:@"%f", ctrlData.yaw];
//    self.logLabel3.text = [NSString stringWithFormat:@"%f", ctrlData.verticalThrottle];
    DJIFlightController* fc = [DemoComponentHelper fetchFlightController];
    if (fc && fc.isVirtualStickControlModeAvailable) {
        [fc sendVirtualStickFlightControlData:ctrlData withCompletion:nil];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isSimulatorStarted"]) {
        self.isSimulatorOn = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        [self updateSimulatorUI];
    }
}

-(void) updateSimulatorUI {
    if (!self.isSimulatorOn) {
        [self.simulatorButton setTitle:@"Start Simulator" forState:UIControlStateNormal];
        [self.simulatorStateLabel setHidden:YES];
    }
    else {
        [self.simulatorButton setTitle:@"Stop Simulator" forState:UIControlStateNormal];
    }
}

#pragma mark - Delegate

-(void)simulator:(DJISimulator *)simulator updateSimulatorState:(DJISimulatorState *)state {
    [self.simulatorStateLabel setHidden:NO];
    self.simulatorStateLabel.text = [NSString stringWithFormat:@"Yaw: %f\nX: %f Y: %f Z: %f", state.yaw, state.positionX, state.positionY, state.positionZ];
}

@end
