# nix-infernode

Nix flake for running the Infernode `v0.1.3` Linux GUI release.

Target upstream repository: <https://github.com/infernode-os/infernode>

## Usage

Run directly from GitHub:

```bash
nix run github:acomagu/nix-infernode
```

Build only:

```bash
nix build github:acomagu/nix-infernode
```

Use as a flake input:

```nix
{
  inputs.nix-infernode.url = "github:acomagu/nix-infernode";
}
```

Then run:

```bash
nix run github:acomagu/nix-infernode
```

Or, from another flake, reference `inputs.nix-infernode.packages.${system}.default` or `inputs.nix-infernode.apps.${system}.default`.

## What This Flake Does

This flake repackages the upstream archive:

- `https://github.com/infernode-os/infernode/releases/download/v0.1.3/infernode-0.1.3-linux-amd64-gui.tar.gz`

It applies the following changes on top of the upstream release.

### Source-level text patches

- Applies [patches/profile-seed-themes.patch](patches/profile-seed-themes.patch) so first-run theme seeding copies `brimstone` and `halo` in addition to `current`
- Applies [patches/boot-tool-mount.patch](patches/boot-tool-mount.patch) so the GUI boot path starts `tools9p` on `/tmp/tool` and then binds it to `/tool`
- Applies [patches/lucifer-start-tool-mount.patch](patches/lucifer-start-tool-mount.patch) so `lucifer-start.sh` does the same

### Packaging fixes

- Unpacks the upstream tarball once, applies text patches with `pkgs.applyPatches`, then packages the patched tree
- Recreates missing runtime mountpoint directories under `resources/n/...` and `resources/tool`
- Replaces the bundled `bin/libSDL3.so.0` with Nixpkgs `sdl3`

### Binary patching

- Patches `resources/dis/veltro/tools9p.dis` to replace `/tool.` with `/tmp/.`
- Patches `resources/dis/lucibridge.dis` to replace `/tool.` with `/tmp/.`

These two binary patches work around upstream runtime components that still derive `/tool.1`-style paths even when launched with `-m /tmp/tool`.

### Runtime wrapper behavior

The generated `infernode` launcher:

- `cd`s into the extracted Infernode directory before starting `./infernode`
- Uses a writable runtime home at `${XDG_STATE_HOME:-$HOME/.local/state}/infernode-host`
- Falls back to `/tmp/infernode-host` if that state directory cannot be created
- Sets `SDL_VIDEODRIVER=wayland` on Wayland sessions
- Sets `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1` on Wayland to reduce fractional-scaling issues
- Sets `SDL_VIDEODRIVER=x11` on X11 sessions
- Sets `SDL_VIDEO_X11_SCALING_FACTOR=1` on X11 to avoid SDL-side content scaling
- Prepends the packaged `bin` directory to `LD_LIBRARY_PATH`

## Exposed Outputs

- `packages.x86_64-linux.default`
- `apps.x86_64-linux.default`

The app entrypoint runs:

- `./infernode`

from inside the packaged upstream release tree.

## Upstream Notes

Notes about changes that should ideally be fixed in Infernode itself are in [UPSTREAM_NOTES.md](UPSTREAM_NOTES.md).
