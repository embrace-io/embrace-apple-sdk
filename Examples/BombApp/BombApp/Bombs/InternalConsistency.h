//
//  InternalInconsistency.h
//  BombApp
//
//  Created by Ariel Demarco on 02/07/2024.
//

#import <Foundation/Foundation.h>
#import "CRLCrash.h"

NS_ASSUME_NONNULL_BEGIN

@interface InternalConsistency : CRLCrash

- (void)crash __attribute__((noreturn));

@end

NS_ASSUME_NONNULL_END
