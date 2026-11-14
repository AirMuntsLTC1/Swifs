package com.swifs.native

import android.app.NotificationChannel
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.os.Build
import androidx.core.app.NotificationCompat
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/// Shows Swifs phone notifications: circle avatar on the left, bold title, the message below,
/// the time at the top right, and the Swifs orange accent. Works on Android 8 and newer.
class NotificationManager(private val context: Context) {
    private val channelId = "swifs_social_notifications"
    private val brandColor = 0xFFFF6B35.toInt()
    private val groupKey = "com.swifs.notifications.activity"

    init {
        createChannel()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Swifs activity",
                android.app.NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "New messages, follows, follow requests, likes and comments"
                enableLights(true)
                lightColor = brandColor
                enableVibration(true)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    /// Crops a picture to a circle, scaled to 128 px so it stays light on memory.
    private fun circle(src: Bitmap, size: Int = 128): Bitmap {
        val scaled = Bitmap.createScaledBitmap(src, size, size, true)
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawOval(RectF(0f, 0f, size.toFloat(), size.toFloat()), paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(scaled, 0f, 0f, paint)
        return out
    }

    /// Shown when a person has no profile picture: a brand-orange circle with the Swifs "S".
    private fun placeholder(size: Int = 128): Bitmap {
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = brandColor })
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = size * 0.5f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        canvas.drawText("S", size / 2f, size / 2f - (text.descent() + text.ascent()) / 2f, text)
        return out
    }

    private fun download(url: String): Bitmap? = try {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 5000
        conn.readTimeout = 5000
        conn.inputStream.use { BitmapFactory.decodeStream(it) }
    } catch (e: Exception) {
        null
    }

    /// Shows one notification. Runs the picture download off the main thread.
    fun showNotification(id: Int, title: String, body: String, avatarUrl: String?, tag: String? = null) {
        thread {
            val picture = avatarUrl?.takeIf { it.isNotBlank() }?.let { download(it) }
            val large = picture?.let { circle(it) } ?: placeholder()

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pending = launch?.let {
                android.app.PendingIntent.getActivity(
                    context,
                    id,
                    it,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
            }

            val smallIcon = context.applicationInfo.icon
            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(if (smallIcon != 0) smallIcon else android.R.drawable.ic_dialog_info)
                .setColor(brandColor)
                .setLargeIcon(large)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setWhen(System.currentTimeMillis())
                .setShowWhen(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_SOCIAL)
                .setGroup(groupKey)
                .setAutoCancel(true)
            if (pending != null) builder.setContentIntent(pending)

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            // Same tag as the server push: Android replaces the earlier copy instead of stacking two.
            if (tag != null) manager.notify(tag, 0, builder.build()) else manager.notify(id, builder.build())
        }
    }
}


