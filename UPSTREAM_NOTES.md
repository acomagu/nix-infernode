# Infernode Upstream Notes

Target upstream repository: <https://github.com/infernode-os/infernode>

This note collects behaviors observed while packaging and running the `v0.1.3` Linux GUI release on Nix/Linux.

These notes are intentionally conservative:

- they describe issues that look likely to belong upstream rather than to downstream Nix packaging
- but they have not been exhaustively verified across all supported operating systems or runtime configurations
- so they should be read as packaging observations and hypotheses, not as fully established upstream bug reports

For that reason, this file is mainly a memo for future upstream investigation, not a polished issue list.

## Most likely upstream-facing issues

### `tools9p` appears not to fully respect `-m <mountpoint>`

On the tested Linux/Nix setup, starting `tools9p` with `-m /tmp/tool` was not sufficient by itself. The runtime still appeared to derive sibling paths such as `/tool.1`, which failed under ordinary unprivileged Linux execution.

This suggests that some internal path handling may still be anchored to `/tool` even when another mountpoint is requested.

What would ideally be true:

- if `tools9p` is started with `-m /tmp/tool`, derived paths should also be based on `/tmp/tool`
- no internal logic should assume `/tool` or `/tool.*` unless `/tool` was explicitly requested

This has only been investigated on the Linux GUI release and should be rechecked against upstream source and other runtime environments.

### `lucibridge` also seems to assume `/tool.*`

On the same setup, `lucibridge` also appeared to depend on `/tool.1`-style paths. Even after adjusting the launcher to start `tools9p` on `/tmp/tool`, the bridge still behaved as if `/tool.1` were expected.

This suggests that `lucibridge` may share the same hardcoded mountpoint assumption.

What would ideally be true:

- `lucibridge` should discover the active tool mount from runtime state or configuration
- it should not assume `/tool` or `/tool.*` if another mountpoint is being used

As above, this is based on Linux/Nix observations and should be verified more directly in upstream source.

## Release layout and first-run setup

### The release tarball may rely on mountpoint directories that are not present in the archive

In the tested `v0.1.3` Linux GUI tarball, the expected empty directories under `resources/n/...` and `resources/tool` did not appear to be included in the archive.

At least on the tested setup, the runtime still seemed to expect those mountpoints to exist.

That suggests one of two upstream improvements:

- include those directories in the release artifact, or
- create them explicitly and reliably at startup

This may or may not matter on every platform, but on the tested Linux packaging path it was significant.

### First-run theme seeding seems incomplete

On first run, the writable overlay seeded `/lib/lucifer/theme/current`, then overlaid the whole `/lib/lucifer/theme` directory.

On the tested setup, this could leave the selected theme name present while the actual theme contents were missing from the writable layer, leading to:

`[Lucitheme] Broken: "dereference of nil"`

The likely upstream-side improvement would be:

- seed `current`
- and also seed the actual default theme assets such as `brimstone` and `halo`, or otherwise avoid hiding the readonly theme directory before the writable layer is ready

This behavior was observed in practice, but the exact intended overlay semantics should be confirmed upstream.

## Linux GUI runtime dependencies

### The bundled SDL3 may not be sufficient on all Linux setups

On the tested Linux/Nix environment, the bundled `libSDL3.so.0` did not work reliably and had to be replaced with the system `sdl3`.

This may indicate one of several things:

- the bundled SDL was built without the expected Linux backends
- the release assumes host-provided graphics stack details that were not present in the test environment
- or the failure is specific to this packaging/runtime combination

Because this was not validated across multiple Linux distributions or non-Nix setups, it should be treated as a strong packaging observation rather than a confirmed upstream defect.

Still, it would be useful upstream to confirm:

- whether the bundled SDL is expected to support Wayland and X11 in the Linux GUI release
- or whether the release is intentionally expected to use a system SDL instead

## Fractional scaling behavior

On the tested Linux GUI setup, fractional scaling interacted badly with Inferno subfonts: text became either unreadable or blurry depending on font size and backend behavior.

This may not be a strict bug, but it looks like an area where upstream behavior and expectations are unclear.

Potential upstream work could include:

- documenting expected behavior under fractional scaling
- setting SDL scaling-related hints in the launcher
- improving DPI-awareness or font rendering strategy

This note does not claim that current behavior is universally wrong, only that it was problematic in the tested environment.

## Documentation gaps

### Hosted Linux runtime assumptions could be documented more explicitly

The Linux GUI release seems to rely on several assumptions that were not obvious from the quick start alone, including:

- hosted filesystem bridges such as `/n/local`
- writable runtime mountpoints for tool and namespace services
- working GUI backend availability
- writable overlay behavior for secstore, config, and theme state

Even if all of these are intentional, documenting them more explicitly would make downstream packaging and debugging much easier.

## Practical takeaway

The most likely upstream-side improvements, based on the tested Linux/Nix behavior, are:

1. make `tools9p` fully mountpoint-relative
2. make `lucibridge` follow the same mountpoint contract

If those two points are addressed upstream, the downstream package should become much simpler.

Until broader cross-platform validation is done, though, these should be treated as informed notes rather than finalized upstream conclusions.
