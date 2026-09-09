# typed: false
# frozen_string_literal: true

# Curacast for macOS, installed from a compiled build. See the tap README.
class Curacast < Formula
  desc "Your media library as live TV: 24/7 channels for Plex, Jellyfin and Emby with a real guide"
  homepage "https://curacast.tv"
  version "2.1.0"
  license :cannot_represent

  on_arm do
    url "https://github.com/curacast/homebrew-curacast/releases/download/v2.1.0/curacast-2.1.0-darwin-arm64.tar.gz"
    sha256 "ARM64_SHA256"
  end
  on_intel do
    url "https://github.com/curacast/homebrew-curacast/releases/download/v2.1.0/curacast-2.1.0-darwin-x64.tar.gz"
    sha256 "X64_SHA256"
  end

  depends_on :macos
  depends_on "ffmpeg"

  def install
    # The tarball is one directory: the compiled binary, the SQLite addon it
    # loads from beside itself, and the frontend, resources, locales and API
    # description it serves. All of it lives in libexec, untouched.
    libexec.install Dir["*"]

    # The command people run, and the one the service runs: production
    # logging (the build ships no dev pretty-printer), and the ffmpeg this
    # formula depends on, so a fresh install finds an encoder without a trip
    # to Settings. Hardware encoding (VideoToolbox) is Homebrew ffmpeg's own.
    (bin/"curacast").write_env_script libexec/"curacast",
      NODE_ENV:            "production",
      CURACAST_FFMPEG_PATH: Formula["ffmpeg"].opt_bin/"ffmpeg"
  end

  def post_install
    (var/"curacast").mkpath
    (var/"log").mkpath
  end

  service do
    run [opt_bin/"curacast", "--database", var/"curacast", "--port", "8000"]
    keep_alive true
    working_dir var/"curacast"
    log_path var/"log/curacast.log"
    error_log_path var/"log/curacast.log"
  end

  def caveats
    <<~EOS
      Start Curacast as a background service (it survives reboots):
        brew services start curacast

      Then open http://localhost:8000 and follow the setup.

      Your channels, settings and licence live in:
        #{var}/curacast
      Back that folder up. Updates keep it:
        brew upgrade curacast

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
      body = nil
      45.times do
        sleep 1
        body = shell_output("curl -s -m 2 http://127.0.0.1:#{port}/health", 0) rescue nil
        break if body&.include?("\"database\"")
      end
      assert_match "\"database\":\"ok\"", body.to_s
      assert_match "\"version\":\"#{version}\"", body.to_s
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
