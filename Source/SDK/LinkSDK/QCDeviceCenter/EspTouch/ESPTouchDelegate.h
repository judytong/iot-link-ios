//
//  ESPTouchDelegate.h
//  EspTouchDemo
//
//

#import <Foundation/Foundation.h>
#import "ESPTouchResult.h"


@protocol ESPTouchDelegate <NSObject>

/**
 * when new esptouch result is added, the listener will call
 * onEsptouchResultAdded callback
 *
 * @param result
 *            the Esptouch result
 */
-(void) onEsptouchResultAddedWithResult: (ESPTouchResult *) result;

@end
