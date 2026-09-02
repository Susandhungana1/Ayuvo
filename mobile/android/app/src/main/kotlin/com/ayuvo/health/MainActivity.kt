package com.ayuvo.health

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * `FlutterFragmentActivity`, not `FlutterActivity`.
 *
 * `local_auth` shows the biometric prompt through AndroidX `BiometricPrompt`,
 * which is a fragment and needs a `FragmentActivity` to attach to. On a plain
 * `FlutterActivity` every call to `authenticate()` throws `no_fragment_activity`
 * at runtime — it builds and installs fine, and only fails the first time
 * somebody puts a finger on the sensor.
 */
class MainActivity : FlutterFragmentActivity()
