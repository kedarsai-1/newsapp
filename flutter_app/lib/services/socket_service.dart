import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants.dart';

class SocketService {
  static IO.Socket? _socket;
  static bool _connected = false;

  static bool get isConnected => _connected;

  static void connect() {
    if (_connected) return;

    _socket = IO.io(
      AppConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      debugPrint('Socket connected');
      // Join the general feed room
      _socket!.emit('join_feed', 'all');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      debugPrint('Socket disconnected');
    });

    _socket!.onConnectError((err) => debugPrint('Socket error: $err'));

    _socket!.connect();
  }

  /// Listen for new approved posts pushed from the server
  static void onNewPost(void Function(Map<String, dynamic> data) callback) {
    _socket?.on('new_post', (data) {
      if (data is Map<String, dynamic>) callback(data);
    });
  }

  /// Join a specific category room for targeted updates
  static void joinCategory(String categorySlug) {
    _socket?.emit('join_feed', categorySlug);
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }
}