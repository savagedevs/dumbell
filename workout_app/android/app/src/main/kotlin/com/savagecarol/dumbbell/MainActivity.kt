package com.savagecarol.dumbbell

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var liveWorkoutChannel: MethodChannel? = null
    private var pendingOpenWorkout = false
    private var dartReady = false
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingOpenWorkout = intent?.action == LiveWorkoutSurfaces.ACTION_OPEN_WORKOUT
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LiveWorkoutSurfaces.createNotificationChannel(this)
        liveWorkoutChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "liftlog/live_workout",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWorkout" -> {
                        if (isFinishing || isDestroyed) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            val arguments = call.arguments as? Map<*, *>
                                ?: throw IllegalArgumentException("Expected workout details.")
                            val snapshot = LiveWorkoutSnapshot.fromArguments(arguments)
                            val accepted = LiveWorkoutStore.update(this, snapshot)
                            LiveWorkoutSurfaces.update(this, accepted)
                            result.success(null)
                        } catch (exception: IllegalArgumentException) {
                            result.error("invalid_snapshot", exception.message, null)
                        }
                    }
                    "getLaunchAction" -> {
                        dartReady = true
                        val shouldOpen = pendingOpenWorkout
                        pendingOpenWorkout = false
                        result.success(shouldOpen)
                    }
                    "requestNotifications" -> requestNotifications(result)
                    "notificationsEnabled" -> result.success(
                        LiveWorkoutSurfaces.notificationsEnabled(this),
                    )
                    "requestPinWidget" -> result.success(
                        LiveWorkoutWidgetProvider.requestPin(this),
                    )
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action != LiveWorkoutSurfaces.ACTION_OPEN_WORKOUT) return
        pendingOpenWorkout = true
        if (dartReady) {
            // getLaunchAction buffers a cold start; this handles an already running app.
            pendingOpenWorkout = false
            liveWorkoutChannel?.invokeMethod("openWorkout", null, object : MethodChannel.Result {
                override fun success(result: Any?) = Unit
                override fun error(code: String, message: String?, details: Any?) {
                    pendingOpenWorkout = true
                }
                override fun notImplemented() {
                    pendingOpenWorkout = true
                }
            })
        }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(LiveWorkoutSurfaces.notificationsEnabled(this))
            return
        }
        if (notificationPermissionResult != null) {
            result.error("permission_in_progress", "A notification permission request is open.", null)
            return
        }
        notificationPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION) return
        notificationPermissionResult?.success(LiveWorkoutSurfaces.notificationsEnabled(this))
        notificationPermissionResult = null
        LiveWorkoutSurfaces.update(this, LiveWorkoutStore.read(this))
    }

    override fun onDestroy() {
        // Backgrounding keeps the live surfaces running. A real finish keeps only a draft.
        if (isFinishing && !isChangingConfigurations) {
            LiveWorkoutSurfaces.update(this, LiveWorkoutStore.markInactive(this))
        }
        notificationPermissionResult?.success(false)
        notificationPermissionResult = null
        liveWorkoutChannel?.setMethodCallHandler(null)
        liveWorkoutChannel = null
        dartReady = false
        super.onDestroy()
    }

    private companion object {
        const val NOTIFICATION_PERMISSION = 4381
    }
}
