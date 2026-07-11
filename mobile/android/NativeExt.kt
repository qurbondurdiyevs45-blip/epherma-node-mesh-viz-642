package com.epherma.meshviz

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import android.util.Log

class NativeExt : Service() {

    companion object {
        private const val CHANNEL_ID = "EphermaNode_Mesh_Viz_Service"
        private const val NOTIFICATION_ID = 8881
        private const val TAG = "EphermaNativeExt"
        
        fun startService(context: Context) {
            val intent = Intent(context, NativeExt::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, NativeExt::class.java)
            context.stopService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
        Log.d(TAG, "EphermaNode Mesh Viz background persistence service initialized.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("EphermaNode Mesh active")
            .setContentText("Monitoring transient microservice failures in background...")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        // Perform background telemetry synchronization logic here
        // This ensures the hardware-accelerated WebGL frontend has hot data when resumed
        
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "EphermaNode Mesh Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the observability heat-map updated via native background sync."
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "EphermaNode::PersistenceWakeLock"
        ).apply {
            acquire(24 * 60 * 60 * 1000L) // Limit to 24 hours per session as per viz specs
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        Log.d(TAG, "EphermaNode Mesh Viz background service terminated.")
    }
}