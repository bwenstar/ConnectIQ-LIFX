# ConnectIQ-LIFX
 ConnectIQ app to control LIFX smart lights

Forked from [cfculhane/ConnectIQ-LIFX](https://github.com/cfculhane/ConnectIQ-LIFX), whose version is
available from [the ConnectIQ store here](https://apps.garmin.com/en-US/apps/a50ca7b7-47bb-44bc-9683-0df70e40a27c).

This fork adds:
- Forerunner 265 / 265S support, and fixes for building with Connect IQ SDK 9.x
- **Toggle a light** now picks a room first (the LIFX group), then a light in it or the whole room
- Light filters, so you can hide lights you don't want on your watch (e.g. someone else's room)

## Using the app

The main menu has:
- **Toggle a light**: pick a room, then **Whole room** or a single light
- **Toggle all lights**: toggles every light the app shows (hidden lights are left alone)
- **Apply a Scene**: activates one of your LIFX scenes

## Settings

| Setting | What it does |
|---|---|
| `LIFX_API_KEY` | Your LIFX token, from <https://cloud.lifx.com/settings> |
| `HIDE_LIGHTS` | Lights to hide |
| `SHOW_LIGHTS` | If set, only these lights are shown; empty shows everything. `HIDE_LIGHTS` still wins |

`HIDE_LIGHTS` and `SHOW_LIGHTS` are comma separated. Each entry can be a location
name (`Guest House`), a group name (`Kitchen`), `Location/Group` (`Upstairs/Bedroom`), or a
light's name. Case doesn't matter. When two rooms share a group name, the menu adds the
location, e.g. `Bedroom (Upstairs)`.

For an app installed from the store, these are set in the Garmin Connect phone app.
A sideloaded app can't get settings that way, so build them into a personal copy instead
(below).

## Building

You need:
- Java 17+
- The [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/). Use it to
  install an SDK and the device files for your watch (this needs a Garmin login)
- A developer key:
  ```
  openssl genrsa -out developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
  ```

Plain build (no settings built in):
```
monkeyc -d fr265 -f monkey.jungle -o bin/ConnectIQ-LIFX.prg -y path/to/developer_key.der
```

### Personal build for sideloading (Linux)

`scripts/build-watch.sh` builds a copy with your token and filters built in and can copy
it onto the watch over USB. It reads two files from `~/.config/lifx/`:

- `token`: your LIFX token, on one line
- `watch-settings`:
  ```
  HIDE_LIGHTS="Guest House"
  SHOW_LIGHTS=""
  DEVICE="fr265"
  ```

It expects the developer key at `~/.Garmin/keys/developer_key.der` (or set
`GARMIN_DEV_KEY`). It finds the SDK the SDK Manager installed, and uses Java from `PATH`
or `~/.local/opt/jdk-*`.

```
scripts/build-watch.sh --list      # show your lights as Location/Group: Name
scripts/build-watch.sh             # build bin/personal/LIFX.prg
scripts/build-watch.sh --install   # build and copy to the plugged-in watch
```

After `--install`, eject and unplug the watch to finish installing. The script also removes
the watch's saved `LIFX.SET`, because old saved settings would override the new built-in
ones. Keep `bin/personal/LIFX.prg` private, since your token is inside it (`bin/` is
git-ignored). Always sign with the same developer key, or the watch treats the build as a
different app.
