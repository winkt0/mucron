import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef MicListener = void Function(dynamic data);

class MicStreamService {
  MicStreamService._() {
    _sub = _channel.receiveBroadcastStream().listen(
      _onData,
      onError: (e) => debugPrint('Audio error: $e'),
    );
  }
  static final MicStreamService instance = MicStreamService._();
  static const _channel = EventChannel('com.example.mic_stream/audio');
  late StreamSubscription? _sub;
  final List<MicListener> _listeners = [];

  void addListener(MicListener listener) {
    _listeners.add(listener);
    //ensureSubscribed();
  }

  void removeListener(MicListener listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _sub?.cancel();
      _sub = null;
    }
  }

  void _onData(dynamic data) {
    for (MicListener listener in List<MicListener>.from(_listeners)) {
      try {
        listener(data);
      } catch (e, st) {
        debugPrint("shit");
        debugPrint(e.toString());
        debugPrint(st.toString());
      }
    }
  }
}
