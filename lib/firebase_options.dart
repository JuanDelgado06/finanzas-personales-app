// ARCHIVO TEMPORAL — Reemplazar con el generado por `flutterfire configure`
//
// Pasos para configurarlo correctamente:
// 1. Instalar Firebase CLI: npm install -g firebase-tools
// 2. Autenticarse: firebase login
// 3. Instalar FlutterFire CLI (ya hecho): ya está en C:\Users\josed\AppData\Local\Pub\Cache\bin\flutterfire.bat
// 4. Ejecutar en la carpeta del proyecto Flutter (C:\Users\josed\dev\finanzas_personales):
//    C:\Users\josed\AppData\Local\Pub\Cache\bin\flutterfire.bat configure --project=control-de-finanzas-mensuales
//    (El nombre del proyecto de Firebase es el mismo que usa la web app)
// 5. Ese comando reemplazará este archivo automáticamente.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions no soportado en esta plataforma');
    }
  }

  // ⚠️ REEMPLAZA estos valores con los de tu proyecto Firebase

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCK3gFc6rU12yAevOV3uPOlQds-_Y3uXGM',
    appId: '1:1035168087468:web:0cc3d8773dededc73cce09',
    messagingSenderId: '1035168087468',
    projectId: 'control-de-finanzas-mensuales',
    authDomain: 'control-de-finanzas-mensuales.firebaseapp.com',
    storageBucket: 'control-de-finanzas-mensuales.firebasestorage.app',
    measurementId: 'G-BYYYRK3PES',
  );

  // Ve a: https://console.firebase.google.com → Configuración del proyecto → Tus apps

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA6U3FZhX6D7-wOsYH8aAANCS1CAMLuUGE',
    appId: '1:1035168087468:android:2bb84be08c6053b83cce09',
    messagingSenderId: '1035168087468',
    projectId: 'control-de-finanzas-mensuales',
    storageBucket: 'control-de-finanzas-mensuales.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBEi5Dnme32GXxwSN2w4txtqFcTNsfhsC0',
    appId: '1:1035168087468:ios:ecce9d5b110a841d3cce09',
    messagingSenderId: '1035168087468',
    projectId: 'control-de-finanzas-mensuales',
    storageBucket: 'control-de-finanzas-mensuales.firebasestorage.app',
    iosClientId: '1035168087468-07mm48ib3q02h4jbfnh58ajaikiudbfa.apps.googleusercontent.com',
    iosBundleId: 'com.finanzaspersonales.finanzasPersonales',
  );

}