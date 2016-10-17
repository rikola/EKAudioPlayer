//
//  EKAudioPlayer.swift
//  EKAudioPlayer
//
//  Created by Eric Koehler  on 2/25/16.
//  Copyright © 2015 Eric Koehler. All rights reserved.
//

import MediaPlayer
import AVFoundation


// MARK: Array shuffling functions

extension CollectionType {
	
	// Returns 'self' with its contents shuffled
	func shuffled() -> [Generator.Element] {
		var list = Array(self)
		list.shuffleInPlace()
		return list
	}
}


extension MutableCollectionType where Index == Int {
	
	// Shuffle elements of 'self' in place
	mutating func shuffleInPlace() {
		if count < 2 { return }       // Empty and single element collections can't shuffle
		
		for a in 0..<(count - 1) {
			let b = Int(arc4random_uniform(UInt32(count - a))) + a
			guard a != b else { continue }
			swap(&self[a], &self[b])
		}
	}
}


public protocol EKAudioPlayerDelegate {
	func musicPlayer(musicPlayer: EKAudioPlayer, trackDidChange nowPlaying: MPMediaItem?)
	func musicPlayer(musicPlayer: EKAudioPlayer, endOfQueueReached lastTrack: MPMediaItem?)
	func musicPlayer(musicPlayer: EKAudioPlayer, playbackStateChanged isPlaying: Bool)
}


// MARK: ---------- Music Controller Class ----------

/**
Master music player singleton.  

Features:  
* Playback control  
* Playlist management  
* Delegate notifications  
* Metering
*/
public class EKAudioPlayer: NSObject {
	
	/// Singleton reference.
	public static let sharedInstance = EKAudioPlayer()
	
	/// Delegates to recieve playback notifications.
	var delegates: [EKAudioPlayerDelegate] = []
	
	/// Playlist of songs.
	var playlist: EKPlaylist<MPMediaItem>?
	
	/// Underlying audio player object. Actually plays the song.
	private var player: AVAudioPlayer?
	
	/// If the player is currently playing.
	var isPlaying: Bool {
		guard let thePlayer = player
			else { return false }
		return thePlayer.playing
	}
	
	/// The current song duration.
	var duration: NSTimeInterval {
		return player != nil ? Double(player!.duration) : 0.0
	}
	
	/// The current song being played.
	var nowPlaying: MPMediaItem? {
		return playlist?.nowPlaying
	}
	
	/// Location of the playhead in the current song.
	var currentPlaybackTime: NSTimeInterval {
		get { return player != nil ? Double(player!.currentTime) : 0.0 }
		set { seekTo(newValue) }
	}
	
	/// Player will skip to the previous song only if playback time is less than 3 seconds.
	private var shouldReturnToBeginningWhenSkippingToPreviousItem: Bool {
		return currentPlaybackTime >= 3 ? true : false
	}
	
	/**
	The audio output power level. It is the average of all audio channels. The value will
	generally be between 0 (silent) and 160 (full).
	*/
	public var power: Float {
		guard let thePlayer = player
			else { return 0.0 }
		thePlayer.updateMeters()
		
		// Find average channel power		
		var averagePower: Float = 0.0
		let channelCount = thePlayer.numberOfChannels
		for i in 0 ..< channelCount {
			averagePower += thePlayer.averagePowerForChannel(i)
		}
		averagePower = averagePower / Float(channelCount)
		
		// Add 160, since values begin at -160 and go up to 0 by default
		averagePower += 160
		return averagePower
	}
	
	/**
	Default initializer. Configures the audio session and begins generating player notifications.
	*/
	public override init() {
		super.init()
		delegates = []
		configureAudioSession()
		let systemPlayer = MPMusicPlayerController.systemMusicPlayer()
		systemPlayer.beginGeneratingPlaybackNotifications()
	}
	
	/**
	Deinitializer. Cuts off playback notification generation.
	*/
	deinit {
		let systemPlayer = MPMusicPlayerController.systemMusicPlayer()
		systemPlayer.endGeneratingPlaybackNotifications()
	}
	
	// MARK: Delegate Management
	
	/**
	Registers a delegate to recieve playback notifications  
	
	- parameter delegate:
	*/
	public func addDelegate(delegate: EKAudioPlayerDelegate) {
		delegates.append(delegate)
	}
	
	public func removeDelegate(delegate: EKAudioPlayerDelegate) {
		delegates = delegates.filter() { $0 as? AnyObject !== delegate as? AnyObject } // Filter only objects that are not equal
	}
	
	// MARK: Playback Management
	
	public func play() {
		guard let thePlayer = player
			else { return }
		
		thePlayer.play()
		
		for delegate in delegates {
			delegate.musicPlayer(self, playbackStateChanged: thePlayer.playing)
		}
	}
	
	public func pause() {
		guard let thePlayer = player
			else { return }
		
		thePlayer.pause()
		
		for delegate in delegates {
			delegate.musicPlayer(self, playbackStateChanged: thePlayer.playing)
		}
	}
	
	public func seekTo(time: NSTimeInterval) {
		guard let thePlayer = player
			else { return }
		thePlayer.currentTime = time
	}
	
	// MARK: Playlist Management
	
	/// Loads the current track into a player object and initializes player delegate and metering settings.
	private func loadSong() {
		player?.stop()
		do {
			player = try AVAudioPlayer(contentsOfURL: nowPlaying!.valueForProperty(MPMediaItemPropertyAssetURL) as! NSURL)
			player?.meteringEnabled = true
		} catch let error as NSError {
			print(error.localizedDescription)
		}
		
		updateNowPlayingCenter()
		
		for delegate in delegates {
			delegate.musicPlayer(self, trackDidChange: nowPlaying)
		}
	}
	
	/// Load collection of songs into playlist and begin playing them.
	///
	/// - Parameter songs: Collection of tracks to load in the playlist.
	/// - Parameter index: index in current collection to begin playback from
	public func loadSongsAndBeginPlayback(songs: MPMediaItemCollection, index: Int = 0) {
		playlist = EKPlaylist<MPMediaItem>(songs: songs.items)
		playlist!.index = index
		loadSong()
		play()
	}
	
	/// Skip to the next track in the playlist
	public func skipToNextItem() {
		guard let thePlayer = player
			else { return }
		guard let thePlaylist = playlist
			else { return }
		
		let wasPreviouslyPlaying = thePlayer.playing
		
		thePlaylist.next()
		loadSong()
		
		if wasPreviouslyPlaying {
			play()
		}
		
		for delegate in delegates {
			delegate.musicPlayer(self, trackDidChange: nowPlaying)
		}
	}
	
	/**
	Skip to the previous track in the playlist.
	
	Will move playhead to beginning of track if:  
	- Playback is near beginning of track  
	- Song is first in the playlist
	*/
	public func skipToPreviousItem() {
		guard let thePlayer = player
			else { return }
		guard let thePlaylist = playlist
			else { return }
		
		let wasPreviouslyPlaying = thePlayer.playing
		
		if shouldReturnToBeginningWhenSkippingToPreviousItem || thePlaylist.index == 0 {
			currentPlaybackTime = 0.0
		} else {
			thePlaylist.previous()
			loadSong()
		}
		
		if wasPreviouslyPlaying {
			play()
		}
		
		for delegate in delegates {
			delegate.musicPlayer(self, trackDidChange: nowPlaying)
		}
	}
	
	/**
	Begins playing a song at the specified playlist index
	
	- parameter index: A song index to load
	*/
	public func playItemAtIndex(index: Int) {
		guard let thePlaylist = playlist
			else { return }
		thePlaylist.changeTo(index)
		play()
	}
	
	/**
	Configures the AVAudioSession for music playback
	*/
	public func configureAudioSession() {
		let audioSession = AVAudioSession.sharedInstance()
		do {
			try audioSession.setCategory(AVAudioSessionCategoryPlayback)
			try audioSession.setActive(true)
		} catch {
			print(error)
		}
	}
}


// Update MPNowPlayingInfoCenter and handle remote control events
extension EKAudioPlayer {
	
	// Updates the MPMediaInfoCenter
	// Alternative function here: http://swiftexplained.com/?p=34
	func updateNowPlayingCenter() {
		let center = MPNowPlayingInfoCenter.defaultCenter()
		if nowPlaying == nil {
			center.nowPlayingInfo = nil
		} else {
			var songInfo = [String: AnyObject]()
			
			// Add item to dictionary if it exists
			if let artist = nowPlaying?.artist {
				songInfo[MPMediaItemPropertyArtist] = artist
			}
			if let title = nowPlaying?.title {
				songInfo[MPMediaItemPropertyTitle] = title
			}
			if let albumTitle = nowPlaying?.albumTitle {
				songInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
			}
			if let playbackDuration = nowPlaying?.playbackDuration {
				songInfo[MPMediaItemPropertyPlaybackDuration] = playbackDuration
			}
			if let artwork = nowPlaying?.artwork {
				songInfo[MPMediaItemPropertyArtwork] = artwork
			}
			center.nowPlayingInfo = songInfo
		}
	}
	
	/// Handler for Remote Control Events (Lock screen controls or headphone buttons).
	public func remoteControlReceivedWithEvent(event: UIEvent) {
		guard let thePlayer = player
			else { return }
		
		if event.type == .RemoteControl {
			switch event.subtype {
			case .RemoteControlPlay:
				play()
			case .RemoteControlPause:
				pause()
			case .RemoteControlTogglePlayPause:
				if thePlayer.playing {
					pause()
				} else {
					play()
				}
			case .RemoteControlNextTrack:
				skipToNextItem()
			case .RemoteControlPreviousTrack:
				skipToPreviousItem()
			default:
				return
			}
		}
	}
}


extension EKAudioPlayer : AVAudioPlayerDelegate {
	
	/**
	Called when the audio player reaches the end of a song
	*/
	public func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
		skipToNextItem()
	}
}



