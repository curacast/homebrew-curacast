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
  version "2.11.3"
  license :cannot_represent

  if Hardware::CPU.arm?
    url "https://github.com/curacast/homebrew-curacast/releases/download/v2.11.3/curacast-2.11.3-darwin-arm64.tar.gz"
    sha256 "b166cfb508275b1125042ac10b44b020444070068f5ca0267f4db89b3b47f1a2"
  else
    url "https://github.com/curacast/homebrew-curacast/releases/download/v2.11.3/curacast-2.11.3-darwin-x64.tar.gz"
    sha256 "da6d199cbcdf6bd9c24387c16f8db55bc14c6ca7842dac95ebfdd3c943c82f2a"
  end

  bottle do
    root_url "https://github.com/curacast/homebrew-curacast/releases/download/v2.11.3"
    sha256 cellar: :any_skip_relocation, arm64_big_sur: "0587d79553bf3f1e425a66d2dc8c8e90d301c5101d30583d52e7b38c44bc9e5c"
    sha256 cellar: :any_skip_relocation, big_sur:       "bfb3f284b47235c36777fcc5e87b27c1e92e9f01ff9f0a85e0c9e5e4206ed346"
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
