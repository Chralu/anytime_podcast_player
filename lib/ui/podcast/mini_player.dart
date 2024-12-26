// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:anytime/ui/podcast/now_playing.dart';
import 'package:anytime/ui/widgets/placeholder_builder.dart';
import 'package:anytime/ui/widgets/podcast_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';

/// Displays a mini podcast player widget if a podcast is playing or paused.
///
/// If stopped a zero height box is built instead. Tapping on the mini player
/// will open the main player window.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);

    return StreamBuilder<AudioState>(
      stream: audioBloc.playingState,
      initialData: AudioState.stopped,
      builder: (context, snapshot) {
        return snapshot.data != AudioState.stopped &&
                snapshot.data != AudioState.none &&
                snapshot.data != AudioState.error
            ? _MiniPlayerBuilder()
            : const SizedBox(
                height: 0,
              );
      },
    );
  }
}

class _MiniPlayerBuilder extends StatefulWidget {
  @override
  _MiniPlayerBuilderState createState() => _MiniPlayerBuilderState();
}

class _MiniPlayerBuilderState extends State<_MiniPlayerBuilder> with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;
  late StreamSubscription<AudioState> _audioStateSubscription;

  @override
  void initState() {
    super.initState();

    _playPauseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _playPauseController.value = 1;

    _audioStateListener();
  }

  @override
  void dispose() {
    _audioStateSubscription.cancel();
    _playPauseController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final width = MediaQuery.of(context).size.width;
    final placeholderBuilder = PlaceholderBuilder.of(context);

    return Dismissible(
      key: UniqueKey(),
      confirmDismiss: (direction) async {
        await _audioStateSubscription.cancel();
        audioBloc.transitionState(TransitionState.stop);
        return true;
      },
      direction: DismissDirection.startToEnd,
      background: Container(
        color: Theme.of(context).colorScheme.surface,
        height: 64,
      ),
      child: GestureDetector(
        key: const Key('miniplayergesture'),
        onTap: () async {
          await _audioStateSubscription.cancel();

          if (context.mounted) {
            await showModalBottomSheet<void>(
              context: context,
              routeSettings: const RouteSettings(name: 'nowplaying'),
              isScrollControlled: true,
              builder: (BuildContext modalContext) {
                return Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  child: const NowPlaying(),
                );
              },
            ).then((_) {
              _audioStateListener();
            });
          }
        },
        child: Semantics(
          header: true,
          label: L.of(context)!.semantics_mini_player_header,
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: Divider.createBorderSide(context, width: 1, color: Theme.of(context).dividerColor),
                bottom: Divider.createBorderSide(context, width: 0, color: Theme.of(context).dividerColor),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<Episode?>(
                    stream: audioBloc.nowPlaying,
                    builder: (context, snapshot) {
                      return StreamBuilder<AudioState>(
                        stream: audioBloc.playingState,
                        builder: (context, stateSnapshot) {
                          final playing = stateSnapshot.data == AudioState.playing;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(
                                height: 58,
                                width: 58,
                                child: ExcludeSemantics(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: snapshot.hasData
                                        ? PodcastImage(
                                            key: Key('mini${snapshot.data!.imageUrl}'),
                                            url: snapshot.data!.imageUrl!,
                                            width: 58,
                                            height: 58,
                                            borderRadius: 4,
                                            placeholder: placeholderBuilder != null
                                                ? placeholderBuilder.builder()(context)
                                                : const Image(
                                                    image: AssetImage('assets/images/anytime-placeholder-logo.png'),
                                                  ),
                                            errorPlaceholder: placeholderBuilder != null
                                                ? placeholderBuilder.errorBuilder()(context)
                                                : const Image(
                                                    image: AssetImage('assets/images/anytime-placeholder-logo.png'),
                                                  ),
                                          )
                                        : Container(),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      snapshot.data?.title ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodyMedium,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        snapshot.data?.author ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 52,
                                width: 52,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: CircleBorder(
                                      side: BorderSide(color: Theme.of(context).colorScheme.surface, width: 0),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (playing) {
                                      audioBloc.transitionState(TransitionState.fastforward);
                                    }
                                  },
                                  child: Icon(
                                    Icons.forward_30,
                                    semanticLabel: L.of(context)!.fast_forward_button_label,
                                    size: 36,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 52,
                                width: 52,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: CircleBorder(
                                      side: BorderSide(color: Theme.of(context).colorScheme.surface, width: 0),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (playing) {
                                      _pause(audioBloc);
                                    } else {
                                      _play(audioBloc);
                                    }
                                  },
                                  child: AnimatedIcon(
                                    semanticLabel:
                                        playing ? L.of(context)!.pause_button_label : L.of(context)!.play_button_label,
                                    size: 48,
                                    icon: AnimatedIcons.play_pause,
                                    color: Theme.of(context).iconTheme.color,
                                    progress: _playPauseController,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  StreamBuilder<PositionState>(
                    stream: audioBloc.playPosition,
                    builder: (context, snapshot) {
                      var cw = 0.0;
                      final position = snapshot.hasData ? snapshot.data!.position : Duration.zero;
                      final length = snapshot.hasData ? snapshot.data!.length : Duration.zero;

                      if (length.inSeconds > 0) {
                        final pc = length.inSeconds / position.inSeconds;
                        cw = width / pc;
                      }

                      return Container(
                        width: cw,
                        height: 1,
                        color: Theme.of(context).primaryColor,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// We call this method to setup a listener for changing [AudioState]. This in turns calls upon the [_pauseController]
  /// to animate the play/pause icon. The [AudioBloc] playingState method is backed by a [BehaviorSubject] so we'll
  /// always get the current state when we subscribe. This, however, has a side effect causing the play/pause icon to
  /// animate when returning from the full-size player, which looks a little odd. Therefore, on the first event we move
  /// the controller to the correct state without animating. This feels a little hacky, but stops the UI from looking a
  /// little odd.
  void _audioStateListener() {
    if (mounted) {
      final audioBloc = Provider.of<AudioBloc>(context, listen: false);
      var firstEvent = true;

      _audioStateSubscription = audioBloc.playingState!.listen((event) {
        if (event == AudioState.playing || event == AudioState.buffering) {
          if (firstEvent) {
            _playPauseController.value = 1;
            firstEvent = false;
          } else {
            _playPauseController.forward();
          }
        } else {
          if (firstEvent) {
            _playPauseController.value = 0;
            firstEvent = false;
          } else {
            _playPauseController.reverse();
          }
        }
      });
    }
  }

  void _play(AudioBloc audioBloc) {
    audioBloc.transitionState(TransitionState.play);
  }

  void _pause(AudioBloc audioBloc) {
    audioBloc.transitionState(TransitionState.pause);
  }
}
