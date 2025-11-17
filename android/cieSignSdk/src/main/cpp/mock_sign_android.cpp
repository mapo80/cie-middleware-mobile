#include "mock/mock_transport.h"
#include "PdfSignatureGenerator.h"
#include "SignedDocument.h"
#include "mobile/cie_sign.h"
#include "mobile/mock_signer_material.h"

#include <android/log.h>
#include <jni.h>

#include <array>
#include <cctype>
#include <cstdio>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr const char* kLogTag = "CieSignNative";

void log_error(const char* message)
{
    __android_log_print(ANDROID_LOG_ERROR, kLogTag, "%s", message);
}

void throw_java_exception(JNIEnv* env, const std::string& message)
{
    log_error(message.c_str());
    jclass exceptionClass = env->FindClass("java/lang/RuntimeException");
    if (exceptionClass != nullptr)
    {
        env->ThrowNew(exceptionClass, message.c_str());
    }
}

std::string to_std_string(JNIEnv* env, jstring value)
{
    if (!value)
        return {};
    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (!chars)
        return {};
    std::string result(chars);
    env->ReleaseStringUTFChars(value, chars);
    return result;
}

std::vector<uint8_t> to_vector(JNIEnv* env, jbyteArray array)
{
    if (!array)
        return {};
    jsize len = env->GetArrayLength(array);
    if (len <= 0)
        return {};
    std::vector<uint8_t> buffer(static_cast<size_t>(len));
    env->GetByteArrayRegion(array, 0, len, reinterpret_cast<jbyte*>(buffer.data()));
    return buffer;
}

std::vector<std::string> to_string_list(JNIEnv* env, jobjectArray array)
{
    std::vector<std::string> values;
    if (!array)
        return values;
    jsize len = env->GetArrayLength(array);
    values.reserve(static_cast<size_t>(len));
    for (jsize i = 0; i < len; ++i)
    {
        jstring element = static_cast<jstring>(env->GetObjectArrayElement(array, i));
        if (!element)
        {
            values.emplace_back();
            continue;
        }
        values.emplace_back(to_std_string(env, element));
        env->DeleteLocalRef(element);
    }
    return values;
}

int hexValue(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

std::array<long long, 4> parseByteRange(const std::string& pdf, size_t start = 0)
{
    auto pos = pdf.find("/ByteRange", start);
    if (pos == std::string::npos)
        throw std::runtime_error("ByteRange not found");
    pos = pdf.find('[', pos);
    if (pos == std::string::npos)
        throw std::runtime_error("ByteRange bracket missing");
    ++pos;
    std::array<long long, 4> values{};
    for (size_t i = 0; i < values.size(); ++i)
    {
        while (pos < pdf.size() && std::isspace(static_cast<unsigned char>(pdf[pos])))
            ++pos;
        size_t end = pos;
        while (end < pdf.size() && (std::isdigit(static_cast<unsigned char>(pdf[end])) || pdf[end] == '-'))
            ++end;
        if (end == pos)
            throw std::runtime_error("Invalid ByteRange value");
        values[i] = std::stoll(pdf.substr(pos, end - pos));
        pos = end;
    }
    return values;
}

std::vector<uint8_t> collectSignedData(const std::vector<uint8_t>& pdf,
                                       const std::array<long long, 4>& range)
{
    std::vector<uint8_t> data;
    for (size_t i = 0; i < range.size(); i += 2)
    {
        long long offset = range[i];
        long long length = range[i + 1];
        if (offset < 0 || length < 0 || static_cast<size_t>(offset + length) > pdf.size())
            throw std::runtime_error("ByteRange outside PDF");
        data.insert(data.end(), pdf.begin() + offset, pdf.begin() + offset + length);
    }
    return data;
}

std::string extractContentsHex(const std::string& pdf, size_t start = 0)
{
    auto pos = pdf.find("/Contents", start);
    if (pos == std::string::npos)
        throw std::runtime_error("Contents not found");
    pos = pdf.find('<', pos);
    if (pos == std::string::npos)
        throw std::runtime_error("Contents hex start missing");
    auto end = pdf.find('>', pos + 1);
    if (end == std::string::npos)
        throw std::runtime_error("Contents hex end missing");
    return pdf.substr(pos + 1, end - pos - 1);
}

std::vector<uint8_t> decodeHexString(const std::string& hex)
{
    std::vector<uint8_t> out;
    int hi = -1;
    for (char c : hex)
    {
        if (std::isspace(static_cast<unsigned char>(c)))
            continue;
        int val = hexValue(c);
        if (val < 0)
            continue;
        if (hi < 0)
            hi = val;
        else
        {
            out.push_back(static_cast<uint8_t>((hi << 4) | val));
            hi = -1;
        }
    }
    return out;
}

void verify_signed_pdf(const std::vector<uint8_t>& pdf)
{
    std::string pdfStr(reinterpret_cast<const char*>(pdf.data()), pdf.size());
    auto sigPos = pdfStr.find("/Type/Sig");
    if (sigPos == std::string::npos)
        throw std::runtime_error("Signature dictionary missing");
    auto byteRange = parseByteRange(pdfStr, sigPos);
    auto signedData = collectSignedData(pdf, byteRange);
    auto hex = extractContentsHex(pdfStr, sigPos);
    auto cmsBytes = decodeHexString(hex);
    UUCByteArray cmsArray;
    cmsArray.append(cmsBytes.data(), static_cast<unsigned int>(cmsBytes.size()));
    CSignedDocument signedDoc(cmsArray.getContent(), cmsArray.getLength());
    UUCByteArray contentArray;
    contentArray.append(signedData.data(), static_cast<unsigned int>(signedData.size()));
    signedDoc.setContent(contentArray);
    CCertificate signerCert = signedDoc.getSignerCertificate(0);
    UUCByteArray certBytes;
    signerCert.toByteArray(certBytes);
    if (certBytes.getLength() != cie::mobile::mock_signer::kMockCertificateDerLen)
        throw std::runtime_error("Unexpected certificate length");
    bool matches = std::equal(certBytes.getContent(),
                              certBytes.getContent() + certBytes.getLength(),
                              cie::mobile::mock_signer::kMockCertificateDer);
    if (!matches)
        throw std::runtime_error("Signer certificate does not match mock material");
}

void persist_signed_pdf(const std::vector<uint8_t>& pdf, const std::string& outputPath)
{
    if (outputPath.empty())
        return;
    FILE* fp = std::fopen(outputPath.c_str(), "wb");
    if (!fp)
        throw std::runtime_error("Unable to open output file for signed PDF");
    size_t written = std::fwrite(pdf.data(), 1, pdf.size(), fp);
    std::fclose(fp);
    if (written != pdf.size())
        throw std::runtime_error("Failed to write complete signed PDF");
}

struct AppearanceOptions {
    int pageIndex = 0;
    float left = 0.f;
    float bottom = 0.f;
    float width = 0.f;
    float height = 0.f;
    std::string reason;
    std::string location;
    std::string name;
    std::vector<uint8_t> signatureImage;
    int imageWidth = 0;
    int imageHeight = 0;
    std::vector<std::string> fieldIds;
};

std::vector<uint8_t> run_mock_flow(const uint8_t* pdf_data,
                                   size_t pdf_len,
                                   const AppearanceOptions& appearance)
{
    MockApduTransport transport;
    std::unique_ptr<cie_sign_ctx, decltype(&cie_sign_ctx_destroy)> ctx(
        create_mock_context(transport), cie_sign_ctx_destroy);
    if (!ctx)
        throw std::runtime_error("Unable to initialize signing context");

    const char pin[] = "1234";
    const uint8_t data[] = {0x01, 0x02, 0x03};

    cie_sign_request req{};
    req.input = data;
    req.input_len = sizeof(data);
    req.pin = pin;
    req.pin_len = sizeof(pin) - 1;
    req.doc_type = CIE_DOCUMENT_PKCS7;
    req.detached = 0;

    std::vector<uint8_t> buffer(65536);
    cie_sign_result result{};
    result.output = buffer.data();
    result.output_capacity = buffer.size();

    if (cie_sign_execute(ctx.get(), &req, &result) != CIE_STATUS_OK)
        throw std::runtime_error("PKCS7 mock signing failed");
    if (!transport.completed())
        throw std::runtime_error("Mock transport did not complete APDUs");

    std::vector<uint8_t> pdf(pdf_data, pdf_data + pdf_len);
    std::vector<const char*> fieldPointers;
    fieldPointers.reserve(appearance.fieldIds.size());
    for (const auto& value : appearance.fieldIds) {
        if (!value.empty()) {
            fieldPointers.push_back(value.c_str());
        }
    }
    req.input = pdf.data();
    req.input_len = pdf.size();
    req.doc_type = CIE_DOCUMENT_PDF;
    req.pdf = {};
    req.pdf.page_index = static_cast<uint32_t>(appearance.pageIndex);
    req.pdf.left = appearance.left;
    req.pdf.bottom = appearance.bottom;
    req.pdf.width = appearance.width;
    req.pdf.height = appearance.height;
    req.pdf.reason = appearance.reason.empty() ? nullptr : appearance.reason.c_str();
    req.pdf.name = appearance.name.empty() ? nullptr : appearance.name.c_str();
    req.pdf.location = appearance.location.empty() ? nullptr : appearance.location.c_str();
    req.pdf.signature_image = appearance.signatureImage.empty() ? nullptr : appearance.signatureImage.data();
    req.pdf.signature_image_len = appearance.signatureImage.size();
    req.pdf.signature_image_width = static_cast<uint32_t>(appearance.imageWidth);
    req.pdf.signature_image_height = static_cast<uint32_t>(appearance.imageHeight);
    if (!fieldPointers.empty()) {
        req.pdf.field_ids = fieldPointers.data();
        req.pdf.field_ids_len = fieldPointers.size();
    }
    result.output_len = 0;

    if (cie_sign_execute(ctx.get(), &req, &result) != CIE_STATUS_OK)
        throw std::runtime_error("PDF signing failed");

    std::vector<uint8_t> signedPdf(result.output, result.output + result.output_len);
    if (signedPdf.size() <= pdf.size())
        throw std::runtime_error("Signed PDF is not larger than input");
    return signedPdf;
}

} // namespace

extern "C"
JNIEXPORT jbyteArray JNICALL
Java_it_ipzs_ciesign_sdk_NativeBridge_mockSignPdf(
    JNIEnv* env,
    jclass,
    jbyteArray inputPdf,
    jstring outputPath,
    jint pageIndex,
    jfloat left,
    jfloat bottom,
    jfloat width,
    jfloat height,
    jstring reason,
    jstring location,
    jstring name,
    jobjectArray fieldIds,
    jbyteArray signatureImage,
    jint imageWidth,
    jint imageHeight)
{
    if (inputPdf == nullptr)
    {
        throw_java_exception(env, "PDF input is null");
        return nullptr;
    }

    jsize pdf_len = env->GetArrayLength(inputPdf);
    std::vector<uint8_t> pdf_bytes(static_cast<size_t>(pdf_len));
    env->GetByteArrayRegion(inputPdf, 0, pdf_len, reinterpret_cast<jbyte*>(pdf_bytes.data()));

    std::string output_path;
    if (outputPath != nullptr)
    {
        const char* chars = env->GetStringUTFChars(outputPath, nullptr);
        if (chars)
        {
            output_path.assign(chars);
            env->ReleaseStringUTFChars(outputPath, chars);
        }
    }

    AppearanceOptions appearance;
    appearance.pageIndex = static_cast<int>(pageIndex);
    appearance.left = left;
    appearance.bottom = bottom;
    appearance.width = width;
    appearance.height = height;
    appearance.reason = to_std_string(env, reason);
    appearance.location = to_std_string(env, location);
    appearance.name = to_std_string(env, name);
    appearance.fieldIds = to_string_list(env, fieldIds);
    appearance.signatureImage = to_vector(env, signatureImage);
    appearance.imageWidth = static_cast<int>(imageWidth);
    appearance.imageHeight = static_cast<int>(imageHeight);

    try
    {
        auto signedPdf = run_mock_flow(pdf_bytes.data(), pdf_bytes.size(), appearance);
        persist_signed_pdf(signedPdf, output_path);
        verify_signed_pdf(signedPdf);

        jbyteArray resultArray = env->NewByteArray(static_cast<jsize>(signedPdf.size()));
        if (!resultArray)
        {
            throw_java_exception(env, "Unable to allocate jbyteArray for signed PDF");
            return nullptr;
        }
        env->SetByteArrayRegion(resultArray, 0, static_cast<jsize>(signedPdf.size()),
                                reinterpret_cast<const jbyte*>(signedPdf.data()));
        return resultArray;
    }
    catch (const std::exception& ex)
    {
        throw_java_exception(env, ex.what());
    }
    catch (...)
    {
        throw_java_exception(env, "Unknown error while signing PDF");
    }
    return nullptr;
}
