package com.savagecarol.dumbbell

import android.content.Context
import org.json.JSONObject

/** A display-only copy. Flutter's repository remains the owner of the actual draft. */
internal data class LiveWorkoutSnapshot(
    val active: Boolean,
    val workoutId: String,
    val workoutName: String,
    val startedAtMs: Long,
    val exerciseName: String?,
    val completedSets: Int,
    val totalSets: Int,
    val exerciseAsset: String? = null,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("active", active)
        put("workoutId", workoutId)
        put("workoutName", workoutName)
        put("startedAtMs", startedAtMs)
        put("exerciseName", exerciseName ?: JSONObject.NULL)
        put("exerciseAsset", exerciseAsset ?: JSONObject.NULL)
        put("completedSets", completedSets)
        put("totalSets", totalSets)
    }

    companion object {
        fun fromArguments(arguments: Map<*, *>): LiveWorkoutSnapshot? {
            val active = arguments["active"] as? Boolean
                ?: throw IllegalArgumentException("active must be a boolean.")
            val id = (arguments["workoutId"] as? String)?.trim().orEmpty()
            if (!active && id.isEmpty()) return null
            require(id.isNotEmpty() && id.length <= 160) { "A valid workoutId is required." }
            val startedAtMs = integer(arguments["startedAtMs"], "startedAtMs")
            require(startedAtMs > 0) {
                "startedAtMs must be a valid workout start time."
            }
            val completed = integer(arguments["completedSets"], "completedSets")
            val total = integer(arguments["totalSets"], "totalSets")
            require(total in 0L..10_000L && completed in 0L..total) { "Invalid set counts." }
            return LiveWorkoutSnapshot(
                active = active,
                workoutId = id,
                workoutName = text(arguments["workoutName"], 100) ?: "Workout",
                startedAtMs = startedAtMs,
                exerciseName = text(arguments["exerciseName"], 120),
                completedSets = completed.toInt(),
                totalSets = total.toInt(),
                exerciseAsset = validExerciseAsset(arguments["exerciseAsset"]),
            )
        }

        fun fromJson(json: JSONObject): LiveWorkoutSnapshot? = fromArguments(
            mapOf(
                "active" to json.getBoolean("active"),
                "workoutId" to json.getString("workoutId"),
                "workoutName" to json.optString("workoutName"),
                "startedAtMs" to json.getLong("startedAtMs"),
                "exerciseName" to if (json.isNull("exerciseName")) null
                    else json.optString("exerciseName"),
                "exerciseAsset" to if (json.isNull("exerciseAsset")) null
                    else json.optString("exerciseAsset"),
                "completedSets" to json.getLong("completedSets"),
                "totalSets" to json.getLong("totalSets"),
            ),
        )

        // An APK asset key, never a filesystem path or network URL. Missing keys
        // in drafts written by earlier app versions intentionally become null.
        internal fun validExerciseAsset(value: Any?): String? = (value as? String)
            ?.takeIf { EXERCISE_ASSET.matches(it) }

        private val EXERCISE_ASSET = Regex(
            "assets/exercises/repdb/flat/[a-zA-Z0-9][a-zA-Z0-9_-]{0,159}\\.webp",
        )

        private fun integer(value: Any?, name: String): Long {
            require(value is Int || value is Long) { "$name must be an integer." }
            return (value as Number).toLong()
        }

        private fun text(value: Any?, limit: Int): String? = (value as? String)
            ?.replace(Regex("[\\p{Cntrl}]"), " ")
            ?.trim()
            ?.take(limit)
            ?.takeIf { it.isNotEmpty() }
    }
}

/** The whole snapshot is written as one private preference value, never field by field. */
internal object LiveWorkoutStore {
    private const val PREFERENCES = "liftlog_live_workout"
    private const val STATE = "snapshot"

    fun read(context: Context): LiveWorkoutSnapshot? {
        val stored = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(STATE, null) ?: return null
        return try {
            val json = JSONObject(stored)
            json.optJSONObject("workout")?.let(LiveWorkoutSnapshot::fromJson)
        } catch (_: Exception) {
            null
        }
    }

    @Synchronized
    fun update(context: Context, next: LiveWorkoutSnapshot?): LiveWorkoutSnapshot? {
        // Dart serializes publishes; each validated payload is the authoritative draft.
        write(context, next)
        return next
    }

    @Synchronized
    fun markInactive(context: Context): LiveWorkoutSnapshot? {
        val inactive = read(context)?.copy(active = false)
        write(context, inactive)
        return inactive
    }

    private fun write(context: Context, snapshot: LiveWorkoutSnapshot?) {
        val json = JSONObject().apply {
            put("workout", snapshot?.toJson() ?: JSONObject.NULL)
        }
        // Small synchronous writes also survive immediately closing the activity.
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().putString(STATE, json.toString()).commit()
    }
}
