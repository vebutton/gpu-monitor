// IOReport private API declarations for Apple Silicon GPU monitoring.
// These live in /usr/lib/libIOReport.dylib (private, undocumented).
// Used by Activity Monitor, powermetrics, macmon, Anubis, NeoAsitop.
// Signatures sourced from exelban/stats and op06072/NeoAsitop.

#ifndef IOREPORT_H
#define IOREPORT_H

#include <CoreFoundation/CoreFoundation.h>

// Opaque subscription handle
typedef struct IOReportSubscription *IOReportSubscriptionRef;

// Channel discovery — find channels in a named group/subgroup.
// "Copy" → caller owns the result (CF_RETURNS_RETAINED).
CF_RETURNS_RETAINED
CFDictionaryRef _Nullable IOReportCopyChannelsInGroup(
    CFStringRef _Nonnull group,
    CFStringRef _Nullable subgroup,
    uint64_t a,
    uint64_t b,
    uint64_t c
);

// Create a subscription for periodic sampling.
IOReportSubscriptionRef _Nullable IOReportCreateSubscription(
    void * _Nullable a,
    CFMutableDictionaryRef _Nonnull desiredChannels,
    CFMutableDictionaryRef _Nullable * _Nullable subbedChannels,
    uint64_t channel_id,
    CFTypeRef _Nullable b
);

// Take a snapshot of current channel values.
// "Create" → caller owns the result.
CF_RETURNS_RETAINED
CFDictionaryRef _Nullable IOReportCreateSamples(
    IOReportSubscriptionRef _Nonnull subscription,
    CFMutableDictionaryRef _Nonnull channels,
    CFTypeRef _Nullable a
);

// Compute delta between two snapshots.
// "Create" → caller owns the result.
CF_RETURNS_RETAINED
CFDictionaryRef _Nullable IOReportCreateSamplesDelta(
    CFDictionaryRef _Nonnull prev,
    CFDictionaryRef _Nonnull current,
    CFTypeRef _Nullable a
);

// Merge channels from source into dest.
void IOReportMergeChannels(
    CFMutableDictionaryRef _Nonnull dest,
    CFDictionaryRef _Nonnull source,
    CFTypeRef _Nullable reserved
);

// Extract integer value from a channel sample.
int64_t IOReportSimpleGetIntegerValue(
    CFDictionaryRef _Nonnull channel,
    int32_t index
);

// State-based channel accessors — for channels with multiple states (residency data).
int IOReportStateGetCount(CFDictionaryRef _Nonnull channel);
int64_t IOReportStateGetResidency(CFDictionaryRef _Nonnull channel, int stateIndex);
CF_RETURNS_NOT_RETAINED
CFStringRef _Nullable IOReportStateGetNameForIndex(CFDictionaryRef _Nonnull channel, int stateIndex);
int64_t IOReportStateGetInTransitions(CFDictionaryRef _Nonnull channel, int stateIndex);

// Channel format — returns the channel type (1=Simple, 2=State, 3=Histogram, etc.)
int IOReportChannelGetFormat(CFDictionaryRef _Nonnull channel);

// Channel metadata accessors — "Get" → not owned.
CF_RETURNS_NOT_RETAINED
CFStringRef _Nullable IOReportChannelGetChannelName(CFDictionaryRef _Nonnull channel);
CF_RETURNS_NOT_RETAINED
CFStringRef _Nullable IOReportChannelGetGroup(CFDictionaryRef _Nonnull channel);
CF_RETURNS_NOT_RETAINED
CFStringRef _Nullable IOReportChannelGetSubGroup(CFDictionaryRef _Nonnull channel);
CF_RETURNS_NOT_RETAINED
CFStringRef _Nullable IOReportChannelGetUnitLabel(CFDictionaryRef _Nonnull channel);

#endif // IOREPORT_H
