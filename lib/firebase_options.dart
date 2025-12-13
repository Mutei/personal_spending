import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    // apiKey: 'YOUR_API_KEY',
    // appId: 'YOUR_WEB_APP_ID',
    // messagingSenderId: 'YOUR_SENDER_ID',
    // projectId: 'YOUR_PROJECT_ID',
    // storageBucket: 'YOUR_BUCKET.appspot.com',
    apiKey: "AIzaSyCuJ0n0a0SAXnnqUYKY696keektFzHA1Y4",
    authDomain: "personal-spendings-531a1.firebaseapp.com",
    projectId: "personal-spendings-531a1",
    storageBucket: "personal-spendings-531a1.firebasestorage.app",
    messagingSenderId: "287540285495",
    appId: "1:287540285495:web:7423f0b304631f56de6fb2",
  );

  static const FirebaseOptions android = FirebaseOptions(
    // apiKey: 'YOUR_ANDROID_API_KEY',
    // appId: 'YOUR_ANDROID_APP_ID',
    // messagingSenderId: 'YOUR_SENDER_ID',
    // projectId: 'YOUR_PROJECT_ID',
    // storageBucket: 'YOUR_BUCKET.appspot.com',
    apiKey: "AIzaSyCuJ0n0a0SAXnnqUYKY696keektFzHA1Y4",
    authDomain: "personal-spendings-531a1.firebaseapp.com",
    projectId: "personal-spendings-531a1",
    storageBucket: "personal-spendings-531a1.firebasestorage.app",
    messagingSenderId: "287540285495",
    appId: "1:287540285495:web:7423f0b304631f56de6fb2",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    // apiKey: 'YOUR_IOS_API_KEY',
    // appId: 'YOUR_IOS_APP_ID',
    // messagingSenderId: 'YOUR_SENDER_ID',
    // projectId: 'YOUR_PROJECT_ID',
    // storageBucket: 'YOUR_BUCKET.appspot.com',
    // iosBundleId: 'com.example.personalSpendings',
    apiKey: "AIzaSyCuJ0n0a0SAXnnqUYKY696keektFzHA1Y4",
    authDomain: "personal-spendings-531a1.firebaseapp.com",
    projectId: "personal-spendings-531a1",
    storageBucket: "personal-spendings-531a1.firebasestorage.app",
    messagingSenderId: "287540285495",
    appId: "1:287540285495:web:7423f0b304631f56de6fb2",
  );
}
