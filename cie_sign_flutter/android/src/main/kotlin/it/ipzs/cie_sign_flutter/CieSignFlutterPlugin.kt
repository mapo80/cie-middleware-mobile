package it.ipzs.cie_sign_flutter

import android.app.Activity
import android.graphics.BitmapFactory
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import it.ipzs.ciesign.sdk.CieSignSdk
import it.ipzs.ciesign.sdk.PdfAppearanceOptions
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference

class CieSignFlutterPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    NfcAdapter.ReaderCallback {

    private lateinit var channel: MethodChannel
    private val sdk = CieSignSdk()
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null
    private val pending = AtomicReference<PendingRequest?>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "cie_sign_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "mockSignPdf" -> handleMockSign(call, result)
            "signPdfWithNfc" -> handleSignWithNfc(call, result)
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
            result.error("nfc_unavailable", "NFC adapter not available", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            result.error("nfc_unsupported", "Reader mode requires API 19 or later", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("nfc_disabled", "NFC adapter is disabled", null)
            return
        }
        if (pending.get() != null) {
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

        val pendingRequest = PendingRequest(pdf, pin, appearance, outputPath, result)
        pending.set(pendingRequest)
        adapter.enableReaderMode(
            activity,
            this,
            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
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
        result.success(true)
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
        val decoded = decodeSignatureImage(map["signatureImage"] as? ByteArray)
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
            decoded?.data,
            decoded?.width ?: 0,
            decoded?.height ?: 0
        )
    }

    private data class SignatureImage(val data: ByteArray, val width: Int, val height: Int)

    private fun decodeSignatureImage(bytes: ByteArray?): SignatureImage? {
        if (bytes == null || bytes.isEmpty()) return null
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val raw = ByteArray(width * height * 4)
        var dst = 0
        for (color in pixels) {
            raw[dst++] = ((color shr 16) and 0xFF).toByte()
            raw[dst++] = ((color shr 8) and 0xFF).toByte()
            raw[dst++] = (color and 0xFF).toByte()
            raw[dst++] = ((color shr 24) and 0xFF).toByte()
        }
        return SignatureImage(raw, width, height)
    }

    override fun onTagDiscovered(tag: Tag) {
        val request = pending.get() ?: return
        val isoDep = IsoDep.get(tag)
        if (isoDep == null) {
            mainHandler.post {
                pending.set(null)
                disableReaderMode()
                request.result.error("unsupported_tag", "Detected tag does not support ISO-DEP", null)
            }
            return
        }
        executor.execute {
            try {
                isoDep.timeout = maxOf(isoDep.timeout, 60_000)
                val signed = sdk.signPdfWithNfc(
                    request.pdf,
                    request.pin,
                    request.appearance,
                    isoDep,
                    request.outputPath?.let(::File)
                )
                mainHandler.post {
                    pending.set(null)
                    disableReaderMode()
                    request.result.success(signed)
                }
            } catch (ex: Exception) {
                mainHandler.post {
                    pending.set(null)
                    disableReaderMode()
                    request.result.error("nfc_sign_failed", ex.message, null)
                }
            } finally {
                try {
                    isoDep.close()
                } catch (_: Exception) {
                }
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
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        nfcAdapter = null
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
    }

    private data class PendingRequest(
        val pdf: ByteArray,
        val pin: String,
        val appearance: PdfAppearanceOptions,
        val outputPath: String?,
        val result: MethodChannel.Result
    )
}
