#import <Foundation/Foundation.h>
#include <dlfcn.h>

#import "include/CarrotMediaShim.h"

// This library is never loaded by Carrot itself. It is loaded into
// /usr/bin/perl, whose code-signing identifier is com.apple.perl, because since
// macOS 15.4 MediaRemote only answers processes whose identifier starts with
// com.apple. The same call from Carrot's own process returns an empty
// dictionary. See research/2026-08-31-mediaremote-perl-adapter.md.

typedef void (*MRGetNowPlayingInfo)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetIsPlaying)(dispatch_queue_t, void (^)(Boolean));
typedef Boolean (*MRSendCommand)(int, CFDictionaryRef);
typedef void (*MRRegisterForNotifications)(dispatch_queue_t);

static NSString *const kTitle = @"kMRMediaRemoteNowPlayingInfoTitle";
static NSString *const kArtist = @"kMRMediaRemoteNowPlayingInfoArtist";
static NSString *const kAlbum = @"kMRMediaRemoteNowPlayingInfoAlbum";
static NSString *const kRate = @"kMRMediaRemoteNowPlayingInfoPlaybackRate";

static void *mediaRemote(void) {
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    });
    return handle;
}

static void *mediaRemoteSymbol(const char *name) {
    void *handle = mediaRemote();
    return handle ? dlsym(handle, name) : NULL;
}

/// Reads an exported NSString* constant. The symbol has to be dereferenced;
/// using its own spelling as the value happens to work for the notification
/// names but is not guaranteed, and fails silently when it doesn't.
static NSString *mediaRemoteConstant(const char *name) {
    NSString *const *pointer = (NSString *const *)mediaRemoteSymbol(name);
    return pointer ? *pointer : nil;
}

static double envDouble(const char *name, double fallback) {
    const char *value = getenv(name);
    return value && *value ? atof(value) : fallback;
}

#pragma mark - State

/// The subset of the now-playing info Carrot uses. Everything else MediaRemote
/// returns (artwork, timing, identifiers) is deliberately dropped: the overlay
/// shows a title, an artist and a play/pause button, and artwork alone would be
/// several hundred kilobytes of base64 per update.
@interface CarrotMediaState : NSObject
@property(nonatomic) BOOL playing;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *artist;
@property(nonatomic, copy) NSString *album;
@end

@implementation CarrotMediaState

- (BOOL)isEqualToState:(CarrotMediaState *)other {
    if (!other) return NO;
    BOOL (^same)(NSString *, NSString *) = ^(NSString *a, NSString *b) {
        return (BOOL)((a == nil && b == nil) || [a isEqualToString:b]);
    };
    return self.playing == other.playing && same(self.title, other.title)
        && same(self.artist, other.artist) && same(self.album, other.album);
}

- (NSString *)jsonLine {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"playing"] = @(self.playing);
    if (self.title.length) payload[@"title"] = self.title;
    if (self.artist.length) payload[@"artist"] = self.artist;
    if (self.album.length) payload[@"album"] = self.album;

    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    if (!data) return @"{\"playing\":false}";
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

/// Reads playing state and metadata together. Both MediaRemote getters are
/// asynchronous, so this blocks on a semaphore for each; the timeout keeps a
/// wedged daemon from hanging the process forever.
static CarrotMediaState *readState(void) {
    MRGetNowPlayingInfo getInfo =
        (MRGetNowPlayingInfo)mediaRemoteSymbol("MRMediaRemoteGetNowPlayingInfo");
    MRGetIsPlaying getIsPlaying =
        (MRGetIsPlaying)mediaRemoteSymbol("MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    if (!getInfo || !getIsPlaying) return nil;

    CarrotMediaState *state = [CarrotMediaState new];
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);

    dispatch_semaphore_t infoDone = dispatch_semaphore_create(0);
    getInfo(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(CFDictionaryRef raw) {
        NSDictionary *info = (__bridge NSDictionary *)raw;
        state.title = info[kTitle];
        state.artist = info[kArtist];
        state.album = info[kAlbum];
        dispatch_semaphore_signal(infoDone);
    });
    dispatch_semaphore_wait(infoDone, timeout);

    dispatch_semaphore_t playingDone = dispatch_semaphore_create(0);
    getIsPlaying(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(Boolean playing) {
        state.playing = playing;
        dispatch_semaphore_signal(playingDone);
    });
    dispatch_semaphore_wait(playingDone, timeout);

    return state;
}

static void emit(CarrotMediaState *state) {
    printf("%s\n", state.jsonLine.UTF8String);
    fflush(stdout);
}

#pragma mark - Entry points

void carrot_get(void) {
    @autoreleasepool {
        CarrotMediaState *state = readState();
        if (!state) {
            fprintf(stderr, "carrot: MediaRemote symbols unavailable\n");
            exit(1);
        }
        emit(state);
    }
}

void carrot_stream(void) {
    @autoreleasepool {
        MRRegisterForNotifications registerForNotifications =
            (MRRegisterForNotifications)mediaRemoteSymbol(
                "MRMediaRemoteRegisterForNowPlayingNotifications");
        if (!registerForNotifications || !mediaRemoteSymbol("MRMediaRemoteGetNowPlayingInfo")) {
            fprintf(stderr, "carrot: MediaRemote symbols unavailable\n");
            exit(1);
        }
        registerForNotifications(dispatch_get_main_queue());

        __block CarrotMediaState *last = nil;
        __block int64_t generation = 0;
        double debounce = envDouble("CARROT_DEBOUNCE_MS", 150) / 1000.0;

        // A single pause produces a burst of notifications, and the read races
        // them: mid-burst reads can still report the old rate. Coalescing on a
        // short delay and only emitting genuine changes keeps the app from
        // flickering between states.
        void (^publish)(void) = ^{
            int64_t mine = ++generation;
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(debounce * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    if (mine != generation) return;
                    CarrotMediaState *current = readState();
                    if (!current || [current isEqualToState:last]) return;
                    last = current;
                    emit(current);
                });
        };

        for (NSString *symbol in @[
                 @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                 @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                 @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
             ]) {
            NSString *name = mediaRemoteConstant(symbol.UTF8String);
            if (!name) continue;
            [NSNotificationCenter.defaultCenter addObserverForName:name
                                                            object:nil
                                                             queue:NSOperationQueue.mainQueue
                                                        usingBlock:^(NSNotification *note) {
                                                            publish();
                                                        }];
        }

        last = readState();
        if (last) emit(last);

        // Carrot closes the pipe when it no longer wants updates, so a write to
        // a dead reader is the shutdown signal rather than an error.
        signal(SIGPIPE, SIG_DFL);
        [NSRunLoop.mainRunLoop run];
    }
}

void carrot_send(void) {
    @autoreleasepool {
        MRSendCommand send = (MRSendCommand)mediaRemoteSymbol("MRMediaRemoteSendCommand");
        if (!send) {
            fprintf(stderr, "carrot: MediaRemote symbols unavailable\n");
            exit(1);
        }

        const char *raw = getenv("CARROT_COMMAND");
        if (!raw || !*raw) {
            fprintf(stderr, "carrot: CARROT_COMMAND not set\n");
            exit(1);
        }
        send(atoi(raw), NULL);

        // MRMediaRemoteSendCommand is asynchronous over XPC and returns true
        // before delivery. Exiting on that return tears down the connection and
        // the command is dropped, with a success value already in hand. Holding
        // the run loop open is what makes pause actually pause.
        [NSRunLoop.mainRunLoop
            runUntilDate:[NSDate dateWithTimeIntervalSinceNow:envDouble("CARROT_LINGER_MS", 1000)
                                 / 1000.0]];
    }
}
