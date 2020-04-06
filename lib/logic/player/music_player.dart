/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/

export 'fetcher.dart';
export 'native_player.dart';
export 'playlist.dart';
export 'serialization.dart';
export 'song.dart';
export 'content.dart';

import 'dart:async';
import 'package:flutter/material.dart';

import 'playlist.dart';
import 'package:flutter/services.dart';

import 'package:sweyer/sweyer.dart';
import 'package:sweyer/constants.dart' as Constants;
import 'package:sweyer/api.dart' as API;

abstract class MusicPlayer {
  // Native player subscriptions
  static StreamSubscription<AudioPlayerState> _stateChangeSubscription;
  static StreamSubscription<void> _completionSubscription;
  static StreamSubscription<PlatformException> _errorSubscription;

  // Getters

  /// Get stream of changes on audio position.
  static Stream<Duration> get onAudioPositionChanged =>
      NativeAudioPlayer.onAudioPositionChanged;

  /// Get stream of changes on player state.
  static Stream<AudioPlayerState> get onPlayerStateChanged =>
      NativeAudioPlayer.onPlayerStateChanged;

  /// Get stream of changes on audio duration
  // static Stream<Duration> get onDurationChanged =>
  //     NativeAudioPlayer.onDurationChanged;

  /// Get stream of player completions
  static Stream<void> get onPlayerCompletion =>
      NativeAudioPlayer.onPlayerCompletion;

  /// Get stream of player errors
  static Stream<PlatformException> get onPlayerError =>
      NativeAudioPlayer.onPlayerError;

  /// Get stream of loop mode changes
  static Stream<bool> get onLoopSwitch => NativeAudioPlayer.onLoopSwitch;

  static AudioPlayerState get playerState => NativeAudioPlayer.state;

  static bool get loopMode => NativeAudioPlayer.loopMode;

  /// Get current position
  static Future<Duration> get currentPosition async {
    try {
      return Duration(
          milliseconds: await NativeAudioPlayer.getCurrentPosition());
    } catch (e) {
      return Duration(seconds: 0);
    }
  }

  /// Get duration of current song
  static Future<Duration> get currentDuration async {
    try {
      return Duration(milliseconds: await NativeAudioPlayer.getDuration());
    } catch (e) {
      return Duration(seconds: 0);
    }
  }

  /// Init whole music instance
  ///
  static Future<void> init() async {
    NativeAudioPlayer.init();

    _errorSubscription = NativeAudioPlayer.onPlayerError.listen((event) {
      // debugger();
    });

    _completionSubscription = onPlayerCompletion.listen((event) {
      // Play next track if not in loop mode, as in loop mode this event is not triggered
      playNext();
    });

    //******** RESTORE BY PREFS ***************

    var prefs = await Prefs.getSharedInstance();

    int savedSongPos;
    // Disable restoring position if native player is actually playing right now
    if (!(await NativeAudioPlayer.isPlaying()))
      savedSongPos = await Prefs.songPositionInt.getPref(prefs);

    // Seek to saved position
    if (savedSongPos != null)
      await MusicPlayer.seek(Duration(seconds: savedSongPos));
  }

  // TODO: improve and add usage to this method
  static void dispose() {
    _stateChangeSubscription.cancel();
    // _songChangeSubscription.cancel();
    _errorSubscription.cancel();
    _completionSubscription.cancel();
  }

  static Future<void> switchLoopMode() async {
    return NativeAudioPlayer.switchLoopMode();
  }

  /// Play track
  ///
  /// @param [songId] argument denotes an id track to play
  ///
  /// @param [silent] - if it is true, won't play track, but just switch to it
  /// (the difference with the [setUri] with this parameter is that this function will also update current playing song respectively)
  static Future<void> play(
    int songId, {
    bool silent = false,
  }) async {
    final song = ContentControl.state
        .getPlaylist(PlaylistType.global)
        .getSongById(songId);
    try {
      if (!silent) // [stayAwake] is very important for player to stay play even in background
        await NativeAudioPlayer.play(song, stayAwake: true);
      else {
        await API.ServiceHandler.sendSong(song);
        await setUri(song.id);
      }
    } on PlatformException catch (e) {
      if (e.code == "error") {
        if (e.message == Constants.Errors.UNABLE_ACCESS_RESOURCE) {
          ShowFunctions.showToast(
            msg: 'Произошла ошибка при воспроизведении,\n удаление трека',
          );
          // NOTE THAT ORDER OF THESE INSTRUCTION MATTERS
          // Play next track after broken one
          await play(ContentControl.state.currentPlaylist.getNextSongId(songId),
              silent: silent);
          ContentControl.state.getPlaylist(PlaylistType.global).removeSongAt(
            ContentControl.state.getPlaylist(PlaylistType.global)
                .getSongIndexById(songId),
          ); //Remove broken track
          ContentControl.state.emitPlaylistChange();
          ContentControl.refetchSongs(); // perform fetching
        } else if (e.message == Constants.Errors.NATIVE_PLAYER_ILLEGAL_STATE) {
          // ...
        }
      }
    } catch (e) {
      // Do not handle this, because other exceptions are not expected
      rethrow;
    } 
  }

  /// Resume player
  static Future<void> resume([int songId]) async {
    // If [songId] hasn't been provided then use playing id state
    if (songId == null) songId = ContentControl.state.currentSongId;
    try {
      return NativeAudioPlayer.resume();
    } catch (e) {
      rethrow;
    }
  }

  /// Sets track url
  /// TODO: remove this method at all, or remove play [silent] parameter
  /// Unlike [play], the playback will not resume, but song will be switched if it player is playing
  static Future<void> setUri(int songId) async {
    try {
      return NativeAudioPlayer.setUri(songId);
    } catch (e) {
      rethrow;
    }
  }

  /// Pause player
  static Future<void> pause() async {
    return NativeAudioPlayer.pause();
  }

  /// Stop player
  static Future<void> stop() async {
    return NativeAudioPlayer.stop();
  }

  /// Seek
  static Future<void> seek(Duration timing) async {
    return NativeAudioPlayer.seek(timing);
  }

  /// Seek 3 seconds forward
  ///
  /// @param (optional) interval makes it possible to seek for specified interval
  static Future<void> fastForward([Duration interval]) async {
    if (interval == null) interval = Duration(seconds: 3);
    return NativeAudioPlayer.seek(((await currentPosition) + interval));
  }

  /// Seek 3 seconds backwards
  ///
  /// @param (optional) interval makes it possible to seek for specified interval
  static Future<void> rewind([Duration interval]) async {
    if (interval == null) interval = Duration(seconds: 3);
    return NativeAudioPlayer.seek(((await currentPosition) - interval));
  }

  /// Function that fires when pause/play button got clicked
  static Future<void> playPause() async {
    switch (playerState) {
      case AudioPlayerState.PLAYING:
        await pause();
        break;
      case AudioPlayerState.PAUSED:
        await resume();
        break;
      case AudioPlayerState.STOPPED:
        // Currently unused and shouldn't
        await play(ContentControl.state.currentSongId);
        break;
      case AudioPlayerState.COMPLETED:
        await play(ContentControl.state.currentSongId);
        break;
      default: // Can be null, so don't throw
        break;
    }
  }

  /// Function that fires when next track button got clicked
  ///
  /// If provided [songId] - plays next from this id
  static Future<void> playNext({int songId, bool silent = false}) async {
    songId ??= ContentControl.state.currentPlaylist
        .getNextSongId(ContentControl.state.currentSongId);
    ContentControl.state.changeSong(songId);
    play(songId, silent: silent);
  }

  /// Function that fires when prev track button got clicked
  ///
  /// If provided [songId] - plays prev from this id
  static Future<void> playPrev({int songId, bool silent = false}) async {
    songId ??= ContentControl.state.currentPlaylist.getPrevSongId(ContentControl.state.currentSongId);
    ContentControl.state.changeSong(songId);
    play(songId, silent: silent);
  }

  /// Function that handles click on track tile
  ///
  /// [clickedSongId] argument denotes an id of clicked track [MainRouteTrackList]
  static Future<void> handleClickSongTile(
      BuildContext context, Song clickedSong,
      {bool pushToPlayerRoute = false}) async {
    int prevCurrentSongId = ContentControl.state.currentSongId;

    ContentControl.state.changeSong(clickedSong.id);

    // print(
    //     "$prevCurrentSongId   ${clickedSong.id}    ${MusicPlayer.playerState}");

    switch (playerState) {
      case AudioPlayerState.PLAYING:
        {
          // If user clicked the same track
          if (prevCurrentSongId == clickedSong.id)
            await pause();

          // If user decided to click a new track
          else
            await play(clickedSong.id);
          break;
        }
      case AudioPlayerState.PAUSED:
        {
          // If user clicked the same track
          if (prevCurrentSongId == clickedSong.id)
            await resume(clickedSong.id);

          // If user decided to click a new track
          else
            await play(clickedSong.id);
          break;
        }
      case AudioPlayerState.STOPPED:
        // Currently unused and shouldn't
        await play(clickedSong.id);
        break;
      case AudioPlayerState.COMPLETED:
        await play(clickedSong.id);
        break;
      default: // Can be null, so don't throw, just play
        await play(clickedSong.id);
        break;
    }

    if (pushToPlayerRoute &&
        (clickedSong.id != prevCurrentSongId ||
            clickedSong.id == prevCurrentSongId &&
                MusicPlayer.playerState == AudioPlayerState.PLAYING)) {
      Navigator.of(context).pushNamed(Constants.Routes.player.value);
    }
  }
}

/// Function that returns artist, or automatically show "Неизвестный исполнитель" instead of "<unknown>"
String artistString(String artist) =>
    artist != '<unknown>' ? artist : 'Неизвестный исполнитель';
