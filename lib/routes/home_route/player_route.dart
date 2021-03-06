/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import 'dart:async';
import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/physics.dart';
import 'package:nt4f04unds_widgets/nt4f04unds_widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sweyer/sweyer.dart';
import 'package:sweyer/constants.dart' as Constants;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final SpringDescription playerRouteSpringDescription =
    SpringDescription.withDampingRatio(
  mass: 0.01,
  stiffness: 30.0,
  ratio: 2.0,
);

class PlayerRoute extends StatefulWidget {
  const PlayerRoute();

  @override
  _PlayerRouteState createState() => _PlayerRouteState();
}

class _PlayerRouteState extends State<PlayerRoute> {
  final GlobalKey<_QueueTabState> _queueTabKey = GlobalKey<_QueueTabState>();
  List<Widget> _tabs;

  /// Active tab index.
  int index = 0;
  int prevIndex = 0;

  /// Whether can transition on swipe.
  bool canTransition = true;
  double dragDelta = 0.0;

  void _changeTab(int _index) {
    prevIndex = index;
    index = _index;
    if (index == 0) {
      _queueTabKey.currentState.opened = false;
    } else if (index == 1) {
      _queueTabKey.currentState.opened = true;
    }
    setState(() {/* update ui to show new tab */});
  }

  SlidableController controller;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _MainTab(),
      _QueueTab(
        key: _queueTabKey,
      ),
    ];
    controller = getPlayerRouteControllerProvider(context).controller;
    controller.addListener(_handleControllerChange);
    controller.addStatusListener(_handleControllerStatusChange);
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChange);
    controller.removeStatusListener(_handleControllerStatusChange);
    super.dispose();
  }

  void _handleControllerChange() {
    // I need to check what the state of the tab and set the end colors of tweens accordingly.
    // That will ensure the correct looking animation
    // when the page is being swiped and the route is being collapesed/expanded at the same moment.

    final systemNavigationBarColorTween = ColorTween(
      begin: Constants.UiTheme.grey.auto.systemNavigationBarColor,
      end: Constants.UiTheme.black.auto.systemNavigationBarColor,
    );

    // Change system UI on expanding/collapsing the player route.
    NFSystemUiControl.setSystemUiOverlay(
      NFSystemUiControl.lastUi.copyWith(
        systemNavigationBarColor: systemNavigationBarColorTween.evaluate(
          controller,
        ),
      ),
    );
  }

  void _handleControllerStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      _changeTab(0);
    }
  }

  Animation _queueTabAnimation;
  bool dontJump = false;

  void _handleQueueTabAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      if (dontJump) {
        /// Don't jump.
        dontJump = false;
      } else {
        /// When the main tab is fully visible and the queue tab is not,
        /// reset the scroll controller.
        _queueTabKey.currentState.jumpOnTabChange();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final sign = textScaleFactor < 1 ? 1 : -1;
    final backgroundColor = ThemeControl.theme.colorScheme.background;
    return Slidable(
      controller: controller,
      // startOffset:
      //     Offset(0.92 + sign * 0.002 * math.pow(textScaleFactor, 8), 0.0),
      startOffset: Offset(1.0 - kSongTileHeight / screenHeight, 0.0),
      endOffset: const Offset(0.0, 0.0),
      direction: SlideDirection.upFromBottom,
      barrier: Container(
        color: ThemeControl.isDark ? Colors.black : Colors.black26,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          color: backgroundColor,
          child: Stack(
            children: <Widget>[
              GestureDetector(
                onHorizontalDragStart: (_) {
                  canTransition = true;
                },
                onHorizontalDragUpdate: (details) {
                  if (canTransition) {
                    dragDelta += details.delta.dx;
                    if (dragDelta.abs() > 15.0) {
                      if (dragDelta.sign > 0.0 && index - 1 >= 0) {
                        _changeTab(index - 1);
                        canTransition = false;
                      } else if (dragDelta.sign < 0.0 && index + 1 < 2) {
                        /// Don't jump when user swipes to right and the previous animation
                        /// didn't reach the main tab. If I don't do this, the unwanted jump will occur
                        /// and user will see it while on the queue tab.
                        if (!_queueTabAnimation.isDismissed) {
                          dontJump = true;
                        }
                        _changeTab(index + 1);
                        canTransition = false;
                      }
                    }
                  }
                },
                onHorizontalDragEnd: (_) {
                  canTransition = false;
                  dragDelta = 0.0;
                },
                child: IndexedTransitionSwitcher(
                  index: index,
                  duration: const Duration(milliseconds: 200),
                  reverse: prevIndex > index,
                  children: _tabs,
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                  ) {
                    if (child is _QueueTab) {
                      if (animation != _queueTabAnimation) {
                        _queueTabAnimation = animation;
                        animation.addStatusListener(
                          _handleQueueTabAnimationStatus,
                        );
                      }
                    }
                    return SharedAxisTransition(
                      transitionType: SharedAxisTransitionType.horizontal,
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      fillColor: Colors.transparent,
                      child: AnimatedBuilder(
                        animation: animation,
                        child: child,
                        builder: (context, child) => IgnorePointer(
                          ignoring: child is _QueueTab &&
                              animation.status == AnimationStatus.reverse,
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              ),
              TrackPanel(
                onTap: controller.open,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueTab extends StatefulWidget {
  _QueueTab({Key key}) : super(key: key);

  @override
  _QueueTabState createState() => _QueueTabState();
}

class _QueueTabState extends State<_QueueTab>
    with
        PlayerRouteControllerMixin,
        SingleTickerProviderStateMixin,
        SongSelectionMixin {
  /// Default scroll alignment.
  static const double scrollAlignment = 0.00;

  /// Scroll alignment for jumping to the end of the list.
  static const double endScrollAlignment = 0.9;

  static const double appBarHeight = 81.0;

  /// How much tracks to list end to apply [endScrollAlignment]
  int edgeOffset;
  int songsPerScreen;

  /// Min index to start from applying [endScrollAlignment].
  int get edgeScrollIndex => queueLength - 1 - edgeOffset;
  int prevSongIndex = ContentControl.state.currentSongIndex;
  int get queueLength => ContentControl.state.queues.current.length;

  /// This is set in parent via global key
  bool opened = false;
  final ItemScrollController itemScrollController = ItemScrollController();

  /// A bool var to disable show/hide in tracklist controller listener when manual [scrollToSong] is performing
  StreamSubscription<Song> _songChangeSubscription;
  StreamSubscription<void> _songListChangeSubscription;

  bool get isAlbum => ContentControl.state.queues.persistent is Album;
  Album get album {
    assert(isAlbum);
    return ContentControl.state.queues.persistent as Album;
  }

  QueueType get type => ContentControl.state.queues.type;

  @override
  void initState() {
    super.initState();
    songsPerScreen = (screenHeight / kSongTileHeight).ceil() - 2;
    edgeOffset = (screenHeight / kSongTileHeight / 2).ceil();
    _songListChangeSubscription =
        ContentControl.state.onSongListChange.listen((event) async {
      if (ContentControl.state.queues.all.isNotEmpty) {
        // Reset value when queue changes
        prevSongIndex = ContentControl.state.currentSongIndex;
        // Jump when tracklist changes (e.g. shuffle happened)
        jumpToSong();
        setState(() {/* update ui list as data list may have changed */});
      }
    });
    _songChangeSubscription =
        ContentControl.state.onSongChange.listen((event) async {
      setState(() {
        /* mupdate current track indicator */
      });
      if (!opened) {
        // Scroll when track changes
        await performScrolling();
      }
    });
  }

  @override
  void handleSongSelection() {}

  @override
  void handleSongSelectionStatus(AnimationStatus status) {}

  @override
  void dispose() {
    _songListChangeSubscription.cancel();
    _songChangeSubscription.cancel();
    super.dispose();
  }

  /// Scrolls to current song.
  ///
  /// If optional [index] is provided - scrolls to it.
  Future<void> scrollToSong(
      [int index, double alignment = scrollAlignment]) async {
    if (index == null) index = ContentControl.state.currentSongIndex;
    return itemScrollController.scrollTo(
      index: index,
      duration: Constants.scrollDuration,
      curve: Curves.easeOutCubic,
      opacityAnimationWeights: const [20, 20, 60],
      alignment: alignment,
    );
  }

  /// Jumps to current song.
  ///
  /// If optional [index] is provided - jumps to it.
  void jumpToSong([int index, double alignment = scrollAlignment]) async {
    if (index == null) index = ContentControl.state.currentSongIndex;
    itemScrollController.jumpTo(
      index: index,
      alignment: alignment,
    );
  }

  /// A more complex function with additional checks
  Future<void> performScrolling() async {
    final currentSongIndex = ContentControl.state.currentSongIndex;
    // Exit immediately if index didn't change
    if (prevSongIndex == currentSongIndex) return;
    // If queue is longer than e.g. 10 tracks
    if (queueLength > songsPerScreen) {
      if (currentSongIndex < edgeScrollIndex) {
        prevSongIndex = currentSongIndex;
        // Scroll to current song and tapped track is in between range [0:queueLength - offset]
        await scrollToSong();
      } else if (prevSongIndex > edgeScrollIndex) {
        /// Do nothing when it is already scrolled to [edgeScrollIndex]
        return;
      } else if (currentSongIndex >= edgeScrollIndex) {
        prevSongIndex = currentSongIndex;
        await scrollToSong(queueLength - 1, endScrollAlignment);
      } else {
        prevSongIndex = currentSongIndex;
        scrollToSong();
      }
    }
  }

  /// Jump to song when changing tab to `0`
  Future<void> jumpOnTabChange() async {
    final currentSongIndex = ContentControl.state.currentSongIndex;
    // If queue is longer than e.g. 6
    if (queueLength > songsPerScreen) {
      if (currentSongIndex < edgeScrollIndex) {
        jumpToSong();
      } else {
        // If at the end of the list
        jumpToSong(queueLength - 1, endScrollAlignment);
      }
    }
  }

  void _handleTitleTap() {
    switch (type) {
      case QueueType.searched:
        final query = ContentControl.state.queues.searchQuery;
        assert(query != null);
        if (query != null) {
          SearchPageRoute searchRoute;
          App.homeNavigatorKey.currentState.popUntil((route) {
            final name = route?.settings?.name;
            if (name == Constants.HomeRoutes.search.value) {
              searchRoute = route;
            }
            return name == Constants.HomeRoutes.tabs.value ||
                name == Constants.HomeRoutes.search.value;
          });
          if (searchRoute != null) {
            searchRoute.delegate.query = query;
            searchRoute.delegate.showResults(context);
          } else {
            ShowFunctions.showSongsSearch(
              App.homeNavigatorKey.currentContext,
              // This query won't be saved into history.
              query: query,
              openKeyboard: false,
            );
          }
          playerRouteController.close();
          SearchHistory.instance.save(query);
        }
        return;
      case QueueType.persistent:
        if (isAlbum) {
          App.homeNavigatorKey.currentState.popUntil((route) {
            final name = route?.settings?.name;
            return name == Constants.HomeRoutes.tabs.value ||
                name == Constants.HomeRoutes.search.value;
          });
          App.homeNavigatorKey.currentState.pushNamed(
            Constants.HomeRoutes.album.value,
            arguments: album,
          );
          playerRouteController.close();
        } else {
          assert(false);
        }
        return;
      case QueueType.all:
      case QueueType.arbitrary:
        return;
      default:
        assert(false);
    }
  }

  List<TextSpan> _getQueueType(AppLocalizations l10n) {
    List<TextSpan> text = [];
    switch (ContentControl.state.queues.type) {
      case QueueType.all:
        text.add(TextSpan(text: l10n.allTracks));
        break;
      case QueueType.searched:
        final query = ContentControl.state.queues.searchQuery;
        assert(query != null);
        text.add(TextSpan(
          text: '${l10n.found} ${l10n.byQuery.toLowerCase()} ',
        ));
        text.add(TextSpan(
          text: '"$query"',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: ThemeControl.theme.colorScheme.onBackground,
          ),
        ));
        break;
      case QueueType.persistent:
        if (isAlbum) {
          text.add(TextSpan(text: '${l10n.album} '));
          text.add(TextSpan(
            text: album.album + _getYear(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: ThemeControl.theme.colorScheme.onBackground,
            ),
          ));
        } else {
          assert(false);
        }
        break;
      case QueueType.arbitrary:
        text.add(TextSpan(text: l10n.arbitraryQueue));
        break;
      default:
        assert(false);
    }
    return text;
  }

  String _getYear() {
    final year = album.year;
    if (year == null) {
      return '';
    }
    return ' • $year';
  }

  Text _buildTitleText(List<TextSpan> text) {
    return Text.rich(
      TextSpan(children: text),
      overflow: TextOverflow.ellipsis,
      style: ThemeControl.theme.textTheme.subtitle2.copyWith(
        fontSize: 14.0,
        height: 1.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSongIndex = ContentControl.state.currentSongIndex;
    var initialAlignment = scrollAlignment;
    var initialScrollIndex = 0;
    if (queueLength > songsPerScreen) {
      if (currentSongIndex >= edgeScrollIndex) {
        initialAlignment = endScrollAlignment;
        initialScrollIndex = queueLength - 1;
      } else {
        initialScrollIndex = currentSongIndex;
      }
    }
    final l10n = getl10n(context);
    final horizontalPadding = isAlbum ? 12.0 : 20.0;
    final topScreenPadding = MediaQuery.of(context).padding.top;
    final appBarHeightWithPadding = appBarHeight + topScreenPadding;
    final fadeAnimation = CurvedAnimation(
      curve: const Interval(0.6, 1.0),
      parent: playerRouteController,
    );
    final appBar = Material(
      elevation: 2.0,
      color: ThemeControl.theme.appBarTheme.color,
      child: Container(
        height: appBarHeight,
        margin: EdgeInsets.only(top: topScreenPadding),
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          top: 24.0,
          bottom: 0.0,
        ),
        child: AnimatedBuilder(
          animation: playerRouteController,
          builder: (context, child) => FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
          child: GestureDetector(
            onTap: _handleTitleTap,
            child: Row(
              children: [
                if (isAlbum)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0, right: 10.0),
                    child: AlbumArt(
                      path: album.albumArt,
                      borderRadius: 8,
                      size: kSongTileArtSize - 8.0,
                    ),
                  ),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          Text(
                            l10n.upNext,
                            style:
                                ThemeControl.theme.textTheme.headline6.copyWith(
                              fontSize: 24,
                              height: 1.2,
                            ),
                          ),
                          if (ContentControl.state.queues.modified)
                            Padding(
                              padding: const EdgeInsets.only(left: 5.0),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 18.0,
                              ),
                            ),
                          if (ContentControl.state.queues.shuffled)
                            Padding(
                              padding: const EdgeInsets.only(left: 2.0),
                              child: const Icon(
                                Icons.shuffle_rounded,
                                size: 20.0,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: _buildTitleText(
                              _getQueueType(l10n),
                            ),
                          ),
                          if (isAlbum || type == QueueType.searched)
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18.0,
                              color:
                                  ThemeControl.theme.textTheme.subtitle2.color,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: appBarHeightWithPadding),
            child: PlayerRouteQueue(
              selectionController: songSelectionController,
              itemScrollController: itemScrollController,
              initialAlignment: initialAlignment,
              initialScrollIndex: initialScrollIndex,
            ),
          ),
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            child: appBar,
          ),
        ],
      ),
    );
  }
}

class _MainTab extends StatefulWidget {
  const _MainTab();
  @override
  _MainTabState createState() => _MainTabState();
}

class _MainTabState extends State<_MainTab> with PlayerRouteControllerMixin {
  // Color _prevColor = ContentControl.currentArtColor;
  // StreamSubscription<Color> _artColorChangeSubscription;
  // AnimationController _animationController;
  // Animation<Color> _colorAnimation;

  // @override
  // void initState() {
  //   super.initState();

  //   _animationController = AnimationController(
  //       vsync: this, duration: const Duration(milliseconds: 550));
  //   _animationController.addListener(() {
  //     setState(() {});
  //   });
  // _colorAnimation = ColorTween(
  //         begin: ContentControl.currentArtColor,
  //         end: ContentControl.currentArtColor)
  //     .animate(CurvedAnimation(
  //         curve: Curves.easeOutCubic, parent: _animationController));

  //   _artColorChangeSubscription =
  //       ContentControl.onArtColorChange.listen((event) {
  //     setState(() {
  //       _animationController.value = 0;
  //       _colorAnimation = ColorTween(begin: _prevColor, end: event).animate(
  //           CurvedAnimation(
  //               curve: Curves.easeOutCubic, parent: _animationController));
  //       _prevColor = event;
  //       _animationController.forward();
  //     });
  //   });
  // }

  // @override
  // void dispose() {
  //   _artColorChangeSubscription.cancel();
  //   _animationController.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    final animation = ColorTween(
      begin: ThemeControl.theme.colorScheme.secondary,
      end: ThemeControl.theme.colorScheme.background,
    ).animate(playerRouteController);
    final fadeAnimation = CurvedAnimation(
      curve: const Interval(0.6, 1.0),
      parent: playerRouteController,
    );
    return AnimatedBuilder(
      animation: playerRouteController,
      builder: (context, child) => NFPageBase(
        resizeToAvoidBottomInset: false,
        enableElevation: false,
        backgroundColor: animation.value,
        appBarBackgroundColor: Colors.transparent,
        backButton: FadeTransition(
          opacity: fadeAnimation,
          child: NFIconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded),
            size: 40.0,
            onPressed: playerRouteController.close,
          ),
        ),
        actions: <Widget>[
          ValueListenableBuilder(
            valueListenable: ContentControl.state.devMode,
            builder: (context, value, child) =>
                value ? child : const SizedBox.shrink(),
            child: FadeTransition(
              opacity: fadeAnimation,
              child: const _InfoButton(),
            ),
          ),
        ],
        child: child,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(const Size(500.0, 800.0)),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const _TrackShowcase(),
              Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Container(
                      child: _Seekbar(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 40.0,
                      top: 10.0,
                    ),
                    child: _PlaybackButtons(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackButtons extends StatelessWidget {
  const _PlaybackButtons({Key key}) : super(key: key);
  static const buttonMargin = 18.0;
  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const ShuffleButton(),
        SizedBox(width: buttonMargin),
        Container(
          padding: const EdgeInsets.only(right: buttonMargin),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100.0),
          ),
          child: NFIconButton(
            size: 50.0,
            iconSize: textScaleFactor * 30.0,
            icon: const Icon(Icons.skip_previous_rounded),
            onPressed: MusicPlayer.playPrev,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: ThemeControl.theme.colorScheme.secondary,
            borderRadius: BorderRadius.circular(100.0),
          ),
          child: Material(
            color: Colors.transparent,
            child: AnimatedPlayPauseButton(
              iconSize: 26.0,
              size: 70.0,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: buttonMargin),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100.0),
          ),
          child: NFIconButton(
            size: textScaleFactor * 50.0,
            iconSize: textScaleFactor * 30.0,
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: MusicPlayer.playNext,
          ),
        ),
        SizedBox(width: buttonMargin),
        const LoopButton(),
      ],
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = getl10n(context);
    return Padding(
      padding: const EdgeInsets.only(right: 5.0),
      child: NFIconButton(
        icon: Icon(Icons.info_outline_rounded),
        size: 40.0,
        onPressed: () {
          var songInfo = ContentControl.state.currentSong
              ?.toJson()
              .toString()
              .replaceAll(r', ', ',\n');
          if (songInfo != null) {
            songInfo = songInfo.substring(1, songInfo.length - 1);
          }
          ShowFunctions.instance.showAlert(
            context,
            title: Text(
              l10n.songInformation,
              textAlign: TextAlign.center,
            ),
            contentPadding: defaultAlertContentPadding.copyWith(top: 4.0),
            content: SelectableText(
              songInfo ?? 'null',
              style: const TextStyle(fontSize: 13.0),
              selectionControls: NFTextSelectionControls(
                backgroundColor: ThemeControl.theme.colorScheme.background,
              ),
            ),
            additionalActions: [
              NFCopyButton(text: songInfo),
            ],
          );
        },
      ),
    );
  }
}

/// A widget that displays all information about current song
class _TrackShowcase extends StatefulWidget {
  const _TrackShowcase({Key key}) : super(key: key);
  @override
  _TrackShowcaseState createState() => _TrackShowcaseState();
}

class _TrackShowcaseState extends State<_TrackShowcase> {
  StreamSubscription<Song> _songChangeSubscription;
  StreamSubscription<void> _songListChangeSubscription;

  @override
  void initState() {
    super.initState();
    _songChangeSubscription =
        ContentControl.state.onSongChange.listen((event) async {
      setState(() {/* update track in ui */});
    });

    _songListChangeSubscription =
        ContentControl.state.onSongListChange.listen((event) async {
      setState(() {
        /// This needed to keep sync with album arts, because they are fetched with [ContentControl.refetchAlbums], which runs without `await` in [ContentControl.init]
        /// So sometimes even though current song is being restored, its album art might still be fetching.
      });
    });
  }

  @override
  void dispose() {
    _songChangeSubscription.cancel();
    _songListChangeSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ContentControl.state.currentSong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: NFMarquee(
            key: ValueKey(ContentControl.state.currentSongId),
            fontWeight: FontWeight.w900,
            text: currentSong.title,
            fontSize: 20.0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2.0, bottom: 30.0),
          child: ArtistWidget(
            artist: currentSong.artist,
            textStyle: const TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 60.0,
            right: 60.0,
            top: 10.0,
          ),
          child: AlbumArt.playerRoute(path: currentSong.albumArt),
        ),
      ],
    );
  }
}

class _Seekbar extends StatefulWidget {
  _Seekbar({Key key}) : super(key: key);

  _SeekbarState createState() => _SeekbarState();
}

class _SeekbarState extends State<_Seekbar> {
  // Duration of playing track
  Duration _duration = Duration(seconds: 0);

  /// Actual track position value
  double _value = 0.0;

  /// Value to perform drag
  double _localValue;

  /// Is user dragging slider right now
  bool _isDragging = false;

  /// Value to work with, depends on [_isDragging] state, either [_value] or [_localValue]
  double get workingValue => _isDragging ? _localValue : _value;

  SharedPreferences prefs;

  /// Subscription for audio position change stream
  StreamSubscription<Duration> _positionSubscription;
  StreamSubscription<Song> _songChangeSubscription;

  @override
  void initState() {
    super.initState();
    _setInitialPosition();
    // Handle track position movement
    _positionSubscription = MusicPlayer.onPosition.listen((position) {
      if (!_isDragging) {
        setState(() {
          _value = _positionToValue(position);
        });
      }
    });
    // Handle track switch
    _songChangeSubscription = ContentControl.state.onSongChange.listen((event) {
      setState(() {
        _isDragging = false;
        _localValue = 0.0;
        _value = 0.0;
        _duration = Duration(milliseconds: event.duration);
      });
    });
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _songChangeSubscription.cancel();
    super.dispose();
  }

  double _positionToValue(Duration position) {
    return (position.inMilliseconds / math.max(_duration.inMilliseconds, 1.0))
        .clamp(0.0, 1.0);
  }

  Future<void> _setInitialPosition() async {
    var position = await MusicPlayer.position;
    if (mounted) {
      setState(() {
        _duration =
            Duration(milliseconds: ContentControl.state.currentSong?.duration);
        _value = _positionToValue(position);
      });
    }
  }

  // Drag functions
  void _handleChangeStart(double newValue) {
    setState(() {
      _isDragging = true;
      _localValue = newValue;
    });
  }

  void _handleChanged(double newValue) {
    setState(() {
      if (!_isDragging) _isDragging = true;
      _localValue = newValue;
    });
  }

  /// FIXME: https://github.com/nt4f04uNd/sweyer/issues/6
  void _handleChangeEnd(double newValue) async {
    await MusicPlayer.seek(_duration * newValue);
    if (mounted) {
      setState(() {
        _isDragging = false;
        _value = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final scaleFactor = textScaleFactor == 1.0 ? 1.0 : textScaleFactor * 1.1;
    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 36.0 * scaleFactor,
            transform: Matrix4.translationValues(5.0, 0.0, 0.0),
            child: Text(
              (_duration * workingValue).getFormattedDuration(),
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: ThemeControl.theme.textTheme.headline6.color,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.0,
                activeTrackColor: ThemeControl.theme.colorScheme.primary,
                inactiveTrackColor: Constants.AppTheme.sliderInactive.auto,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7.5,
                ),
              ),
              child: Slider(
                value: _isDragging ? _localValue : _value,
                onChangeStart: _handleChangeStart,
                onChanged: _handleChanged,
                onChangeEnd: _handleChangeEnd,
              ),
            ),
          ),
          Container(
            width: 36.0 * scaleFactor,
            transform: Matrix4.translationValues(-5.0, 0.0, 0.0),
            child: Text(
              _duration.getFormattedDuration(),
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: ThemeControl.theme.textTheme.headline6.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
