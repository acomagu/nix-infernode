{
  description = "Infernode 0.1.3 GUI release wrapper";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          version = "0.1.3";
          rawSrc = pkgs.fetchurl {
            url = "https://github.com/infernode-os/infernode/releases/download/v${version}/infernode-${version}-linux-amd64-gui.tar.gz";
            hash = "sha256-KIjibJ2oUBm8ynQ6/77UwuiLXVQmMg3rWWpv8Acvdow=";
          };
          unpackedSrc = pkgs.runCommandLocal "infernode-${version}-src" { } ''
            mkdir -p "$out"
            ${pkgs.gnutar}/bin/tar -xzf ${rawSrc} -C "$out" --strip-components=1
          '';
          patchedSrc = pkgs.applyPatches {
            name = "infernode-${version}-patched-src";
            src = unpackedSrc;
            patches = [
              ./patches/profile-seed-themes.patch
              ./patches/boot-tool-mount.patch
              ./patches/lucifer-start-tool-mount.patch
            ];
          };
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
            pname = "infernode";
            inherit version;
            src = patchedSrc;

            nativeBuildInputs = [
              pkgs.perl
            ];

            dontUnpack = true;

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/share" "$out/bin"
              mkdir -p "$out/share/infernode"
              cp -a "$src"/. "$out/share/infernode"/
              chmod -R u+w "$out/share/infernode"
              mkdir -p \
                "$out/share/infernode/resources/n/local/home" \
                "$out/share/infernode/resources/n/ui" \
                "$out/share/infernode/resources/n/speech" \
                "$out/share/infernode/resources/n/llm" \
                "$out/share/infernode/resources/n/wallet" \
                "$out/share/infernode/resources/tool"
              rm -f "$out/share/infernode/bin/libSDL3.so.0"
              ln -s "${pkgs.sdl3}/lib/libSDL3.so.0" "$out/share/infernode/bin/libSDL3.so.0"
              perl -0pi -e 's@/tool\.@/tmp/.@g' "$out/share/infernode/resources/dis/veltro/tools9p.dis"
              perl -0pi -e 's@/tool\.@/tmp/.@g' "$out/share/infernode/resources/dis/lucibridge.dis"

              cat > "$out/bin/infernode" <<EOF
              #!${pkgs.runtimeShell}
              set -eu
              cd "$out/share/infernode"

              base_home="\''${HOME:-\''${TMPDIR:-/tmp}}"
              infernode_home="\''${XDG_STATE_HOME:-\$base_home/.local/state}/infernode-host"
              if ! mkdir -p "\$infernode_home" 2>/dev/null; then
                infernode_home="\''${TMPDIR:-/tmp}/infernode-host"
                mkdir -p "\$infernode_home"
              fi
              export HOME="\$infernode_home"

              if [ -n "\''${WAYLAND_DISPLAY:-}" ] && [ -n "\''${XDG_RUNTIME_DIR:-}" ]; then
                export SDL_VIDEODRIVER=wayland
                export SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1
              elif [ -n "\''${DISPLAY:-}" ]; then
                export SDL_VIDEODRIVER=x11
                export SDL_VIDEO_X11_SCALING_FACTOR=1
              fi

              export LD_LIBRARY_PATH="$out/share/infernode/bin\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
              exec ./infernode "\$@"
              EOF

              chmod +x "$out/bin/infernode"

              runHook postInstall
            '';

            meta = {
              description = "Infernode GUI release repackaged for Nix";
              homepage = "https://github.com/infernode-os/infernode";
              license = pkgs.lib.licenses.mit;
              mainProgram = "infernode";
              platforms = [ "x86_64-linux" ];
            };
          });
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/infernode";
        };
      });
    };
}
