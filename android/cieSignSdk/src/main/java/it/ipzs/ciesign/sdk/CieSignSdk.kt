package it.ipzs.ciesign.sdk

import java.io.File

/**
 * High level helper used by instrumentation tests and host apps in order to
 * exercise the native CIE signing pipeline without an NFC reader.
 */
class CieSignSdk {

    /**
     * Executes the mock signing flow implemented in native code.
     *
     * @param pdfBytes The PDF to sign.
     * @param outputFile Optional file path where the signed PDF will be written.
     * @return Signed PDF bytes ready for assertions.
     */
    fun mockSignPdf(pdfBytes: ByteArray, outputFile: File? = null): ByteArray {
        require(pdfBytes.isNotEmpty()) { "PDF input cannot be empty" }
        val path = outputFile?.absolutePath
        return NativeBridge.mockSignPdf(pdfBytes, path)
    }
}
