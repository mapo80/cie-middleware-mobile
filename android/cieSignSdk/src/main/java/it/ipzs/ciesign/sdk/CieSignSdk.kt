package it.ipzs.ciesign.sdk

import android.nfc.tech.IsoDep
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
    fun mockSignPdf(
        pdfBytes: ByteArray,
        outputFile: File? = null,
        appearance: PdfAppearanceOptions? = null,
    ): ByteArray {
        require(pdfBytes.isNotEmpty()) { "PDF input cannot be empty" }
        val path = outputFile?.absolutePath
        val app = appearance
        return NativeBridge.mockSignPdf(
            pdfBytes,
            path,
            app?.pageIndex ?: 0,
            app?.left ?: 0f,
            app?.bottom ?: 0f,
            app?.width ?: 0f,
            app?.height ?: 0f,
            app?.reason,
            app?.location,
            app?.name,
            app?.fieldIds?.toTypedArray(),
            app?.signatureImage,
            app?.signatureImageWidth ?: 0,
            app?.signatureImageHeight ?: 0
        )
    }

  fun signPdfWithNfc(
        pdfBytes: ByteArray,
        pin: String,
        appearance: PdfAppearanceOptions,
        isoDep: IsoDep,
        outputFile: File? = null
    ): ByteArray {
        require(pdfBytes.isNotEmpty()) { "PDF input cannot be empty" }
        require(pin.isNotBlank()) { "PIN cannot be empty" }

        if (!isoDep.isConnected) {
            isoDep.connect()
        }
        val atr = buildAtr(isoDep)
        val path = outputFile?.absolutePath
    return NativeBridge.signPdfWithNfc(
      pdfBytes,
      pin,
      appearance.pageIndex,
      appearance.left,
      appearance.bottom,
      appearance.width,
      appearance.height,
      appearance.reason,
      appearance.location,
      appearance.name,
      appearance.fieldIds?.toTypedArray(),
      appearance.signatureImage,
      appearance.signatureImageWidth,
      appearance.signatureImageHeight,
      isoDep,
      atr,
      path
    )
  }

  fun verifyPinWithNfc(
    pin: String,
    isoDep: IsoDep,
  ): Boolean {
    require(pin.isNotBlank()) { "PIN cannot be empty" }
    if (!isoDep.isConnected) {
      isoDep.connect()
    }
    val atr = buildAtr(isoDep)
    return NativeBridge.verifyPinWithNfc(pin, isoDep, atr)
  }

    private fun buildAtr(isoDep: IsoDep): ByteArray {
        isoDep.historicalBytes?.takeIf { it.isNotEmpty() }?.let { return it }
        isoDep.hiLayerResponse?.takeIf { it.isNotEmpty() }?.let { return it }
        isoDep.tag?.id?.takeIf { it.isNotEmpty() }?.let { return it }
        return byteArrayOf('A'.code.toByte(), 'N'.code.toByte(), 'D'.code.toByte(), 'R'.code.toByte())
    }
}
