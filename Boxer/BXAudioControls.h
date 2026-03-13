/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

/// Pure C/ObjC-safe header for audio effect controls.
/// Does not include any C++ headers, so safe to import from .m files.

#import <Foundation/Foundation.h>

#pragma mark - Audio effect enums

/// Reverb presets matching DOSBox-Staging's ReverbPreset enum.
typedef NS_ENUM(NSInteger, BXReverbPreset) {
    BXReverbPresetNone   = 0,
    BXReverbPresetTiny   = 1,
    BXReverbPresetSmall  = 2,
    BXReverbPresetMedium = 3,
    BXReverbPresetLarge  = 4,
    BXReverbPresetHuge   = 5
};

/// Chorus presets matching DOSBox-Staging's ChorusPreset enum.
typedef NS_ENUM(NSInteger, BXChorusPreset) {
    BXChorusPresetNone   = 0,
    BXChorusPresetLight  = 1,
    BXChorusPresetNormal = 2,
    BXChorusPresetStrong = 3
};

/// Crossfeed strength levels.
typedef NS_ENUM(NSInteger, BXCrossfeedPreset) {
    BXCrossfeedOff    = 0,
    BXCrossfeedLight  = 1,  // 20%
    BXCrossfeedNormal = 2,  // 40%
    BXCrossfeedStrong = 3   // 60%
};

#pragma mark - Audio effect control functions

#ifdef __cplusplus
extern "C" {
#endif

void boxer_setReverbPreset(BXReverbPreset preset);
BXReverbPreset boxer_getReverbPreset(void);

void boxer_setChorusPreset(BXChorusPreset preset);
BXChorusPreset boxer_getChorusPreset(void);

void boxer_setCrossfeedPreset(BXCrossfeedPreset preset);
BXCrossfeedPreset boxer_getCrossfeedPreset(void);

#ifdef __cplusplus
}
#endif
