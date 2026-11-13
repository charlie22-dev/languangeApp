import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/lingo_localizations.dart';
import '../../features/audio/data/audio_service.dart';
import '../../features/audio/domain/audio_ports.dart';

class AudioSpeakerButton extends ConsumerStatefulWidget {
  const AudioSpeakerButton({
    super.key,
    required this.text,
    this.audioUrl,
    this.locale,
    this.enabled = true,
    this.onUnavailable,
  });
  final String text;
  final String? audioUrl, locale;
  final bool enabled;
  final VoidCallback? onUnavailable;
  @override
  ConsumerState<AudioSpeakerButton> createState() => _AudioSpeakerButtonState();
}

class _AudioSpeakerButtonState extends ConsumerState<AudioSpeakerButton> {
  final _owner = Object();
  AudioService? _service;
  bool _playing = false;
  int _request = 0;
  String? _error;
  @override
  void dispose() {
    if (_playing) unawaited(_service?.stop(owner: _owner));
    super.dispose();
  }

  @override
  void didUpdateWidget(AudioSpeakerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled && _playing) {
      unawaited(_service?.stop(owner: _owner));
    }
  }

  Future<void> _play() async {
    final AudioService service =
        _service ?? ref.read<AudioService>(audioServiceProvider);
    _service = service;
    if (_playing) {
      _request++;
      setState(() => _playing = false);
      await service.stop(owner: _owner);
      return;
    }
    final request = ++_request;
    setState(() {
      _playing = true;
      _error = null;
    });
    final result = await service.play(
      owner: _owner,
      text: widget.text,
      audioUrl: widget.audioUrl,
      locale: widget.locale ?? ref.read(pronunciationLocaleProvider),
    );
    if (!mounted || request != _request) return;
    setState(() {
      _playing = false;
      _error = switch (result) {
        AudioOutcome.missingVoice => 'audioMissingVoice',
        AudioOutcome.unavailable => 'audioUnavailable',
        _ => null,
      };
    });
    if (_error != null) widget.onUnavailable?.call();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.center,
        child: IconButton(
          tooltip: context.l10n.text(
            _playing ? 'stopPronunciation' : 'playPronunciation',
          ),
          onPressed: widget.enabled ? _play : null,
          icon: Icon(
            _playing ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
          ),
        ),
      ),
      if (_error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            context.l10n.text(_error!, {
              'locale':
                  widget.locale ??
                  ref.watch(pronunciationLocaleProvider) ??
                  context.l10n.text('selectedLanguage'),
            }),
          ),
        ),
    ],
  );
}
