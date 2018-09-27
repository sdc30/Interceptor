//
//  main.m
//  Interceptor
//
//  Created by Stephen Cartwright on 9/11/18.
//  Copyright © 2018 Ōmagatoki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSAlert.h>
#import <QuartzCore/QuartzCore.h>

FILE *logFile = NULL;
CFTimeInterval lastAttemptedQuit;
CGEventRef nonPromptCallback(CGEventTapProxy, CGEventType, CGEventRef, void *);
CGEventRef promptCallback(CGEventTapProxy, CGEventType, CGEventRef, void *);

int main(int argc, const char * argv[])
{
	
	@autoreleasepool {
		CFRunLoopSourceRef runLoopSource;
		CGEventFlags oldFlags = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
	
		CGEventMask eventMask = (CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged) | CGEventMaskBit(kCGEventKeyUp));
		CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, eventMask, nonPromptCallback, &oldFlags);
		
		if (!eventTap)
		{
			NSLog(@"Exiting..");
			exit(1);
		}
		
		runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
		
		CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
		
		CGEventTapEnable(eventTap, true);
		
		CFRunLoopRun();
		
		CFRelease(eventTap);
		CFRelease(runLoopSource);
	}
	
	return 0;
}

// Maybe a todo if I can figure out why the runloop stops? perhaps a non keyboard event is
// disallowing? or maybe the keydown expects a keyup event for the same key, not a NULL?
CGEventRef promptCallback(CGEventTapProxy proxy,
							 CGEventType type,
							 CGEventRef event,
							 void *refcon)
{
	if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) && (type != kCGEventFlagsChanged))
	{
		return event;
	}
	
	CGEventFlags flags = CGEventGetFlags(event);
	BOOL isCommandKeyPressed = (flags & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand;
	BOOL isKeyDown = (type != kCGEventFlagsChanged) && (type != kCGEventKeyUp);
	
	if (isKeyDown && isCommandKeyPressed)
	{
		// Can't be a kCGEventFlagsChanged event
		NSEvent *keyEvent = [NSEvent eventWithCGEvent:event];
		BOOL isQKeyEvent = ([[keyEvent charactersIgnoringModifiers] isEqualToString:@"c"] || [[keyEvent charactersIgnoringModifiers] isEqualToString:@"C"]);
		
		if (isQKeyEvent)
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"Do you want to quit?"];
			[alert addButtonWithTitle:@"Ok"];
			[alert addButtonWithTitle:@"Cancel"];
			
			NSInteger button = [alert runModal];
			if (button == NSAlertFirstButtonReturn) {
				return event;
			} else if (button == NSAlertSecondButtonReturn) {
				return NULL;
			}
		}
	}

	return event;
}

CGEventRef nonPromptCallback(CGEventTapProxy proxy,
							 CGEventType type,
							 CGEventRef event,
							 void *refcon)
{
	/*
	 http://osxbook.com/book/bonus/chapter2/alterkeys/
	 https://stackoverflow.com/questions/16444024/how-to-discard-commandshiftq-command-in-mac-os-x-objective-c-code
	 >>> https://stackoverflow.com/questions/4420995/obtaining-modifier-key-pressed-in-cgevent-tap
	 //		 These are bit masks, which will be bitwise-ORed together into the value you receive from CGEventGetFlags (or pass when creating an event yourself).
	 //
	 //		 You can't test equality here because no single bit mask will be equal to a combination of multiple bit masks. You need to test equality of a single bit.
	 //
	 //		 To extract a single bit mask's value from a combined bit mask, use the bitwise-AND (&) operator. Then, compare that to the single bit mask you're interested in:
	 //
	 //		 BOOL commandKeyIsPressed = (flagsP & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand;
	 //		 Why both?
	 //
	 //		 The & expression evaluates to the same type as its operands, which is CGEventFlags in this case, which may not fit in the size of a BOOL, which is a signed char. The == expression resolves that to 1 or 0, which is all that will fit in a BOOL.
	 //
	 //		 Other solutions to that problem include negating the value twice (!!) and declaring the variable as bool or _Bool rather than Boolean or BOOL. C99's _Bool type (synonymized to bool when you include stdbool.h) forces its value to be either 1 or 0, just as the == and !! solutions do.
	 
	 https://stackoverflow.com/questions/44396256/parsing-keyboard-shortcuts-from-cgevent
	 https://stackoverflow.com/questions/5718587/send-auto-repeated-key-using-coregraphics-methods-mac-os-x-snow-leopard
	 https://github.com/caseyscarborough/keylogger/blob/master/keylogger.c
	 
	 What (type of event) am I?
	 If I'm not a KeyDown and I'm not a KeyUp and I'm not a KeyFlagsChanged, then I must be something else.
	 ex : 10
	 type != KeyDown ? (10 != 10) false
	 type != KeyUp ? (10 != 11) true
	 type != KeyFlagsChanged ? (10 != 12) true
	 
	 f || t || t -> t (if we are a valid keyboard event we will discard it like this, so it has to be &&)
	 
	 f && t && t -> f then we return event like we should (non keyboard event)
	 */
	
	CGEventFlags flags;
	BOOL isCommandKeyPressed;
	BOOL isKeyDown;
	NSEvent *keyEvent;
	BOOL isQKeyEvent;
	
	// Only want to setup timer once
	static BOOL timerWasSet;
	static dispatch_once_t didSetTimer;
	dispatch_once(&didSetTimer, ^{
		timerWasSet = NO;
	});
	
	if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) && (type != kCGEventFlagsChanged))
	{
		return event;
	}
	
	flags = CGEventGetFlags(event);
	isCommandKeyPressed = (flags & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand;
	isKeyDown = (type != kCGEventFlagsChanged) && (type != kCGEventKeyUp);
	
	// On a KeyUp we don't want to fire (essentially a double fire)
	if (isKeyDown && isCommandKeyPressed)
	{
		// Can't be a kCGEventFlagsChanged event
		keyEvent = [NSEvent eventWithCGEvent:event];
		isQKeyEvent = ([[keyEvent charactersIgnoringModifiers] isEqualToString:@"q"] || [[keyEvent charactersIgnoringModifiers] isEqualToString:@"Q"]);
		
		if (isQKeyEvent)
		{
			NSLog(@"Q Key Event");
			if (!timerWasSet)
			{
				// First time reject a quit
				NSLog(@"Init timer");
				lastAttemptedQuit = CACurrentMediaTime();
				timerWasSet = YES;
				return NULL;
			}
			else
			{
				// Reject if we haven't tried to repeat 'Quit' in less than half a second
				if (CACurrentMediaTime() - lastAttemptedQuit > 0.5)
				{
					NSLog(@"Q Key Event: Reject");
					lastAttemptedQuit = CACurrentMediaTime();
					return NULL;
				}
				else
				{
					// Guess we really want to exit
					NSLog(@"Q Key Event: Accept");
					lastAttemptedQuit = CACurrentMediaTime();
					return event;
				}
			}
		}
	}
	
	return event;
}
