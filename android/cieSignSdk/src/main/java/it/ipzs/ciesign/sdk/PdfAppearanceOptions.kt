package it.ipzs.ciesign.sdk

data class PdfAppearanceOptions(
    val pageIndex: Int = 0,
    val left: Float = 0f,
    val bottom: Float = 0f,
    val width: Float = 0f,
    val height: Float = 0f,
    val reason: String? = null,
    val location: String? = null,
    val name: String? = null,
    val fieldIds: List<String>? = null,
    val signatureImage: ByteArray? = null,
    val signatureImageWidth: Int = 0,
    val signatureImageHeight: Int = 0
)
