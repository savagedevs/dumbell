package com.savagecarol.dumbbell

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

internal object LiveWorkoutSurfaces {
    const val ACTION_OPEN_WORKOUT = "com.savagecarol.dumbbell.OPEN_WORKOUT"
    private const val ACTION_OPEN_APP = "com.savagecarol.dumbbell.OPEN_APP"
    private const val CHANNEL_ID = "liftlog_live_workout"
    private const val NOTIFICATION_ID = 4380
    internal const val NOTIFICATION_TAP = 4382
    const val WIDGET_TAP = 4383

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.live_workout_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(R.string.live_workout_channel_description)
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        manager(context).createNotificationChannel(channel)
    }

    fun notificationsEnabled(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        val manager = manager(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) {
            return false
        }
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            manager.getNotificationChannel(CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
    }

    fun update(context: Context, snapshot: LiveWorkoutSnapshot?) {
        LiveWorkoutWidgetProvider.updateAll(context, snapshot)
        val manager = manager(context)
        if (snapshot?.active != true || !notificationsEnabled(context)) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        createNotificationChannel(context)
        val content = context.getString(
            R.string.live_workout_notification_detail,
            snapshot.exerciseName ?: context.getString(R.string.live_workout_no_exercise),
            snapshot.completedSets,
            snapshot.totalSets,
        )
        val publicVersion = builder(context)
            .setSmallIcon(R.drawable.ic_live_workout)
            .setContentTitle(context.getString(R.string.app_name))
            .setContentText(context.getString(R.string.live_workout_public_notification))
            .setWhen(snapshot.startedAtMs)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
        val notification = builder(context)
            .setSmallIcon(R.drawable.ic_live_workout)
            .setColor(context.getColor(R.color.live_workout_notification_accent))
            .setContentTitle(snapshot.workoutName)
            .setContentText(content)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(LiveWorkoutNotification.views(context, snapshot, expanded = false))
            .setCustomBigContentView(LiveWorkoutNotification.views(context, snapshot, expanded = true))
            .setSubText(context.getString(R.string.live_workout_public_notification))
            .setWhen(snapshot.startedAtMs)
            .setShowWhen(false)
            .setUsesChronometer(false)
            .setContentIntent(openIntent(context, resumeWorkout = true, requestCode = NOTIFICATION_TAP))
            .addAction(Notification.Action.Builder(null,
                context.getString(R.string.live_workout_notification_resume),
                openIntent(context, resumeWorkout = true, requestCode = NOTIFICATION_TAP)).build())
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Permission can be revoked between checking and posting; widgets still work.
        }
    }

    fun openIntent(context: Context, resumeWorkout: Boolean, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = if (resumeWorkout) ACTION_OPEN_WORKOUT else ACTION_OPEN_APP
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_IMMUTABLE)
    }

    @Suppress("DEPRECATION")
    private fun builder(context: Context): Notification.Builder =
        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(context, CHANNEL_ID)
        else Notification.Builder(context)).apply {
            setDefaults(0)
            setSound(null)
            setVibrate(longArrayOf(0))
            setPriority(Notification.PRIORITY_LOW)
        }

    private fun manager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
