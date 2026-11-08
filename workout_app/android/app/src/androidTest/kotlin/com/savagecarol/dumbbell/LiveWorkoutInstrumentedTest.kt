package com.savagecarol.dumbbell

import android.Manifest
import android.app.Notification
import android.app.PendingIntent
import android.app.NotificationManager
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.Chronometer
import android.view.ViewGroup
import android.view.ContextThemeWrapper
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 29)
class LiveWorkoutInstrumentedTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private var saved: String? = null
    private var host: AppWidgetHost? = null
    private var widgetId = -1

    @Before fun setUp() {
        saved = context.getSharedPreferences("liftlog_live_workout", Context.MODE_PRIVATE).getString("snapshot", null)
        if (Build.VERSION.SDK_INT >= 33) {
            instrumentation.uiAutomation.grantRuntimePermission(context.packageName, Manifest.permission.POST_NOTIFICATIONS)
        }
        instrumentation.uiAutomation.adoptShellPermissionIdentity("android.permission.BIND_APPWIDGET")
        LiveWorkoutSurfaces.createNotificationChannel(context)
    }

    @After fun tearDown() {
        if (widgetId >= 0) host?.deleteAppWidgetId(widgetId)
        host?.stopListening()
        host?.deleteHost()
        instrumentation.uiAutomation.dropShellPermissionIdentity()
        context.getSharedPreferences("liftlog_live_workout", Context.MODE_PRIVATE).edit().apply {
            if (saved == null) remove("snapshot") else putString("snapshot", saved)
        }.commit()
        LiveWorkoutSurfaces.update(context, LiveWorkoutStore.read(context))
    }

    private fun workout(id: String = "native-smoke", started: Long = System.currentTimeMillis() - 245_000) =
        LiveWorkoutSnapshot.fromArguments(mapOf(
            "active" to true, "workoutId" to id, "workoutName" to "Strength session",
            "startedAtMs" to started, "exerciseName" to "Barbell Bench Press",
            "exerciseAsset" to "assets/exercises/repdb/flat/bench-press-start.webp",
            "completedSets" to 2, "totalSets" to 5,
        ))!!

    @Test fun notificationUsesSavedClockAndClearsWithoutDestroyingDraft() {
        val draft = workout(started = System.currentTimeMillis() - 3_725_000)
        assertTrue(LiveWorkoutSurfaces.notificationsEnabled(context))
        LiveWorkoutSurfaces.update(context, LiveWorkoutStore.update(context, draft))
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Posting replaces the existing live notification asynchronously. Wait for this
        // snapshot, rather than accepting a notification left by the user's session.
        waitUntil { manager.activeNotifications.any {
            it.id == 4380 && it.notification.`when` == draft.startedAtMs
        } }
        val notification = manager.activeNotifications.single { it.id == 4380 }.notification
        assertEquals(draft.startedAtMs, notification.`when`)
        assertNotNull("The compact notification needs a dedicated timer and exercise layout", notification.contentView)
        assertNotNull("Expanding the notification should reveal the full workout summary", notification.bigContentView)
        assertFalse("The timer belongs in the content, without a duplicate clock in the header",
            notification.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(notification.publicVersion.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(notification.extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("Barbell Bench Press"))
        assertNotNull(notification.contentIntent)
        assertEquals("Resume workout", notification.actions.single().title.toString())
        assertEquals(notification.contentIntent, notification.actions.single().actionIntent)
        assertEquals(Notification.VISIBILITY_PRIVATE, notification.visibility)
        assertFalse(notification.publicVersion.extras.toString().contains(draft.exerciseName!!))
        assertFalse(notification.publicVersion.extras.toString().contains(draft.workoutName))
        // Capture SystemUI with display-only fixture data; the durable Flutter records are untouched.
        shell("cmd statusbar expand-notifications")
        try {
            Thread.sleep(2500)
            instrumentation.uiAutomation.takeScreenshot()?.let { bitmap ->
                File(context.cacheDir, "live-workout-notification-shade.png").outputStream().use {
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                }
                bitmap.recycle()
            }
        } finally {
            shell("cmd statusbar collapse")
        }
        LiveWorkoutSurfaces.update(context, LiveWorkoutStore.markInactive(context))
        waitUntil { manager.activeNotifications.none { it.id == 4380 } }
        assertFalse(manager.activeNotifications.any { it.id == 4380 })
        assertEquals(draft.workoutId, LiveWorkoutStore.read(context)!!.workoutId)
        assertFalse(LiveWorkoutStore.read(context)!!.active)
    }

    @Test fun notificationLayoutsFitNarrowScreensAndRespectThemeAndSavedClock() {
        val draft = workout(started = System.currentTimeMillis() - 3_725_000)
        instrumentation.runOnMainSync {
            for (dark in listOf(false, true)) {
                val theme = if (dark) "dark" else "light"
                for (expanded in listOf(false, true)) {
                    val suffix = if (expanded) "expanded" else "compact"
                    renderNotification(draft, expanded, dark, 1f, 310,
                        "-$suffix-$theme")
                    val long = draft.copy(workoutName = "A long strength and conditioning workout name",
                        exerciseName = "Single Arm Dumbbell Bent Over Reverse Fly With Bench Support")
                    renderNotification(long, expanded, dark, 1.3f, 260,
                        "-$suffix-$theme-large-text")
                }
            }
            val empty = draft.copy(exerciseName = null, totalSets = 0, completedSets = 0,
                startedAtMs = System.currentTimeMillis() + 3_600_000)
            val view = renderNotification(empty, true, false, 1f, 310, "-empty")
            assertEquals(context.getString(R.string.live_workout_no_exercise),
                view.findViewById<TextView>(R.id.notification_exercise).text.toString())
            val progress = view.findViewById<ProgressBar>(R.id.notification_progress_bar)
            assertEquals(1, progress.max)
            assertEquals(0, progress.progress)
            assertTrue("A clock rollback must not create a negative timer",
                kotlin.math.abs(SystemClock.elapsedRealtime() -
                    view.findViewById<Chronometer>(R.id.notification_timer).base) < 1000)
        }
    }

    private fun renderNotification(snapshot: LiveWorkoutSnapshot, expanded: Boolean, dark: Boolean,
        fontScale: Float, widthDp: Int, suffix: String): ViewGroup {
        val config = Configuration(context.resources.configuration).apply {
            this.fontScale = fontScale
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                if (dark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
        }
        val themed = ContextThemeWrapper(context.createConfigurationContext(config),
            if (dark) android.R.style.Theme_DeviceDefault else android.R.style.Theme_DeviceDefault_Light)
        val view = LiveWorkoutNotification.views(themed, snapshot, expanded)
            .apply(themed, FrameLayout(themed)) as ViewGroup
        val density = themed.resources.displayMetrics.density
        val width = (widthDp * density).toInt()
        val maxHeight = ((if (expanded) 252 else 48) * density).toInt()
        view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(maxHeight, View.MeasureSpec.AT_MOST))
        view.layout(0, 0, width, view.measuredHeight)
        val timer = view.findViewById<Chronometer>(R.id.notification_timer)
        val elapsed = (System.currentTimeMillis() - snapshot.startedAtMs).coerceAtLeast(0)
        assertTrue(kotlin.math.abs((SystemClock.elapsedRealtime() - timer.base) - elapsed) < 1000)
        assertTrue("The whole elapsed time must fit", timer.paint.measureText("1:02:05") <= timer.width)
        assertEquals(snapshot.exerciseName ?: context.getString(R.string.live_workout_no_exercise),
            view.findViewById<TextView>(R.id.notification_exercise).text.toString())
        for (id in listOf(R.id.notification_timer, R.id.notification_exercise, R.id.notification_progress)
            + if (expanded) listOf(R.id.notification_workout) else emptyList()) {
            assertTextVisible(view, view.findViewById(id))
        }
        if (expanded) {
            val progress = view.findViewById<ProgressBar>(R.id.notification_progress_bar)
            assertEquals(snapshot.totalSets.coerceAtLeast(1), progress.max)
            assertEquals(snapshot.completedSets, progress.progress)
            assertTrue(progress.bottom <= view.height)
        }
        val pendingIntentTag = context.resources.getIdentifier("pending_intent_tag", "id", "android")
        assertEquals(LiveWorkoutSurfaces.openIntent(context, true, LiveWorkoutSurfaces.NOTIFICATION_TAP),
            view.getTag(pendingIntentTag))
        val text = view.findViewById<TextView>(R.id.notification_exercise).currentTextColor
        val brightness = Color.red(text) + Color.green(text) + Color.blue(text)
        assertTrue("Text must contrast with the notification theme", if (dark) brightness > 384 else brightness < 384)
        val bitmap = Bitmap.createBitmap(width, view.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(if (dark) Color.rgb(32, 33, 29) else Color.rgb(248, 250, 244))
        view.draw(canvas)
        File(context.cacheDir, "live-workout-notification$suffix.png").outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
        bitmap.recycle()
        return view
    }

    private fun shell(command: String) {
        instrumentation.uiAutomation.executeShellCommand(command).use { descriptor ->
            java.io.FileInputStream(descriptor.fileDescriptor).use { it.readBytes() }
        }
    }

    @Test fun restoringAnOlderOrPreviouslyClearedDraftIsAuthoritative() {
        val original = workout()
        LiveWorkoutStore.update(context, original)
        LiveWorkoutStore.update(context, null)
        assertEquals(original, LiveWorkoutStore.update(context, original))
        val older = workout("restored-draft", original.startedAtMs - 3600_000)
        assertEquals(older, LiveWorkoutStore.update(context, older))
        assertEquals(older, LiveWorkoutStore.read(context))
        val afterClockRollback = workout("clock-rollback", System.currentTimeMillis() + 3_600_000)
        LiveWorkoutStore.update(context, afterClockRollback)
        assertEquals(afterClockRollback, LiveWorkoutStore.read(context))
    }

    @Test fun widgetRendersTimerExerciseAndUnfinishedStateInAnActualHost() {
        val draft = workout(started = System.currentTimeMillis() - 3_725_000)
        LiveWorkoutStore.update(context, draft)
        val manager = AppWidgetManager.getInstance(context)
        val widgetHost = AppWidgetHost(context, 4385).also { host = it }
        widgetHost.startListening()
        widgetId = widgetHost.allocateAppWidgetId()
        assertTrue(manager.bindAppWidgetIdIfAllowed(widgetId,
            ComponentName(context, LiveWorkoutWidgetProvider::class.java), widgetSize(250, 140)))
        lateinit var view: AppWidgetHostView
        instrumentation.runOnMainSync {
            view = widgetHost.createView(context, widgetId, manager.getAppWidgetInfo(widgetId))
        }
        LiveWorkoutSurfaces.update(context, draft)
        waitUntil {
            view.findViewById<TextView>(R.id.widget_exercise)?.text?.toString() == draft.exerciseName
        }
        var compactTimerSize = 0f
        instrumentation.runOnMainSync {
            val timer = view.findViewById<Chronometer>(R.id.widget_timer)
            compactTimerSize = timer.textSize
            assertTrue(kotlin.math.abs((SystemClock.elapsedRealtime() - timer.base) - 3_725_000) < 5000)
            assertEquals(View.VISIBLE, view.findViewById<View>(R.id.widget_clock).visibility)
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_headline).visibility)
            assertProgress(view, 2, 5)
            assertWidgetActions(view, resume = true)
            captureWidget(view, 250, 140, "-compact")
            assertTimerFits(view, "1:02:05")
        }

        // Resize the already bound instance rather than directly inflating a chosen layout.
        manager.updateAppWidgetOptions(widgetId, widgetSize(360, 180))
        waitUntil { (view.findViewById<Chronometer>(R.id.widget_timer)?.textSize ?: 0f) > compactTimerSize }
        instrumentation.runOnMainSync {
            assertProgress(view, 2, 5)
            captureWidget(view, 360, 180, "")
            assertTimerFits(view, "1:02:05")
        }

        // A second instance retains its own size after updateAll refreshes both widgets.
        val compactId = widgetHost.allocateAppWidgetId()
        assertTrue(manager.bindAppWidgetIdIfAllowed(compactId,
            ComponentName(context, LiveWorkoutWidgetProvider::class.java), widgetSize(250, 140)))
        lateinit var compactView: AppWidgetHostView
        instrumentation.runOnMainSync {
            compactView = widgetHost.createView(context, compactId, manager.getAppWidgetInfo(compactId))
        }
        LiveWorkoutSurfaces.update(context, draft)
        waitUntil { compactView.findViewById<TextView>(R.id.widget_exercise)?.text?.toString() == draft.exerciseName }
        instrumentation.runOnMainSync {
            assertEquals(compactTimerSize, compactView.findViewById<Chronometer>(R.id.widget_timer).textSize, 0f)
            assertTrue(view.findViewById<Chronometer>(R.id.widget_timer).textSize > compactTimerSize)
        }

        val longName = "Single Arm Dumbbell Overhead Triceps Extension"
        val longDraft = draft.copy(exerciseName = longName,
            startedAtMs = System.currentTimeMillis() - 36_725_000,
            exerciseAsset = "assets/exercises/repdb/flat/not-a-real-exercise.webp")
        LiveWorkoutSurfaces.update(context, LiveWorkoutStore.update(context, longDraft))
        waitUntil { view.findViewById<TextView>(R.id.widget_exercise)?.text?.toString() == longName &&
            compactView.findViewById<TextView>(R.id.widget_exercise)?.text?.toString() == longName }
        instrumentation.runOnMainSync {
            captureWidget(view, 360, 180, "-long")
            assertTimerFits(view, "10:12:05")
            assertEquals(longName, view.findViewById<TextView>(R.id.widget_exercise).contentDescription)
            captureWidget(compactView, 250, 140, "-compact-long")
            assertTimerFits(compactView, "10:12:05")
        }

        // Empty and completed sessions use a finite, determinate native progress bar.
        for ((completed, total) in listOf(0 to 0, 0 to 5, 5 to 5)) {
            LiveWorkoutSurfaces.update(context, LiveWorkoutStore.update(context,
                draft.copy(completedSets = completed, totalSets = total)))
            waitUntil { view.findViewById<TextView>(R.id.widget_progress)?.text?.toString() ==
                context.getString(R.string.live_workout_widget_sets, completed, total) }
            instrumentation.runOnMainSync { assertProgress(view, completed, total) }
        }

        LiveWorkoutSurfaces.update(context, LiveWorkoutStore.markInactive(context))
        waitUntil { view.findViewById<TextView>(R.id.widget_status)?.text?.toString() == context.getString(R.string.live_workout_widget_draft) &&
            compactView.findViewById<TextView>(R.id.widget_status)?.text?.toString() == context.getString(R.string.live_workout_widget_draft) }
        instrumentation.runOnMainSync {
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_clock).visibility)
            assertEquals(context.getString(R.string.live_workout_widget_unfinished),
                view.findViewById<TextView>(R.id.widget_headline).text.toString())
            assertEquals(draft.exerciseName, view.findViewById<TextView>(R.id.widget_exercise).text.toString())
            assertWidgetActions(view, resume = true)
            captureWidget(view, 360, 180, "-unfinished")
            captureWidget(compactView, 250, 140, "-compact-unfinished")
        }
        LiveWorkoutSurfaces.update(context, LiveWorkoutStore.update(context, null))
        waitUntil { view.findViewById<TextView>(R.id.widget_status)?.text?.toString() == context.getString(R.string.live_workout_widget_ready) &&
            compactView.findViewById<TextView>(R.id.widget_status)?.text?.toString() == context.getString(R.string.live_workout_widget_ready) }
        instrumentation.runOnMainSync {
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_clock).visibility)
            assertEquals(View.GONE, view.findViewById<View>(R.id.widget_progress_bar).visibility)
            assertEquals(context.getString(R.string.live_workout_widget_idle),
                view.findViewById<TextView>(R.id.widget_headline).text.toString())
            assertEquals(context.getString(R.string.live_workout_widget_open),
                view.findViewById<TextView>(R.id.widget_cta).text.toString())
            assertWidgetActions(view, resume = false)
            captureWidget(view, 360, 180, "-idle")
            captureWidget(compactView, 250, 140, "-compact-idle")
        }

        // An app update refreshes existing host IDs from the saved draft in place.
        LiveWorkoutStore.update(context, draft.copy(active = false))
        LiveWorkoutWidgetProvider().onReceive(context, Intent(Intent.ACTION_MY_PACKAGE_REPLACED))
        waitUntil { view.findViewById<TextView>(R.id.widget_status)?.text?.toString() == context.getString(R.string.live_workout_widget_draft) }
        instrumentation.runOnMainSync {
            assertEquals(draft.workoutName, view.findViewById<TextView>(R.id.widget_workout).text.toString())
            assertWidgetActions(view, resume = true)
        }
    }

    @Test fun widgetExerciseAssetsAreOptionalAndRestrictedToBundledRepDbImages() {
        val draft = workout()
        assertEquals(draft, LiveWorkoutSnapshot.fromJson(draft.toJson()))
        val legacy = draft.toJson().apply { remove("exerciseAsset") }
        assertNull(LiveWorkoutSnapshot.fromJson(legacy)!!.exerciseAsset)
        assertNull(LiveWorkoutSnapshot.fromJson(draft.toJson().put("exerciseAsset", org.json.JSONObject.NULL))!!.exerciseAsset)
        for (asset in listOf(
            "https://example.com/exercise.webp", "/data/local/tmp/exercise.webp",
            "assets/exercises/repdb/flat/../exercise.webp",
            "assets/exercises/repdb/flat/nested/exercise.webp",
            "assets/exercises/repdb/flat/bench-press-start.webp?other=true",
        )) {
            assertNull(asset, LiveWorkoutSnapshot.fromJson(draft.toJson().put("exerciseAsset", asset))!!.exerciseAsset)
        }
    }

    private fun widgetSize(width: Int, height: Int) = Bundle().apply {
        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, width)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, height)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, width)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, height)
    }

    private fun assertProgress(view: AppWidgetHostView, completed: Int, total: Int) {
        val progress = view.findViewById<ProgressBar>(R.id.widget_progress_bar)
        assertEquals(View.VISIBLE, progress.visibility)
        assertFalse(progress.isIndeterminate)
        assertEquals(total.coerceAtLeast(1), progress.max)
        assertEquals(completed, progress.progress)
        assertEquals(context.getString(R.string.live_workout_widget_sets, completed, total),
            view.findViewById<TextView>(R.id.widget_progress).text.toString())
    }

    private fun assertWidgetActions(view: AppWidgetHostView, resume: Boolean) {
        // RemoteViews records each assigned PendingIntent on its target view. Reading that
        // framework tag checks the installed host wiring without launching or altering a draft.
        val pendingIntentTag = context.resources.getIdentifier("pending_intent_tag", "id", "android")
        assertNotEquals(0, pendingIntentTag)
        val expected = PendingIntent.getActivity(context, LiveWorkoutSurfaces.WIDGET_TAP,
            Intent(context, MainActivity::class.java).apply {
                action = if (resume) LiveWorkoutSurfaces.ACTION_OPEN_WORKOUT
                    else "com.savagecarol.dumbbell.OPEN_APP"
            }, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        assertNotNull(expected)
        for (id in listOf(R.id.widget_root, R.id.widget_cta)) {
            val target = view.findViewById<View>(id)
            assertTrue(target.hasOnClickListeners())
            assertEquals(expected, target.getTag(pendingIntentTag))
        }
    }

    private fun assertTimerFits(view: AppWidgetHostView, example: String) {
        val timer = view.findViewById<Chronometer>(R.id.widget_timer)
        assertTextVisible(view, timer)
        assertTrue("The complete elapsed time must fit on one line",
            timer.paint.measureText(example) <= timer.width - timer.compoundPaddingLeft - timer.compoundPaddingRight)
        assertEquals(1, timer.lineCount)
    }

    private fun assertTextVisible(hostView: ViewGroup, text: TextView) {
        assertTrue(text.width > 0 && text.height > 0)
        assertNotNull(text.layout)
        assertTrue("Text must not be cropped vertically",
            text.layout.height <= text.height - text.compoundPaddingTop - text.compoundPaddingBottom)
        var parent = text.parent
        while (parent is ViewGroup && parent !== hostView) {
            val bounds = Rect()
            text.getDrawingRect(bounds)
            parent.offsetDescendantRectToMyCoords(text, bounds)
            assertTrue("Text must remain inside its widget containers", bounds.left >= 0 &&
                bounds.top >= 0 && bounds.right <= parent.width && bounds.bottom <= parent.height)
            parent = parent.parent
        }
    }

    private fun captureWidget(view: AppWidgetHostView, widthDp: Int, heightDp: Int, suffix: String) {
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).toInt()
        val height = (heightDp * density).toInt()
        view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, width, height)
        for (id in listOf(R.id.widget_workout, R.id.widget_status, R.id.widget_exercise,
            R.id.widget_cta, R.id.widget_headline, R.id.widget_progress)) {
            val text = view.findViewById<TextView>(id)
            if (text.visibility == View.VISIBLE) assertTextVisible(view, text)
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        File(context.cacheDir, "live-workout-widget$suffix.png").outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
        bitmap.recycle()
    }

    private fun waitUntil(check: () -> Boolean) {
        repeat(50) {
            var passed = false
            instrumentation.runOnMainSync { passed = check() }
            if (passed) return
            Thread.sleep(100)
        }
        fail("Native widget host did not receive its updated view")
    }
}
