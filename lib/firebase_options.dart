import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firebase options are read from `.env` at startup.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _required('FIREBASE_WEB_API_KEY'),
        appId: _required('FIREBASE_WEB_APP_ID'),
        messagingSenderId: _required('FIREBASE_WEB_MESSAGING_SENDER_ID'),
        projectId: _required('FIREBASE_WEB_PROJECT_ID'),
        authDomain: _required('FIREBASE_WEB_AUTH_DOMAIN'),
        storageBucket: _required('FIREBASE_WEB_STORAGE_BUCKET'),
        measurementId: _optional('FIREBASE_WEB_MEASUREMENT_ID'),
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _required('FIREBASE_ANDROID_API_KEY'),
        appId: _required('FIREBASE_ANDROID_APP_ID'),
        messagingSenderId: _required('FIREBASE_ANDROID_MESSAGING_SENDER_ID'),
        projectId: _required('FIREBASE_ANDROID_PROJECT_ID'),
        storageBucket: _required('FIREBASE_ANDROID_STORAGE_BUCKET'),
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _required('FIREBASE_IOS_API_KEY'),
        appId: _required('FIREBASE_IOS_APP_ID'),
        messagingSenderId: _required('FIREBASE_IOS_MESSAGING_SENDER_ID'),
        projectId: _required('FIREBASE_IOS_PROJECT_ID'),
        storageBucket: _required('FIREBASE_IOS_STORAGE_BUCKET'),
        iosBundleId: _required('FIREBASE_IOS_BUNDLE_ID'),
      );

  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: _required('FIREBASE_MACOS_API_KEY'),
        appId: _required('FIREBASE_MACOS_APP_ID'),
        messagingSenderId: _required('FIREBASE_MACOS_MESSAGING_SENDER_ID'),
        projectId: _required('FIREBASE_MACOS_PROJECT_ID'),
        storageBucket: _required('FIREBASE_MACOS_STORAGE_BUCKET'),
        iosBundleId: _required('FIREBASE_MACOS_BUNDLE_ID'),
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: _required('FIREBASE_WINDOWS_API_KEY'),
        appId: _required('FIREBASE_WINDOWS_APP_ID'),
        messagingSenderId: _required('FIREBASE_WINDOWS_MESSAGING_SENDER_ID'),
        projectId: _required('FIREBASE_WINDOWS_PROJECT_ID'),
        authDomain: _required('FIREBASE_WINDOWS_AUTH_DOMAIN'),
        storageBucket: _required('FIREBASE_WINDOWS_STORAGE_BUCKET'),
        measurementId: _optional('FIREBASE_WINDOWS_MEASUREMENT_ID'),
      );

  static String _required(String key) {
    final value = dotenv.env[key];
    if (value == null || value.trim().isEmpty) {
      throw StateError('Missing required env variable: $key');
    }
    return value;
  }

  static String? _optional(String key) {
    final value = dotenv.env[key];
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }
}
