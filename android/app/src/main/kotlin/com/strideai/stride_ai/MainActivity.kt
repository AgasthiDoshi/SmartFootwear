package com.strideai.stride_ai

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.strideai.stride_ai/telephony"
    private val PERMISSION_REQUEST_CODE = 991

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> {
                    val permissions = mutableListOf<String>()
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                        permissions.add(Manifest.permission.SEND_SMS)
                    }
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
                        permissions.add(Manifest.permission.CALL_PHONE)
                    }
                    if (permissions.isNotEmpty()) {
                        ActivityCompat.requestPermissions(this, permissions.toTypedArray(), PERMISSION_REQUEST_CODE)
                    }
                    result.success(true)
                }
                "sendDirectSms" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val cleanPhone = phone.replace(Regex("[^0-9+]"), "")

                    if (cleanPhone.isEmpty() || message.isEmpty()) {
                        result.error("INVALID_ARGS", "Phone and message must not be empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            context.getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }
                        val parts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(cleanPhone, null, parts, null, null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", e.localizedMessage, null)
                    }
                }
                "makeDirectCall" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val cleanPhone = phone.replace(Regex("[^0-9+]"), "")

                    if (cleanPhone.isEmpty()) {
                        result.error("INVALID_ARGS", "Phone must not be empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                            val intent = Intent(Intent.ACTION_CALL).apply {
                                data = Uri.parse("tel:$cleanPhone")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(intent)
                        } else {
                            val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                                data = Uri.parse("tel:$cleanPhone")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(dialIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                                data = Uri.parse("tel:$cleanPhone")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(dialIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("CALL_FAILED", e2.localizedMessage, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
