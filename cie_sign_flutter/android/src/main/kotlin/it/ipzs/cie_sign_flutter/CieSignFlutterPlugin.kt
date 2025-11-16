package it.ipzs.cie_sign_flutter

import it.ipzs.ciesign.sdk.CieSignSdk
import java.io.File
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class CieSignFlutterPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val sdk = CieSignSdk()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cie_sign_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "mockSignPdf" -> handleMockSign(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleMockSign(call: MethodCall, result: Result) {
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
        try {
            val signedPdf = sdk.mockSignPdf(pdf, outputPath?.let(::File))
            result.success(signedPdf)
        } catch (ex: Exception) {
            result.error("mock_sign_failed", ex.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
