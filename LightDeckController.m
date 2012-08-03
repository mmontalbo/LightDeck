//
//  LightDeckController.m
//  ArduinoSerial
//
//  Created by Florian Maurer on 2/26/12.
//  Copyright (c) 2012 2215 22nd St. All rights reserved.
//

#define PARCAN_CHANNEL_THRESHOLD 6
#define MEGAPANEL_CHANNEL_THRESHOLD 7
#define TRIPHASE_CHANNEL_THRESHOLD 8

#define MEGAPANEL_CHANNEL_BASE 37
#define TRIPHASE_CHANNEL_BASE 41

typedef enum {
    kLightParcan,
    kLightMegapanel,
    kLightTriphase,
    kLightUnknown
} LightIdentifier;

#import "LightDeckController.h"
#import "DMXChannel.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"

@interface LightDeckController()
- (void)setDMXChannelsForParcan:(NSNumber *)lightNumber params:(NSDictionary *)params;
- (void)setDMXChannelsForMegapanel:(NSNumber *)lightNumber params:(NSDictionary *)params;
- (void)setDMXChannelsForTriphase:(NSNumber *)lightNumber params:(NSDictionary *)params;
- (LightIdentifier)getLightIDFromChannel:(NSNumber *)lightNumber;
- (void)setChannelsFromRGBString:(int)channelBase rgbString:(NSString *)rgbString;
- (NSNumber *)getNumberFromString:(NSString *)floatString;
@end

@implementation LightDeckController

@synthesize activeChannels;
@synthesize dmxchannels = _dmxchannels;
@synthesize port = _port;
@synthesize deviceName;

- (id) init {
    
    if (self = [super init]) {
        self.deviceName = @"";
        
        // Initialize dmx channel values
        self.dmxchannels = [[[DMXChannels alloc] init] autorelease];
        
        //listen for change to lights from httpServer  
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(lightsChanged:) name:@"PostReceived" object:nil];
        
        //listen for change to different device selection
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(selectedDevice:) name:@"DeviceSelected" object:nil];
        
        /// set up notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddPorts:) name:AMSerialPortListDidAddPortsNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemovePorts:) name:AMSerialPortListDidRemovePortsNotification object:nil];
        
        /// initialize port list to arm notifications
        [AMSerialPortList sharedPortList];
        
        if(self.port) {
            [self initPort];
        }
        
        return self;
        
    }
    
    return self;
}

- (void)awakeFromNib {
}

//event handler when event occurs
-(void)lightsChanged: (NSNotification *) notification
{
    [self setLights:notification.userInfo];
}

- (void)selectedDevice: (NSNotification *) notification{
    self.deviceName = [notification.userInfo objectForKey:@"dev"];
    NSLog(@"%@",self.deviceName);
}

-(void) setLights:(NSDictionary*)parameters {
    
    
    for (NSNumber *lightNumber in [parameters objectForKey:@"lights"]) {
        LightIdentifier identifier = [self getLightIDFromChannel:lightNumber];
        if (identifier == kLightParcan) {
            [self setDMXChannelsForParcan:lightNumber params:parameters];
        } else if (identifier == kLightMegapanel) {
            [self setDMXChannelsForMegapanel:lightNumber params:parameters];
        } else if (identifier == kLightTriphase) {
            [self setDMXChannelsForTriphase:lightNumber params:parameters];
        }
        
    }
    
    [self sendDMXSerialString];
    /*if (writeError) {
     NSLog(@"Write error: %@",writeError);
     }
     NSLog(@"%@", [[NSString alloc] initWithBytes:&serialData length:sizeof(serialData) encoding:NSASCIIStringEncoding]);
     */
}

#pragma mark - Light type handlers
- (void)setDMXChannelsForParcan:(NSNumber *)lightNumber params:(NSDictionary *)params {
    int lightChannelBase = ([lightNumber intValue]-1)*7;
    
    for( NSString *aKey in params)
    {
        if ([aKey isEqualToString:@"brightness"]){
            NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
            [f setNumberStyle:NSNumberFormatterDecimalStyle];
            NSNumber *tempBrightness = [f numberFromString:[params objectForKey:aKey]];
            /* The following line is a hack to make it work: it assumes all the lights have identical channels to multiply by 7
             
             The correct solution would be another function setValueOf:dmxChannel forLight:identifier which uses the below method
             
             (lightNum -1 ) * 7 + channel
             
             */
            [self.dmxchannels setChannel:[NSNumber numberWithInt:[lightNumber intValue]*7] toValue:tempBrightness];
            //NSLog(@"%@",tempBrightness);
            [f release];
        }
        if ([aKey isEqualToString:@"color"]){
            NSString *tempColor = [params objectForKey:aKey];
            
            if ([tempColor isEqualToString:@"red"]) {
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+1] toValue:[NSNumber numberWithInt:1]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+2] toValue:[NSNumber numberWithInt:0]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+3] toValue:[NSNumber numberWithInt:0]];
            }
            
            if ([tempColor isEqualToString:@"purple"]) {
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+1] toValue:[NSNumber numberWithInt:1]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+2] toValue:[NSNumber numberWithInt:0]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+3] toValue:[NSNumber numberWithInt:1]];
            }
            
            if ([tempColor isEqualToString:@"blue"]) {
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+1] toValue:[NSNumber numberWithInt:0]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+2] toValue:[NSNumber numberWithInt:0]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+3] toValue:[NSNumber numberWithInt:1]];
            }
            
            if ([tempColor isEqualToString:@"teal"]) {
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+1] toValue:[NSNumber numberWithInt:0]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+2] toValue:[NSNumber numberWithInt:1]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+3] toValue:[NSNumber numberWithInt:1]];
            }
            
            if ([tempColor isEqualToString:@"green"]) {
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+1] toValue:[NSNumber numberWithInt:0]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+2] toValue:[NSNumber numberWithInt:1]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+3] toValue:[NSNumber numberWithInt:0]];
            }
            
            if ([tempColor isEqualToString:@"white"]) {
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+1] toValue:[NSNumber numberWithInt:1]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+2] toValue:[NSNumber numberWithInt:1]];
                [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+3] toValue:[NSNumber numberWithInt:1]];
            }
            if ([aKey isEqualToString:@"rgb"]){            
                NSString *rgbString = [params objectForKey:aKey];
                [self setChannelsFromRGBString:lightChannelBase rgbString:rgbString];                        
            }  
            
            
            //NSLog(@"%@",tempBrightness);
        }  
    }
}

- (void)setDMXChannelsForMegapanel:(NSNumber *)lightNumber params:(NSDictionary *)params {
    int lightChannelBase = MEGAPANEL_CHANNEL_BASE;
    
    for( NSString *aKey in params)
    {
        if ([aKey isEqualToString:@"rgb"]){            
            NSString *rgbString = [params objectForKey:aKey];
            [self setChannelsFromRGBString:lightChannelBase rgbString:rgbString];                        
        }  else if ([aKey isEqualToString:@"brightness"]){
            NSNumber *brightnessVal = [self getNumberFromString:[params objectForKey:aKey]];
            [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+4] toValue:brightnessVal];
        }
    }
}

- (void)setDMXChannelsForTriphase:(NSNumber *)lightNumber params:(NSDictionary *)params {
    int lightChannelBase = TRIPHASE_CHANNEL_BASE;
    
    for( NSString *aKey in params)
    {
        if ([aKey isEqualToString:@"color_selection"]){            
            NSNumber *colorSelectionVal = [self getNumberFromString:[params objectForKey:aKey]];            
            [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase] toValue:colorSelectionVal];
        } else if ([aKey isEqualToString:@"rotation"]){
            NSNumber *rotationVal = [self getNumberFromString:[params objectForKey:aKey]];
            [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+1] toValue:rotationVal];
        } else if ([aKey isEqualToString:@"strobe"]){
            NSNumber *strobeVal = [self getNumberFromString:[params objectForKey:aKey]];
            [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+2] toValue:strobeVal];
        }  else if ([aKey isEqualToString:@"brightness"]){
            NSNumber *brightnessVal = [self getNumberFromString:[params objectForKey:aKey]];
            [self.dmxchannels setChannel:[NSNumber numberWithInt:lightChannelBase+3] toValue:brightnessVal];
        }
    }
}

#pragma mark - Helpers
- (NSNumber *)getNumberFromString:(NSString *)floatString {
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    
    NSNumber *tempVal = [f numberFromString:floatString];
    [f release];
    
    return tempVal;
}

- (void)setChannelsFromRGBString:(int)channelBase rgbString:(NSString *)rgbString {
    NSArray *colorVals = [rgbString componentsSeparatedByString:@","];
    
    int i = 0;
    for (NSString *colorVal in colorVals) {
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];        
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        
        NSNumber *tColor = [f numberFromString:colorVal];
        [f release];
        
        float cVal = [tColor floatValue];
        
        [self.dmxchannels setChannel:[NSNumber numberWithInt:channelBase+i] toValue:[NSNumber numberWithFloat:cVal/255.0]];
        i++;
    }
}

- (LightIdentifier)getLightIDFromChannel:(NSNumber *)lightNumber { 
    
    if ([lightNumber intValue] <= PARCAN_CHANNEL_THRESHOLD) {
        return kLightParcan;
    } else if([lightNumber intValue] <= MEGAPANEL_CHANNEL_THRESHOLD) {
        return kLightMegapanel;
    } else if([lightNumber intValue] <= TRIPHASE_CHANNEL_THRESHOLD) {
        return kLightTriphase;
    } else {
        return kLightUnknown;
    }
}

# pragma mark Serial Port Stuff

-(void) sendDMXSerialString {
    NSMutableData *serialData = [self.dmxchannels generateSerialData];
    NSError *writeError;
    [self.port writeData:[serialData retain] error:&writeError];
    [serialData release];
}

- (void)initPort
{
    NSString *currentDevName = self.deviceName;
    if (![currentDevName isEqualToString:[self.port bsdPath]]) {
        [self.port close];
        
        [self setPort:[[[AMSerialPort alloc] init:currentDevName withName:currentDevName type:(NSString*)CFSTR(kIOSerialBSDModemType)] autorelease]];
        [self.port setDelegate:self];
        
        if ([self.port open]) {
            
            //Then I suppose we connected!
            NSLog(@"successfully connected");
            
            //[connectButton setEnabled:NO];
            //[sendButton setEnabled:YES];
            //[serialScreenMessage setStringValue:@"Connection Successful!"];
            
            //TODO: Set appropriate baud rate here. 
            
            //The standard speeds defined in termios.h are listed near
            //the top of AMSerialPort.h. Those can be preceeded with a 'B' as below. However, I've had success
            //with non standard rates (such as the one for the MIDI protocol). Just omit the 'B' for those.
            
            [self.port setSpeed:B115200]; 
            
            
            // listen for data in a separate thread
            [self.port readDataInBackground];
            
            
        } else { // an error occured while creating port
            
            NSLog(@"error connecting");
            //[serialScreenMessage setStringValue:@"Error Trying to Connect..."];
            [self setPort:nil];
            
        }
    }
}

@end
