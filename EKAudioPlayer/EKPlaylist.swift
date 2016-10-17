//
//  EKPlaylist.swift
//  EKAudioPlayer
//
//  Created by Eric Koehler  on 2/18/16.
//  Copyright © 2016 Eric Koehler. All rights reserved.
//

import AVFoundation
import MediaPlayer


class EKPlaylist<T> {
	
	private var contents: [T]
	var count: Int { return contents.count }
	var startIndex: Int { return 0 }
	var endIndex: Int { return contents.count }
	var index: Int = 0
	var nowPlaying: T? {
		return index < count ? contents[index] : nil
	}
	
	init(songs: [T], withIndex: Int = 0) {
		contents = songs
		index = withIndex
	}
	
	func insert(song: T, atIndex: Int) {
		contents.insert(song, atIndex: atIndex)
	}
	
	func remove(index: Int) -> T? {
		if index < endIndex {
			return contents.removeAtIndex(index)
		}
		return nil
	}
	
	func append(song: T) {
		contents.append(song)
	}
	
	func changeTo(index: Int) -> T? {
		assert(index >= 0, "ERROR: Cannot change to index below 0")
		if index < endIndex {
			self.index = index
			return contents[self.index]
		} else {
			self.index = endIndex
			return nil
		}
	}
	
	func next() -> T? {
		if index == endIndex || index + 1 == endIndex {
			return nil
		}
		index += 1
		return contents[index]
	}
	
	func previous() -> T? {
		if index > startIndex {
			index -= 1
		}
		return contents[index]
	}
	
	subscript(i: Int) -> T {
		return contents[i]
	}
}


