# Cask template for the moria CLI. Source of truth lives in this repo;
# the `cli-release.yml` workflow renders this file by substituting the
# placeholders below and opens a PR against `morialabs/homebrew-tap`.
#
# Don't render this file by hand — let the release workflow do it. If you
# need to change the cask body (add a uninstall stanza, etc.), edit this
# template, tag a new release, and the next bump PR carries the change.

cask "moria" do
  version "0.1.0"
  sha256  "5b9e4b0352dcb32a30343779514f2ba35150c5dde89d023976ea1e85675954e2"
  url     "https://github.com/morialabs/Platform/releases/download/cli-v0.1.0/moria-0.1.0-macos.tar.gz"

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
  end

  uninstall delete: [
    # Cask removes the bundle and the binary symlink itself. We add the
    # support directory cleanup here so a stale .command file from an old
    # TCC denial doesn't survive a reinstall.
    "#{Dir.home}/Library/Application Support/Moria/run-*.command",
  ]

  # `brew uninstall --zap` removes user data too. The log directory is
  # large enough to be worth opting into removal explicitly.
  zap trash: [
    "~/Library/Application Support/Moria",
    "~/Library/Logs/Moria",
  ]
end
