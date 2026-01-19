import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Callback for when a URL is received
typedef UrlReceivedCallback = void Function(String url);

/// Service to handle incoming shared URLs from iOS/Android
class ShareHandlerService {
  static const MethodChannel _channel =
      MethodChannel('com.reciperipper/shared_url');

  UrlReceivedCallback? _onUrlReceived;

  /// Initializes the share handler and sets up method call handler
  void initialize({UrlReceivedCallback? onUrlReceived}) {
    _onUrlReceived = onUrlReceived;

    // Set up handler for incoming method calls from native side
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handles method calls from the native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'urlReceived') {
      final url = call.arguments as String?;
      if (url != null && _onUrlReceived != null) {
        _onUrlReceived!(url);
      }
      return null;
    }
    throw PlatformException(
      code: 'UNIMPLEMENTED',
      message: 'Method ${call.method} not implemented',
    );
  }

  /// Gets any shared URL that was passed when the app was launched
  Future<String?> getInitialSharedUrl() async {
    try {
      final url = await _channel.invokeMethod<String>('getSharedUrl');
      return url;
    } on PlatformException catch (e) {
      debugPrint('Failed to get shared URL: ${e.message}');
      return null;
    }
  }

  /// Clears the callback
  void dispose() {
    _onUrlReceived = null;
  }
}
