# Cask template for the moria CLI. Source of truth lives in this repo;
# the `cli-release.yml` workflow renders this file by substituting the
# placeholders below and opens a PR against `morialabs/homebrew-tap`.
#
# Don't render this file by hand — let the release workflow do it. If you
# need to change the cask body (add a uninstall stanza, etc.), edit this
# template, tag a new release, and the next bump PR carries the change.

cask "moria" do
  version "0.2.15"
  sha256  "879faf605908124b9bd94833962b330e662d42cf2c8c3fd19c83f0ba8345b4b0"
  url     "https://github.com/morialabs/homebrew-tap/releases/download/cli-v0.2.15/moria-0.2.15-macos.tar.gz"

  name "Moria"
  desc "Local-setup CLI for the Moria platform"
  homepage "https://moria.dev"

  # Drop the bundle into /Applications. Cask handles quarantine attribution
  # automatically for downloaded artifacts, but we strip it in postflight
  # because the .app is ad-hoc signed (no Apple Developer ID for v1).
  app "Moria.app"

  # Symlink the main CLI binary into the user's PATH so they can run
  # `moria doctor` etc. directly from a terminal. Path resolves to either
  # /usr/local/bin (Intel) or /opt/homebrew/bin (Apple Silicon) depending
  # on Homebrew's prefix on the host.
  binary "#{appdir}/Moria.app/Contents/MacOS/moria", target: "moria"

  postflight do
    # 1) Strip com.apple.quarantine. Without this Gatekeeper blocks the
    #    first launch (because the .app isn't notarized), the URL handler
    #    never registers, and clicking "Set up Project Locally" in the
    #    browser does nothing. The xattr removal converts our ad-hoc-signed
    #    bundle into something macOS will run without a prompt.
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Moria.app"]
    # 2) Force LaunchServices to re-scan the bundle so the moria:// URL
    #    handler is wired up immediately, rather than at the next OS poll.
    #    `lsregister -f` is documented (-private framework, but stable for
    #    decades) and is what every Mac installer that ships a URL handler
    #    uses post-install.
    system_command "/System/Library/Frameworks/CoreServices.framework/" \
                   "Frameworks/LaunchServices.framework/Support/lsregister",
                   args: ["-f", "#{appdir}/Moria.app"]
    # 3) Install the Moria Bridge LaunchAgent so the local daemon runs at
    #    login. Safe to install even though the bridge UI ships disabled
    #    (BRIDGE_UI_ENABLED=false): the daemon only serves authenticated
    #    loopback requests, no browser connects until the flag flips, and the
    #    backend kill-switch can disable the whole fleet instantly. Best-effort
    #    (must_succeed: false) — a launchctl hiccup must not fail the install.
    system_command "#{appdir}/Moria.app/Contents/MacOS/moria",
                   args: ["daemon", "install"],
                   must_succeed: false
  end

  # Boot out the LaunchAgent and remove its plist on uninstall so we don't
  # leave a dangling background job pointing at a deleted binary.
  uninstall launchctl: "com.moria.bridge",
            delete:    [
              "#{Dir.home}/Library/LaunchAgents/com.moria.bridge.plist",
              # Stale .command file from an old TCC denial — clean it so it
              # doesn't survive a reinstall.
              "#{Dir.home}/Library/Application Support/Moria/run-*.command",
            ]

  # `brew uninstall --zap` removes user data too. The log directory is
  # large enough to be worth opting into removal explicitly.
  zap trash: [
    "~/Library/Application Support/Moria",
    "~/Library/Logs/Moria",
    "~/Library/LaunchAgents/com.moria.bridge.plist",
  ]
end
