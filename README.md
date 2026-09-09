# Curacast for macOS — Homebrew tap

Native Curacast for Apple-silicon and Intel Macs. No Docker, no virtual
machine: a compiled binary that runs beside your media server, with
Homebrew's ffmpeg (hardware encoding included) and a `brew services` job
that survives reboots.

```sh
brew tap curacast/curacast
brew install curacast
brew services start curacast
```

Then open <http://localhost:8000>.

## Updating

```sh
brew upgrade curacast
brew services restart curacast
```

Your channels, settings and licence are in `$(brew --prefix)/var/curacast`
and are kept across upgrades. Back that folder up.

## What this installs

- `$(brew --prefix)/opt/curacast/libexec/` — the compiled Curacast binary,
  the SQLite driver it uses, and the web frontend. There is no source code
  in it; Curacast is proprietary software (<https://curacast.tv/terms>).
- `$(brew --prefix)/bin/curacast` — a small wrapper that points Curacast at
  Homebrew's ffmpeg.
- A `brew services` definition running Curacast on port 8000 with its data in
  `$(brew --prefix)/var/curacast` and its logs in `$(brew --prefix)/var/log/curacast/`
  (`curacast.log` is the application log, `service.log` anything launchd caught).

Change the port or data directory by editing the service with
`brew services edit curacast`, or run it yourself:

```sh
curacast --port 8001 --database ~/curacast-data
```

## Plex on the same Mac

Add the tuner at `http://localhost:8000`. If protected streaming is on (the
default), use the tuner URL shown in Curacast's Settings — it carries the key.

## Trademark

Curacast™ is a trademark of Inertia Tech Group LLC. This tap contains the
formula only; the application is licensed under its own terms.
