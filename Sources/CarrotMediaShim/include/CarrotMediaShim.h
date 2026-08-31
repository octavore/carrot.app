#ifndef CARROT_MEDIA_SHIM_H
#define CARROT_MEDIA_SHIM_H

// Entry points loaded into /usr/bin/perl by carrot-media.pl. Each is installed
// as a Perl XSUB via DynaLoader::dl_install_xsub and called with no arguments,
// so every parameter arrives through the environment. See
// research/2026-08-31-mediaremote-perl-adapter.md.

/// Prints one JSON line describing the current now-playing state, then returns.
void carrot_get(void);

/// Prints a JSON line on every change to the now-playing state and never
/// returns. Reads CARROT_DEBOUNCE_MS (default 150).
void carrot_stream(void);

/// Sends the MRCommand id in CARROT_COMMAND (0 = play, 1 = pause,
/// 2 = toggle). Reads CARROT_LINGER_MS (default 1000).
void carrot_send(void);

#endif
