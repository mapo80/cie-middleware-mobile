// Simple PoDoFo test for macOS
// Build with vcpkg arm64-osx:
// VCPKG_ROOT="../../.vcpkg/installed/arm64-osx"
// clang++ -std=c++17 main.cpp \
//   -I${VCPKG_ROOT}/include -L${VCPKG_ROOT}/lib \
//   -lpodofo -lpodofo_private -lpodofo_3rdparty \
//   -lfmt -ldate-tz -lutf8proc \
//   -lfreetype -lfontconfig -lexpat -lpng -lz -ljpeg -ltiff -lxml2 -lbz2 -llzma \
//   -lbrotlidec -lbrotlienc -lbrotlicommon \
//   -lcrypto -lssl \
//   -framework CoreFoundation -framework CoreText -framework Security \
//   -liconv \
//   -o podofo_test

#include <podofo/podofo.h>
#include <cstdio>
#include <cstring>
#include <vector>
#include <fstream>

using namespace PoDoFo;

int main(int argc, char* argv[]) {
    const char* pdfPath = "../../data/fixtures/sample.pdf";
    if (argc > 1) {
        pdfPath = argv[1];
    }

    printf("\n========== PODOFO macOS TEST ==========\n\n");
    printf("Using PDF file: %s\n\n", pdfPath);

    // Read PDF file into buffer
    std::ifstream file(pdfPath, std::ios::binary | std::ios::ate);
    if (!file) {
        printf("ERROR: Cannot open PDF file: %s\n", pdfPath);
        return -1;
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::vector<char> pdfBuffer(size);
    if (!file.read(pdfBuffer.data(), size)) {
        printf("ERROR: Cannot read PDF file\n");
        return -1;
    }
    file.close();
    printf("Loaded PDF file: %lld bytes\n\n", (long long)size);

    // Test 1: Basic PDF loading from buffer
    printf("[TEST 1] Loading PDF from buffer...\n");
    try {
        PdfMemDocument doc;
        bufferview buffer(pdfBuffer.data(), pdfBuffer.size());
        printf("  Created bufferview\n");

        doc.LoadFromBuffer(buffer);
        printf("  LoadFromBuffer succeeded!\n");
        printf("[TEST 1] PASSED\n\n");
    } catch (const PdfError& e) {
        printf("  PdfError: %s\n", e.what());
        printf("[TEST 1] FAILED\n\n");
        return 1;
    } catch (const std::exception& e) {
        printf("  std::exception: %s\n", e.what());
        printf("[TEST 1] FAILED\n\n");
        return 1;
    }

    // Test 2: GetPages().GetCount()
    printf("[TEST 2] Getting page count...\n");
    try {
        PdfMemDocument doc;
        bufferview buffer(pdfBuffer.data(), pdfBuffer.size());
        doc.LoadFromBuffer(buffer);
        printf("  Document loaded\n");

        printf("  Calling GetPages()...\n");
        PdfPageCollection& pages = doc.GetPages();
        printf("  GetPages() returned\n");

        printf("  Calling GetCount()...\n");
        unsigned count = pages.GetCount();
        printf("  Page count: %u\n", count);
        printf("[TEST 2] PASSED\n\n");
    } catch (const PdfError& e) {
        printf("  PdfError: %s\n", e.what());
        printf("[TEST 2] FAILED\n\n");
        return 2;
    } catch (const std::exception& e) {
        printf("  std::exception: %s\n", e.what());
        printf("[TEST 2] FAILED\n\n");
        return 2;
    }

    // Test 3: GetPageAt(0)
    printf("[TEST 3] Getting page at index 0...\n");
    try {
        PdfMemDocument doc;
        bufferview buffer(pdfBuffer.data(), pdfBuffer.size());
        doc.LoadFromBuffer(buffer);
        printf("  Document loaded\n");

        printf("  Calling GetPages().GetPageAt(0)...\n");
        PdfPage& page = doc.GetPages().GetPageAt(0);
        printf("  GetPageAt(0) succeeded!\n");

        printf("  Getting page rect...\n");
        Rect rect = page.GetRect();
        printf("  Page rect: %.1f x %.1f\n", rect.Width, rect.Height);
        printf("[TEST 3] PASSED\n\n");
    } catch (const PdfError& e) {
        printf("  PdfError: %s\n", e.what());
        printf("[TEST 3] FAILED\n\n");
        return 3;
    } catch (const std::exception& e) {
        printf("  std::exception: %s\n", e.what());
        printf("[TEST 3] FAILED\n\n");
        return 3;
    }

    printf("========== ALL TESTS PASSED ==========\n\n");
    return 0;
}
