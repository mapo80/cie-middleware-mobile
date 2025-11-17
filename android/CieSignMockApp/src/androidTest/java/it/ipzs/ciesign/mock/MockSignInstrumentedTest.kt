package it.ipzs.ciesign.mock

import android.graphics.BitmapFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import it.ipzs.ciesign.sdk.CieSignSdk
import it.ipzs.ciesign.sdk.PdfAppearanceOptions
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class MockSignInstrumentedTest {

    @Test
    fun mockSigningPipelineProducesPdf() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val assetManager = instrumentation.context.assets
        val sampleBytes = assetManager.open("sample.pdf").use { it.readBytes() }
        val outputFile = File(context.getExternalFilesDir(null), "mock_signed_android.pdf")

        val sdk = CieSignSdk()
        val result = sdk.mockSignPdf(sampleBytes, outputFile)
        val internalCopy = File(context.filesDir, "mock_signed_android.pdf")
        internalCopy.outputStream().use { it.write(result) }

        val header = result.take(4).toByteArray().decodeToString()
        assertTrue("Result should be a PDF", header.startsWith("%PDF"))
        assertTrue("Signed PDF should contain signature dictionary", String(result).contains("/Type/Sig"))
        assertTrue("Signed PDF should be persisted on disk", outputFile.exists() && outputFile.length().toInt() == result.size)
        assertTrue("Internal copy should exist", internalCopy.exists())
    }

    @Test
    fun mockSigningWithSignatureAppearanceSucceeds() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val assets = instrumentation.context.assets
        val pdfBytes = assets.open("sample.pdf").use { it.readBytes() }
        val (rgba, width, height) = loadSignatureRgba(assets.open("signature.png").use { it.readBytes() })

        val appearance = PdfAppearanceOptions(
            pageIndex = 0,
            left = 0.1f,
            bottom = 0.1f,
            width = 0.4f,
            height = 0.15f,
            reason = "Android instrumentation",
            location = "Lab",
            name = "Instrumentation Tester",
            fieldIds = listOf("SignatureField1"),
            signatureImage = rgba,
            signatureImageWidth = width,
            signatureImageHeight = height
        )

        val sdk = CieSignSdk()
        val result = sdk.mockSignPdf(pdfBytes, null, appearance)
        val pdfText = String(result)
        assertTrue("Signed PDF must still be valid", pdfText.contains("/Type/Sig"))
    }

    private fun loadSignatureRgba(pngBytes: ByteArray): Triple<ByteArray, Int, Int> {
        val bitmap = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size)
            ?: throw IllegalArgumentException("Unable to decode signature.png")
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val out = ByteArray(width * height * 4)
        var dst = 0
        for (color in pixels) {
            out[dst++] = ((color shr 16) and 0xFF).toByte()
            out[dst++] = ((color shr 8) and 0xFF).toByte()
            out[dst++] = (color and 0xFF).toByte()
            out[dst++] = ((color shr 24) and 0xFF).toByte()
        }
        return Triple(out, width, height)
    }
}
