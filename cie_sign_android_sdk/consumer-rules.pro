# Keep the public JNI entrypoints so the loader can find them.
-keepclasseswithmembernames class it.ipzs.ciesign.sdk.NativeBridge {
    native <methods>;
}
