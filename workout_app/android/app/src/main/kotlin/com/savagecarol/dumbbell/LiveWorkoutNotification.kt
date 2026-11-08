package com.savagecarol.dumbbell

import android.content.Context
import android.os.SystemClock
import android.widget.RemoteViews

/** Display-only views: Android advances the clock without waking Flutter or writing the draft. */
internal object LiveWorkoutNotification {
    fun views(context: Context, snapshot: LiveWorkoutSnapshot, expanded: Boolean): RemoteViews =
        RemoteViews(context.packageName, if (expanded)
            R.layout.live_workout_notification_expanded else R.layout.live_workout_notification).apply {
            val exercise = snapshot.exerciseName ?: context.getString(R.string.live_workout_no_exercise)
            val progress = context.getString(R.string.live_workout_widget_sets,
                snapshot.completedSets, snapshot.totalSets)
            setTextViewText(R.id.notification_exercise, exercise)
            setTextViewText(R.id.notification_progress, progress)
            val elapsed = (System.currentTimeMillis() - snapshot.startedAtMs).coerceAtLeast(0)
            setChronometer(R.id.notification_timer, SystemClock.elapsedRealtime() - elapsed, null, true)
            if (expanded) {
                setTextViewText(R.id.notification_workout, snapshot.workoutName)
                setProgressBar(R.id.notification_progress_bar, snapshot.totalSets.coerceAtLeast(1),
                    snapshot.completedSets, false)
                setContentDescription(R.id.notification_progress_bar, progress)
            }
            // The whole card and the system action use the same route and immutable intent.
            setOnClickPendingIntent(R.id.notification_root, LiveWorkoutSurfaces.openIntent(
                context, resumeWorkout = true, requestCode = LiveWorkoutSurfaces.NOTIFICATION_TAP))
        }
}
