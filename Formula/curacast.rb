# typed: false
# frozen_string_literal: true

# Curacast for macOS, installed from a compiled build. See the tap README.
#
# The bottles are the install path: Homebrew unpacks them and needs no Xcode
# Command Line Tools. The url/sha256 pair is the same content as a plain
# tarball, used only by `brew install --build-from-source`. Both come from
# scripts/build-macos.sh in the Curacast repo, one run per architecture, and
# are attached to this tap's GitHub release for the version.
class Curacast < Formula
  desc "Your media library as live TV: 24/7 channels for Plex, Jellyfin and Emby"
  homepage "https://curacast.tv"
  version "2.3.0"
  license :cannot_represent

  if Hardware::CPU.arm?
    url "https://github.com/curacast/homebrew-curacast/releases/download/v2.3.0/curacast-2.3.0-darwin-arm64.tar.gz"
    sha256 "1da95bf428acf16ddb855c47e7a062b6368717a8165d5428e8b90e63c7b0fe51"
  else
    url "https://github.com/curacast/homebrew-curacast/releases/download/v2.3.0/curacast-2.3.0-darwin-x64.tar.gz"
    sha256 "55a21c29928bf9d5177daef1e867fa0da33d4ecba7cb82529c1fb023c47aafd9"
  end

  bottle do
    root_url "https://github.com/curacast/homebrew-curacast/releases/download/v2.3.0"
    sha256 cellar: :any_skip_relocation, arm64_big_sur: "f3e6912bd8831663b8fffe1f0a01fb037a6536d1cab03c5d28040d87f3ffdd7e"
    sha256 cellar: :any_skip_relocation, big_sur:       "1628c7881487b2f0486c0bde0e3cf78cb036154c028ab4b784e0db414114fcff"
  end

  depends_on "ffmpeg"
  depends_on :macos

  def install
    # The tarball is one directory: the compiled binary, the SQLite addon it
    # loads from beside itself, and the frontend, resources, locales and API
    # description it serves. All of it lives in libexec, untouched.
    libexec.install Dir["*"]

    # The command people run, and the one the service runs: production
    # logging (the build ships no dev pretty-printer) into var/log, and the
    # ffmpeg this formula depends on, so a fresh install finds an encoder
    # without a trip to Settings. Hardware encoding (VideoToolbox) is
    # Homebrew ffmpeg's own. The bottle ships this same wrapper.
    (bin/"curacast").write_env_script libexec/"curacast",
      NODE_ENV:             "production",
      LOG_DIR:              var/"log/curacast",
      CURACAST_FFMPEG_PATH: formula_opt_bin("ffmpeg")/"ffmpeg"
  end

  service do
    run [opt_bin/"curacast", "--database", var/"curacast", "--port", "8000"]
    keep_alive true
    working_dir var/"curacast"
    log_path var/"log/curacast/service.log"
    error_log_path var/"log/curacast/service.log"
  end

  def caveats
    <<~EOS
      Start Curacast as a background service (it survives reboots):
        brew services start curacast

      Then open http://localhost:8000 and follow the setup.

      Your channels, settings and licence live in:
        #{var}/curacast
      Back that folder up. Updates keep it:
        brew upgrade curacast && brew services restart curacast

      Logs: #{var}/log/curacast/

      Plex on the same Mac: add the tuner at http://localhost:8000 (protected
      streaming puts the key in the URL shown in Settings).
    EOS
  end

  test do
    # Boot the real binary on a throwaway data directory and read /health.
    # A 503 "degraded" is fine here (no media server yet); the database
    # opening is what proves the addon beside the binary loaded.
    port = free_port
    pid = fork do
      exec bin/"curacast", "--database", testpath/"data", "--port", port.to_s
    end
    begin
      body = ""
      45.times do
        sleep 1
        body = Utils.safe_popen_read("curl", "-s", "-m", "2", "http://127.0.0.1:#{port}/health")
        break if body.include?("\"database\"")
      rescue ErrorDuringExecution
        next
      end
      assert_match "\"database\":\"ok\"", body
      assert_match "\"version\":\"#{version}\"", body
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
