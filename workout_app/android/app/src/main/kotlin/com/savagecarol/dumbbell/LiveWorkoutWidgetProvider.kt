package com.savagecarol.dumbbell

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

class LiveWorkoutWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            // Existing launcher instances adopt new layouts without being removed or re-pinned.
            updateAll(context, LiveWorkoutStore.read(context))
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val snapshot = LiveWorkoutStore.read(context)
        appWidgetIds.forEach {
            manager.updateAppWidget(it, views(context, snapshot, manager.getAppWidgetOptions(it)))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId,
            views(context, LiveWorkoutStore.read(context), newOptions))
    }

    companion object {
        internal fun updateAll(context: Context, snapshot: LiveWorkoutSnapshot?) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, LiveWorkoutWidgetProvider::class.java))
            ids.forEach {
                manager.updateAppWidget(it, views(context, snapshot, manager.getAppWidgetOptions(it)))
            }
        }

        internal fun requestPin(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
            val manager = AppWidgetManager.getInstance(context)
            if (!manager.isRequestPinAppWidgetSupported) return false
            val extras = Bundle().apply {
                putParcelable(AppWidgetManager.EXTRA_APPWIDGET_PREVIEW,
                    views(context, LiveWorkoutStore.read(context), Bundle().apply {
                        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 360)
                        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
                    }))
            }
            return try {
                manager.requestPinAppWidget(
                    ComponentName(context, LiveWorkoutWidgetProvider::class.java), extras, null,
                )
            } catch (_: IllegalStateException) {
                false
            } catch (_: SecurityException) {
                false
            }
        }

        private fun views(context: Context, snapshot: LiveWorkoutSnapshot?, options: Bundle): RemoteViews {
            // A short, wide widget still needs the compact layout to keep its clock legible.
            val expanded = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= 320 &&
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) >= 180
            return RemoteViews(context.packageName, if (expanded)
                R.layout.live_workout_widget_expanded else R.layout.live_workout_widget).apply {
                val active = snapshot?.active == true
                setTextViewText(R.id.widget_status, context.getString(when {
                    active -> R.string.live_workout_widget_live
                    snapshot != null -> R.string.live_workout_widget_draft
                    else -> R.string.live_workout_widget_ready
                }))
                setTextViewText(R.id.widget_workout, snapshot?.workoutName
                    ?: context.getString(R.string.app_name))
                setTextViewText(R.id.widget_headline, context.getString(if (snapshot == null)
                    R.string.live_workout_widget_idle else R.string.live_workout_widget_unfinished))
                setViewVisibility(R.id.widget_headline, if (active) View.GONE else View.VISIBLE)
                setTextViewText(R.id.widget_exercise, when {
                    snapshot == null -> context.getString(R.string.live_workout_widget_idle_detail)
                    else -> snapshot.exerciseName ?: context.getString(R.string.live_workout_no_exercise)
                })
                setTextColor(R.id.widget_exercise, if (snapshot == null)
                    Color.rgb(168, 172, 160) else Color.rgb(245, 245, 239))
                setContentDescription(R.id.widget_exercise, snapshot?.exerciseName
                    ?: context.getString(if (snapshot == null) R.string.live_workout_widget_idle_detail
                        else R.string.live_workout_no_exercise))
                val progress = snapshot?.let { context.getString(R.string.live_workout_widget_sets,
                    it.completedSets, it.totalSets) }.orEmpty()
                setTextViewText(R.id.widget_progress, progress)
                setViewVisibility(R.id.widget_progress, if (snapshot == null) View.INVISIBLE else View.VISIBLE)
                setViewVisibility(R.id.widget_progress_bar, if (snapshot == null) View.GONE else View.VISIBLE)
                val total = snapshot?.totalSets?.coerceAtLeast(0) ?: 0
                setProgressBar(R.id.widget_progress_bar, total.coerceAtLeast(1),
                    (snapshot?.completedSets ?: 0).coerceIn(0, total), false)
                setContentDescription(R.id.widget_progress_bar, progress)
                setTextViewText(R.id.widget_cta, context.getString(if (snapshot == null)
                    R.string.live_workout_widget_open else R.string.live_workout_widget_resume))
                setViewVisibility(R.id.widget_clock, if (active) View.VISIBLE else View.GONE)
                val elapsedMs = snapshot?.let {
                    (System.currentTimeMillis() - it.startedAtMs).coerceAtLeast(0)
                } ?: 0
                setChronometer(R.id.widget_timer, SystemClock.elapsedRealtime() - elapsedMs, null, active)
                val openIntent = LiveWorkoutSurfaces.openIntent(
                    context, resumeWorkout = snapshot != null,
                    requestCode = LiveWorkoutSurfaces.WIDGET_TAP,
                )
                setOnClickPendingIntent(R.id.widget_root, openIntent)
                setOnClickPendingIntent(R.id.widget_cta, openIntent)
                setContentDescription(R.id.widget_root, context.getString(
                    if (snapshot == null) R.string.live_workout_widget_idle_accessibility
                    else R.string.live_workout_widget_resume_accessibility,
                    snapshot?.workoutName.orEmpty(),
                ))
            }
        }
    }
}
