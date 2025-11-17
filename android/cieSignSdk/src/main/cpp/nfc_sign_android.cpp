#include "mobile/cie_platform.h"
#include "mobile/cie_sign.h"

#include <jni.h>
#include <android/log.h>

#include <cstdio>
#include <memory>
#include <string>
#include <vector>

namespace {

JavaVM* g_android_vm = nullptr;

constexpr const char* kTag = "CieSignNfc";

void log_error(const char* message) {
    __android_log_print(ANDROID_LOG_ERROR, kTag, "%s", message);
}

struct IsoDepBridge {
    JavaVM* vm = nullptr;
    jobject iso_dep = nullptr;
    jmethodID transceive = nullptr;
    jmethodID close = nullptr;
    std::vector<uint8_t> atr;
};

class ScopedEnv {
public:
    explicit ScopedEnv(JavaVM* vm) : vm_(vm) {
        if (vm_->GetEnv(reinterpret_cast<void **>(&env_), JNI_VERSION_1_6) != JNI_OK) {
            vm_->AttachCurrentThread(&env_, nullptr);
            attached_ = true;
        }
    }

    ~ScopedEnv() {
        if (attached_) {
            vm_->DetachCurrentThread();
        }
    }

    JNIEnv* get() const { return env_; }

private:
    JavaVM* vm_ = nullptr;
    JNIEnv* env_ = nullptr;
    bool attached_ = false;
};

void throw_java_exception(JNIEnv* env, const char* message) {
    jclass exception = env->FindClass("java/lang/RuntimeException");
    if (!exception) {
        env->FatalError("Unable to find RuntimeException");
    }
    env->ThrowNew(exception, message);
}

int android_nfc_open(void* user_data, const uint8_t** atr, size_t* atr_len) {
    if (!user_data || !atr || !atr_len) {
        return -1;
    }
    auto* bridge = static_cast<IsoDepBridge*>(user_data);
    if (bridge->atr.empty()) {
        return -1;
    }
    *atr = bridge->atr.data();
    *atr_len = bridge->atr.size();
    return 0;
}

int android_nfc_transceive(void* user_data,
                           const uint8_t* apdu,
                           uint32_t apdu_len,
                           uint8_t* resp,
                           uint32_t* resp_len) {
    if (!user_data || !apdu || apdu_len == 0 || !resp || !resp_len) {
        return -1;
    }
    auto* bridge = static_cast<IsoDepBridge*>(user_data);
    ScopedEnv scoped_env(bridge->vm);
    JNIEnv* env = scoped_env.get();
    jbyteArray request = env->NewByteArray(static_cast<jsize>(apdu_len));
    if (!request) {
        log_error("Unable to allocate request array");
        return -1;
    }
    env->SetByteArrayRegion(request, 0, static_cast<jsize>(apdu_len), reinterpret_cast<const jbyte*>(apdu));
    jbyteArray response = static_cast<jbyteArray>(env->CallObjectMethod(bridge->iso_dep, bridge->transceive, request));
    env->DeleteLocalRef(request);
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        log_error("IsoDep.transceive failed");
        return -1;
    }
    if (!response) {
        log_error("IsoDep.transceive returned null");
        return -1;
    }
    const jsize length = env->GetArrayLength(response);
    if (*resp_len < static_cast<uint32_t>(length)) {
        env->DeleteLocalRef(response);
        log_error("Response buffer too small");
        return -1;
    }
    env->GetByteArrayRegion(response, 0, length, reinterpret_cast<jbyte*>(resp));
    env->DeleteLocalRef(response);
    *resp_len = static_cast<uint32_t>(length);
    return 0;
}

void android_nfc_close(void* user_data) {
    auto* bridge = static_cast<IsoDepBridge*>(user_data);
    if (!bridge) {
        return;
    }
    ScopedEnv scoped_env(bridge->vm);
    JNIEnv* env = scoped_env.get();
    if (bridge->iso_dep && bridge->close) {
        env->CallVoidMethod(bridge->iso_dep, bridge->close);
        if (env->ExceptionCheck()) {
            env->ExceptionDescribe();
            env->ExceptionClear();
        }
    }
    if (bridge->iso_dep) {
        env->DeleteGlobalRef(bridge->iso_dep);
        bridge->iso_dep = nullptr;
    }
}

class NativeRequestGuard {
public:
    NativeRequestGuard(JNIEnv* env,
                       jbyteArray pdfData,
                       jstring pinValue,
                       jstring reasonValue,
                       jstring locationValue,
                       jstring nameValue,
                       jobjectArray fieldIds,
                       jbyteArray signatureImage,
                       jint imageWidth,
                       jint imageHeight,
                       jbyteArray atrBytes)
        : env_(env) {
        readByteArray(pdfData, pdf_);
        readByteArray(atrBytes, atr_);
        readByteArray(signatureImage, signature_image_);
        pin_ = readString(pinValue);
        reason_ = readString(reasonValue);
        location_ = readString(locationValue);
        name_ = readString(nameValue);
        readStringArray(fieldIds, field_ids_);
        image_width_ = static_cast<int>(imageWidth);
        image_height_ = static_cast<int>(imageHeight);
    }

    const std::vector<uint8_t>& pdf() const { return pdf_; }
    const std::vector<uint8_t>& atr() const { return atr_; }
    const std::string& pin() const { return pin_; }
    const std::string& reason() const { return reason_; }
    const std::string& location() const { return location_; }
    const std::string& name() const { return name_; }
    const std::vector<std::string>& field_ids() const { return field_ids_; }
    const std::vector<uint8_t>& signature_image() const { return signature_image_; }
    int image_width() const { return image_width_; }
    int image_height() const { return image_height_; }

private:
    void readByteArray(jbyteArray array, std::vector<uint8_t>& out) {
        if (!array) {
            out.clear();
            return;
        }
        const jsize len = env_->GetArrayLength(array);
        out.resize(static_cast<size_t>(len));
        env_->GetByteArrayRegion(array, 0, len, reinterpret_cast<jbyte*>(out.data()));
    }

    std::string readString(jstring value) {
        if (!value) {
            return std::string();
        }
        const char* chars = env_->GetStringUTFChars(value, nullptr);
        if (!chars) {
            return std::string();
        }
        std::string result(chars);
        env_->ReleaseStringUTFChars(value, chars);
        return result;
    }

    void readStringArray(jobjectArray array, std::vector<std::string>& out) {
        if (!array) {
            out.clear();
            return;
        }
        jsize len = env_->GetArrayLength(array);
        out.reserve(static_cast<size_t>(len));
        for (jsize i = 0; i < len; ++i) {
            jstring element = static_cast<jstring>(env_->GetObjectArrayElement(array, i));
            if (!element) {
                out.emplace_back();
                continue;
            }
            out.emplace_back(readString(element));
            env_->DeleteLocalRef(element);
        }
    }

    JNIEnv* env_ = nullptr;
    std::vector<uint8_t> pdf_;
    std::vector<uint8_t> atr_;
    std::vector<uint8_t> signature_image_;
    std::string pin_;
    std::string reason_;
    std::string location_;
    std::string name_;
    std::vector<std::string> field_ids_;
    int image_width_ = 0;
    int image_height_ = 0;
};

void persist_output(const std::vector<uint8_t>& pdf, const std::string& path) {
    if (path.empty()) {
        return;
    }
    FILE* fp = std::fopen(path.c_str(), "wb");
    if (!fp) {
        log_error("Unable to open output path");
        return;
    }
    size_t written = std::fwrite(pdf.data(), 1, pdf.size(), fp);
    std::fclose(fp);
    if (written != pdf.size()) {
        log_error("Failed to persist entire PDF");
    }
}

} // namespace

extern "C" jint JNI_OnLoad(JavaVM* vm, void*) {
    g_android_vm = vm;
    return JNI_VERSION_1_6;
}

extern "C"
JNIEXPORT jbyteArray JNICALL
Java_it_ipzs_ciesign_sdk_NativeBridge_signPdfWithNfc(
    JNIEnv* env,
    jclass,
    jbyteArray pdfBytes,
    jstring pin,
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
    jint imageHeight,
    jobject isoDep,
    jbyteArray atrBytes,
    jstring outputPath) {

    if (!pdfBytes || !pin || !isoDep || !atrBytes) {
        throw_java_exception(env, "Invalid arguments for signPdfWithNfc");
        return nullptr;
    }

    NativeRequestGuard request(env, pdfBytes, pin, reason, location, name, fieldIds, signatureImage, imageWidth, imageHeight, atrBytes);
    if (request.pdf().empty()) {
        throw_java_exception(env, "PDF buffer is empty");
        return nullptr;
    }
    if (request.atr().empty()) {
        throw_java_exception(env, "ATR buffer is empty");
        return nullptr;
    }

    jclass isoDepClass = env->GetObjectClass(isoDep);
    if (!isoDepClass) {
        throw_java_exception(env, "Unable to resolve IsoDep class");
        return nullptr;
    }

    jmethodID transceiveMethod = env->GetMethodID(isoDepClass, "transceive", "([B)[B");
    jmethodID closeMethod = env->GetMethodID(isoDepClass, "close", "()V");
    if (!transceiveMethod) {
        throw_java_exception(env, "IsoDep.transceive method not found");
        return nullptr;
    }
    env->DeleteLocalRef(isoDepClass);

    IsoDepBridge bridge{};
    bridge.vm = g_android_vm;
    bridge.iso_dep = env->NewGlobalRef(isoDep);
    bridge.transceive = transceiveMethod;
    bridge.close = closeMethod;
    bridge.atr = request.atr();

    cie_platform_nfc_adapter adapter{};
    adapter.user_data = &bridge;
    adapter.open = android_nfc_open;
    adapter.transceive = android_nfc_transceive;
    adapter.close = android_nfc_close;

    cie_platform_config config{};
    config.nfc = &adapter;

    std::unique_ptr<cie_sign_ctx, decltype(&cie_sign_ctx_destroy)> ctx(
        cie_sign_ctx_create_with_platform(&config), cie_sign_ctx_destroy);

    if (!ctx) {
        android_nfc_close(&bridge);
        throw_java_exception(env, "Unable to create signing context");
        return nullptr;
    }

    cie_sign_request signRequest{};
    signRequest.input = request.pdf().data();
    signRequest.input_len = request.pdf().size();
    signRequest.pin = request.pin().c_str();
    signRequest.pin_len = request.pin().size();
    signRequest.doc_type = CIE_DOCUMENT_PDF;
    signRequest.detached = 0;
    signRequest.pdf.page_index = static_cast<uint32_t>(pageIndex);
    signRequest.pdf.left = left;
    signRequest.pdf.bottom = bottom;
    signRequest.pdf.width = width;
    signRequest.pdf.height = height;
    signRequest.pdf.reason = request.reason().empty() ? nullptr : request.reason().c_str();
    signRequest.pdf.location = request.location().empty() ? nullptr : request.location().c_str();
    signRequest.pdf.name = request.name().empty() ? nullptr : request.name().c_str();
    signRequest.pdf.signature_image = request.signature_image().empty() ? nullptr : request.signature_image().data();
    signRequest.pdf.signature_image_len = request.signature_image().size();
    signRequest.pdf.signature_image_width = static_cast<uint32_t>(request.image_width());
    signRequest.pdf.signature_image_height = static_cast<uint32_t>(request.image_height());
    std::vector<const char*> fieldPointers;
    fieldPointers.reserve(request.field_ids().size());
    for (const auto& id : request.field_ids()) {
        if (!id.empty()) {
            fieldPointers.push_back(id.c_str());
        }
    }
    if (!fieldPointers.empty()) {
        signRequest.pdf.field_ids = fieldPointers.data();
        signRequest.pdf.field_ids_len = fieldPointers.size();
    }

    std::vector<uint8_t> output(request.pdf().size() + 65536);
    cie_sign_result result{};
    result.output = output.data();
    result.output_capacity = output.size();

    cie_status status = cie_sign_execute(ctx.get(), &signRequest, &result);
    android_nfc_close(&bridge);
    if (status != CIE_STATUS_OK) {
        const char* last_error = cie_sign_get_last_error(ctx.get());
        std::string message = last_error ? last_error : "Unable to sign PDF via NFC";
        throw_java_exception(env, message.c_str());
        return nullptr;
    }

    output.resize(result.output_len);
    if (outputPath) {
        const char* path_chars = env->GetStringUTFChars(outputPath, nullptr);
        if (path_chars) {
            persist_output(output, path_chars);
            env->ReleaseStringUTFChars(outputPath, path_chars);
        }
    }

    jbyteArray signedPdf = env->NewByteArray(static_cast<jsize>(output.size()));
    if (!signedPdf) {
        throw_java_exception(env, "Unable to allocate signed PDF array");
        return nullptr;
    }
    env->SetByteArrayRegion(signedPdf, 0, static_cast<jsize>(output.size()), reinterpret_cast<const jbyte*>(output.data()));
    return signedPdf;
}
