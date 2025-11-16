package it.ipzs.ciesign.mock

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import it.ipzs.ciesign.sdk.CieSignSdk
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

        val header = result.take(4).toByteArray().decodeToString()
        assertTrue("Result should be a PDF", header.startsWith("%PDF"))
        assertTrue("Signed PDF should contain signature dictionary", String(result).contains("/Type/Sig"))
        assertTrue("Signed PDF should be persisted on disk", outputFile.exists() && outputFile.length().toInt() == result.size)
    }
}
