# Musir

**A simple, fast music player for the songs already on your Android phone.**
No accounts, no ads, no tracking, and no internet needed. Your music stays on your device.

## Download

### 👉 [Download the latest version of Musir](https://github.com/ahsanulhoqueabir/Musir/releases/tag/v1.0.1)

Open the link, scroll to **Assets**, and tap the APK file for your phone
(see [Which file should I pick?](#which-file-should-i-pick)).

| Home | Library | Now Playing | Playlist |
|------|---------|-------------|----------|
| ![Home](docs/screenshots/light-home.png) | ![Library](docs/screenshots/light-library.png) | ![Player](docs/screenshots/light-player.png) | ![Playlist](docs/screenshots/light-playlist.png) |
| ![Home dark](docs/screenshots/dark-home.png) | ![Library dark](docs/screenshots/dark-library.png) | ![Player dark](docs/screenshots/dark-player.png) | ![Playlist dark](docs/screenshots/dark-playlist.png) |

*Illustrative screenshots with placeholder artwork.*

## What Musir does

Musir finds the music files on your phone and gives you a clean place to browse,
search and play them. It keeps playing with the screen off and remembers where you left off.

## Features

- **Your whole library, automatically.** Musir scans your phone for songs and shows
  their title, artist, album and cover art. Rescans are quick because only new or changed files are read.
- **Browse your way.** Look through Songs, Albums, Artists and Favorites, or jump to
  Recently played and Recently added on the home screen. Songs can be sorted.
- **Search.** Find songs, albums and artists by typing part of a name.
- **Now Playing.** Large cover art, a seek bar, previous/play/next, shuffle,
  repeat (off, all or one), and 10-second skip back and forward.
- **Queue.** See what plays next. Tap a song to jump to it, drag to reorder,
  swipe to remove. Use "Play next" or "Add to queue" on any song.
- **Playlists.** Create, rename and delete playlists (with Undo), add songs,
  reorder them and play the whole list.
- **Favorites and history.** Tap the heart on any song to save it to Favorites.
- **Plays in the background.** Control music from the notification, the lock screen,
  or your headset and Bluetooth buttons. Playback pauses for calls and other audio apps.
- **Light and dark themes**, and it respects your phone's text size.

## How to use Musir

### First launch
1. Open Musir and tap **Allow** when it asks for access to your music and audio.
2. Wait a moment while it scans. Your songs then appear in the Library.

### Play music
1. Open the **Library** and pick the **Songs**, **Albums** or **Artists** tab.
2. Tap a song to start playing. A mini-player appears at the bottom; tap it to open the full player.

### Search
Tap the search bar on the home screen and type a title, artist or album.

### Use the queue
In the player, open the queue to tap a song to jump to it, drag to reorder, or swipe to remove.
To line up a song, use its menu and choose **Play next** or **Add to queue**.

### Make a playlist
1. Open **Playlists** and create a new one.
2. Add songs from their menus.
3. Open the playlist to reorder songs or play it. If you delete one by mistake, tap **Undo**.

### Favorites
Tap the heart in the player (or a song's menu). Find them all in the **Favorites** tab.

### Settings
Open **Settings** to:
- choose a Light, Dark or System theme
- set the default song sort order
- rescan your library after adding new music
- resume your last queue when you reopen the app
- skip silent parts of tracks
- read the privacy notice and see the app version

## Install on Android

Musir needs **Android 7.0 or newer**.

### Which file should I pick?
On the [release page](https://github.com/ahsanulhoqueabir/Musir/releases/tag/v1.0.1), choose one:

| File | Choose it if |
|---|---|
| `app-arm64-v8a-release.apk` | You have a modern phone or tablet. **Recommended for most people.** |
| `app-release.apk` | You're not sure. It works on every supported device but is a larger download. |
| `app-armeabi-v7a-release.apk` | You have an older or budget 32-bit phone. |
| `app-x86_64-release.apk` | You're using an emulator or certain Chromebooks. |

### Steps
1. On your phone, open the release page and tap your APK file to download it.
2. Open the downloaded file (from your browser's downloads or a file manager).
3. If Android says it can't install apps from this source, tap **Settings** and turn on
   **Allow from this source** for your browser or file manager, then go back and tap **Install**.
   This is normal for apps installed outside the Play Store.
4. Tap **Open** when it finishes, or find **Musir** in your app list.

### Permissions
- **Music and audio**: so Musir can find the songs on your phone.
- **Keep playing with the screen off**: so music doesn't stop when you lock your phone.

Musir doesn't ask for internet access.

## Privacy

Everything stays on your device. Musir has no accounts, ads or analytics.

## Troubleshooting

- **No music showing?** Make sure you allowed access to music and audio, then use
  **Library → Rescan**. Folders containing a `.nomedia` file, hidden folders, and
  Ringtones/Notifications/Alarms are skipped on purpose.
- **Permission screen keeps appearing?** If you tapped "Don't allow" twice, Android stops asking.
  Tap **Open settings** and enable **Music and audio** for Musir.
- **Music stops in the background?** Turn off battery optimization for Musir in your phone's settings.
  Some phone makers stop background apps aggressively.
- **No notification controls?** Check Musir's notification settings in your phone's settings.
- **A song won't play?** Playback depends on your phone's supported formats. Musir looks for
  MP3, M4A, AAC, FLAC, WAV, OGG, Opus, WMA and more.
