# 🎶 EKAudioPlayer 🎶

A framework for easily playing music from the iTunes library. A replacement for MPMusicPlayerController.  
This abstracts all the obtuse playback and playlist management logic so you can focus on playing tunes 🎶.

All you have to do to implement this in your own app is to set your `ViewController` as the player's delegate,
and then link up your buttons to the `EKAudioPlayer` interface.  

The `EKAudioPlayer` is a singleton object that can be instantiated on a root view controller  or `AppDelegate` to play music throughout all screens of your app, no matter the view hierarchy.

### Objects: 
* EKAudioPlayer: Controls music playback and scrubbing. Also maintains a playlist of songs.
* EKPlaylist: Maintains a playlist of songs as a collection type item.

### Pleasantries:
* Updates the "Now Playing Center" (aka. lock screen) with your music info, and receives playback control input from both the lock screen and external things like the headphone buttons or a speaker dock.
* Audio level metering
* Interpreting whether to skip to a previous song or return to the beginning when pressing "Skip back".
* Provides important playback event notifications, such as `trackDidChange`, `endOfQueueReached`, and `playbackStateChanged`. These allow easy interface updates to take place.
* You can instantiate the player with the results from `MPMediaQueries`, so accessing the iPod library is super easy.
* The `nowPlayingItem` exposes a `MPMediaItem`, so it comes with all the info needed to populate a nice interface (artwork, artist, etc).

### Why:
When I needed to integrate iPod-like music playing into my app, I found MPMusicPlayerController too 
limited for my needs. Audio level metering is completely absent from MPMusicPlayerController and requires moving down
to AVFoundation. Due to this snafu, I created this.

### Contact
Email me at koehleree@gmail.com or file an issue if you need help or find bugs.
