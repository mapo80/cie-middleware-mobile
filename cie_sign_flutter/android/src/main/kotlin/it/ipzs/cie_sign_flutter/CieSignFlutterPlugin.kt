package it.ipzs.cie_sign_flutter

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import it.ipzs.ciesign.sdk.CieSignSdk
import it.ipzs.ciesign.sdk.PdfAppearanceOptions
import java.io.File
import java.util.HashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference

private const val TAG = "CieSignFlutterPlugin"

class CieSignFlutterPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    NfcAdapter.ReaderCallback,
    EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private val sdk = CieSignSdk()
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null
    private val pending = AtomicReference<PendingRequest?>()
    private val eventSink = AtomicReference<EventChannel.EventSink?>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "cie_sign_flutter")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "cie_sign_flutter/nfc_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "mockSignPdf" -> handleMockSign(call, result)
            "signPdfWithNfc" -> handleSignWithNfc(call, result)
            "verifyPinWithNfc" -> handleVerifyPin(call, result)
            "cancelNfcSigning" -> handleCancel(result)
            else -> result.notImplemented()
        }
    }

    private fun handleMockSign(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments
        if (args !is Map<*, *>) {
            result.error("invalid_args", "Expected map arguments", null)
            return
        }
        val pdf = args["pdf"]
        if (pdf !is ByteArray || pdf.isEmpty()) {
            result.error("invalid_pdf", "Argument 'pdf' must be a non-empty Uint8List", null)
            return
        }
        val outputPath = (args["outputPath"] as? String)?.takeIf { it.isNotBlank() }
        val appearance = parseAppearance(args["appearance"] as? Map<*, *>)
        try {
            val signedPdf = sdk.mockSignPdf(
                pdf,
                outputPath?.let(::File),
                appearance,
            )
            result.success(signedPdf)
        } catch (ex: Exception) {
            result.error("mock_sign_failed", ex.message, null)
        }
    }

    private fun handleSignWithNfc(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments
        if (args !is Map<*, *>) {
            result.error("invalid_args", "Expected map arguments", null)
            return
        }
        val activity = activity ?: run {
            result.error("no_activity", "Plugin is not attached to an Activity", null)
            return
        }
        val adapter = nfcAdapter ?: run {
            emitError("nfc_unavailable", "NFC adapter not available")
            result.error("nfc_unavailable", "NFC adapter not available", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            emitError("nfc_unsupported", "Reader mode requires API 19 or later")
            result.error("nfc_unsupported", "Reader mode requires API 19 or later", null)
            return
        }
        if (!adapter.isEnabled) {
            emitNfcState()
            result.error("nfc_disabled", "NFC adapter is disabled", null)
            return
        }
        if (pending.get() != null) {
            emitError("busy", "A signing request is already running")
            result.error("busy", "A signing request is already running", null)
            return
        }
        val pdf = args["pdf"]
        if (pdf !is ByteArray || pdf.isEmpty()) {
            result.error("invalid_pdf", "Argument 'pdf' must be a non-empty Uint8List", null)
            return
        }
        val pin = (args["pin"] as? String)?.takeIf { it.isNotBlank() } ?: run {
            result.error("invalid_pin", "PIN cannot be empty", null)
            return
        }
        val appearanceMap = args["appearance"] as? Map<*, *>
        val appearance = parseAppearance(appearanceMap) ?: run {
            result.error("invalid_appearance", "Appearance map is required", null)
            return
        }
        val outputPath = (args["outputPath"] as? String)?.takeIf { it.isNotBlank() }

        val pendingRequest = PendingRequest(
            operation = Operation.SIGN,
            pdf = pdf,
            pin = pin,
            appearance = appearance,
            outputPath = outputPath,
            result = result
        )
        pending.set(pendingRequest)
        emitEvent("listening", emptyMap())
        adapter.enableReaderMode(
            activity,
            this,
            NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            null
        )
    }

    private fun handleVerifyPin(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments
        if (args !is Map<*, *>) {
            result.error("invalid_args", "Expected map arguments", null)
            return
        }
        val activity = activity ?: run {
            result.error("no_activity", "Plugin is not attached to an Activity", null)
            return
        }
        val adapter = nfcAdapter ?: run {
            emitError("nfc_unavailable", "NFC adapter not available")
            result.error("nfc_unavailable", "NFC adapter not available", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            emitError("nfc_unsupported", "Reader mode requires API 19 or later")
            result.error("nfc_unsupported", "Reader mode requires API 19 or later", null)
            return
        }
        if (!adapter.isEnabled) {
            emitNfcState()
            result.error("nfc_disabled", "NFC adapter is disabled", null)
            return
        }
        if (pending.get() != null) {
            emitError("busy", "A signing request is already running")
            result.error("busy", "A signing request is already running", null)
            return
        }
        val pin = (args["pin"] as? String)?.takeIf { it.isNotBlank() } ?: run {
            result.error("invalid_pin", "PIN cannot be empty", null)
            return
        }
        val pendingRequest = PendingRequest(
            operation = Operation.VERIFY,
            pdf = null,
            pin = pin,
            appearance = null,
            outputPath = null,
            result = result
        )
        pending.set(pendingRequest)
        emitEvent("listening", emptyMap())
        adapter.enableReaderMode(
            activity,
            this,
            NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            null
        )
    }

    private fun handleCancel(result: MethodChannel.Result) {
        val current = pending.getAndSet(null)
        if (current == null) {
            result.success(false)
            return
        }
        disableReaderMode()
        mainHandler.post {
            current.result.error("canceled", "NFC signing cancelled", null)
        }
        emitEvent("canceled", emptyMap())
        result.success(true)
    }

    private fun currentNfcStatus(): String {
        val adapter = nfcAdapter
        return when {
            adapter == null -> "not_supported"
            !adapter.isEnabled -> "disabled"
            else -> "ready"
        }
    }

    private fun emitNfcState() {
        emitEvent("state", mapOf("status" to currentNfcStatus()))
    }

    private fun emitError(code: String, message: String) {
        emitEvent("error", mapOf("code" to code, "message" to message))
    }

    private fun emitEvent(type: String, data: Map<String, Any?>) {
        val sink = eventSink.get() ?: return
        val payload = HashMap<String, Any?>(data)
        payload["type"] = type
        mainHandler.post { sink.success(payload) }
    }

    private fun parseAppearance(map: Map<*, *>?): PdfAppearanceOptions? {
        map ?: return null
        val pageIndex = (map["pageIndex"] as? Number)?.toInt() ?: 0
        val left = (map["left"] as? Number)?.toFloat() ?: 0f
        val bottom = (map["bottom"] as? Number)?.toFloat() ?: 0f
        val width = (map["width"] as? Number)?.toFloat() ?: 0f
        val height = (map["height"] as? Number)?.toFloat() ?: 0f
        val reason = (map["reason"] as? String)?.takeIf { it.isNotBlank() }
        val location = (map["location"] as? String)?.takeIf { it.isNotBlank() }
        val name = (map["name"] as? String)?.takeIf { it.isNotBlank() }
        val fieldIds = (map["fieldIds"] as? List<*>)?.mapNotNull { (it as? String)?.takeIf { it.isNotBlank() } }
        val payload = (map["signatureImage"] as? ByteArray)?.takeIf { it.isNotEmpty() }
        Log.d(TAG, "appearance: fieldIds=${fieldIds?.joinToString()} bytes=${payload?.size ?: 0} width=0 height=0")
        return PdfAppearanceOptions(
            pageIndex,
            left,
            bottom,
            width,
            height,
            reason,
            location,
            name,
            fieldIds,
            payload,
            0,
            0
        )
    }

    override fun onTagDiscovered(tag: Tag) {
        val request = pending.get() ?: return
        val tagId = tag.id?.joinToString(separator = "") { String.format("%02X", it) }
        Log.d(TAG, "Tag discovered. id=$tagId tech=${tag.techList?.joinToString()}")
        emitEvent("tag", mapOf("tagId" to (tagId ?: "unknown")))
        val isoDep = IsoDep.get(tag)
        if (isoDep == null) {
            mainHandler.post {
                pending.set(null)
                disableReaderMode()
                request.result.error("unsupported_tag", "Detected tag does not support ISO-DEP", null)
            }
            emitError("unsupported_tag", "Detected tag does not support ISO-DEP")
            return
        }
        executor.execute {
            when (request.operation) {
                Operation.SIGN -> performSigning(request, isoDep)
                Operation.VERIFY -> performVerification(request, isoDep)
            }
        }
    }

    private fun performSigning(request: PendingRequest, isoDep: IsoDep) {
        try {
            isoDep.timeout = maxOf(isoDep.timeout, 60_000)
            Log.d(TAG, "IsoDep connected. Timeout=${isoDep.timeout}")
            val signed = sdk.signPdfWithNfc(
                request.pdf ?: ByteArray(0),
                request.pin,
                request.appearance!!,
                isoDep,
                request.outputPath?.let(::File)
            )
            mainHandler.post {
                pending.set(null)
                disableReaderMode()
                request.result.success(signed)
            }
            emitEvent("completed", mapOf("bytes" to signed.size))
        } catch (ex: Exception) {
            Log.e(TAG, "NFC signing failed", ex)
            mainHandler.post {
                pending.set(null)
                disableReaderMode()
                request.result.error("nfc_sign_failed", ex.message, null)
            }
            emitError("nfc_sign_failed", ex.message ?: "NFC signing failed")
        } finally {
            try {
                isoDep.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun performVerification(request: PendingRequest, isoDep: IsoDep) {
        try {
            isoDep.timeout = maxOf(isoDep.timeout, 60_000)
            val success = sdk.verifyPinWithNfc(request.pin, isoDep)
            mainHandler.post {
                pending.set(null)
                disableReaderMode()
                request.result.success(success)
            }
            emitEvent("completed", mapOf("verified" to success))
        } catch (ex: Exception) {
            Log.e(TAG, "NFC pin verification failed", ex)
            mainHandler.post {
                pending.set(null)
                disableReaderMode()
                request.result.error("nfc_verify_failed", ex.message, null)
            }
            emitError("nfc_verify_failed", ex.message ?: "NFC verification failed")
        } finally {
            try {
                isoDep.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun disableReaderMode() {
        val act = activity ?: return
        val adapter = nfcAdapter ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            adapter.disableReaderMode(act)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        nfcAdapter = NfcAdapter.getDefaultAdapter(binding.activity)
        emitNfcState()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        nfcAdapter = null
        emitNfcState()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        disableReaderMode()
        pending.getAndSet(null)?.let {
            mainHandler.post { it.result.error("canceled", "Activity detached", null) }
        }
        activity = null
        nfcAdapter = null
        emitNfcState()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink.set(events)
        emitNfcState()
    }

    override fun onCancel(arguments: Any?) {
        eventSink.set(null)
    }

    private enum class Operation {
        SIGN,
        VERIFY
    }

    private data class PendingRequest(
        val operation: Operation,
        val pdf: ByteArray?,
        val pin: String,
        val appearance: PdfAppearanceOptions?,
        val outputPath: String?,
        val result: MethodChannel.Result
    )

}
