package com.evora.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val PERMISSIONS_CHANNEL = "com.evora.app/permissions"
        private const val REQ_CAMERA = 3101
        private const val REQ_GALLERY = 3102
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingRequestCode: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestCameraPermission" -> handleCameraPermission(result)
                    "requestGalleryPermission" -> handleGalleryPermission(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleCameraPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        startPermissionRequest(REQ_CAMERA, arrayOf(Manifest.permission.CAMERA), result)
    }

    private fun handleGalleryPermission(result: MethodChannel.Result) {
        if (hasGalleryPermission()) {
            result.success(true)
            return
        }
        val permissionsToRequest = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
            )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES
            )
            else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        startPermissionRequest(REQ_GALLERY, permissionsToRequest, result)
    }

    private fun hasGalleryPermission(): Boolean {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) ==
                    PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
                    ) == PackageManager.PERMISSION_GRANTED
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) ==
                    PackageManager.PERMISSION_GRANTED
            }
            else -> {
                ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) ==
                    PackageManager.PERMISSION_GRANTED
            }
        }
    }

    private fun startPermissionRequest(
        requestCode: Int,
        permissions: Array<String>,
        result: MethodChannel.Result
    ) {
        if (pendingResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "Another permission request is active.", null)
            return
        }
        pendingResult = result
        pendingRequestCode = requestCode
        ActivityCompat.requestPermissions(this, permissions, requestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == pendingRequestCode && pendingResult != null) {
            val granted = if (requestCode == REQ_GALLERY) {
                hasGalleryPermission() || grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            } else {
                grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            }
            val callback = pendingResult
            pendingResult = null
            pendingRequestCode = null
            callback?.success(granted)
        }
    }
}
