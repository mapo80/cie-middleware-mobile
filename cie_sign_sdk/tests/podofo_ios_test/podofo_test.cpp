// Simple PoDoFo test for iOS
// This test verifies basic PoDoFo functionality on iOS arm64

#include <podofo/podofo.h>
#include <cstdio>
#include <cstring>
#include <vector>

using namespace PoDoFo;

// Buffer to hold PDF data passed from Objective-C
static std::vector<char> g_pdfBuffer;

extern "C" {

// Set the PDF data to test with
void podofo_test_set_pdf_data(const char* data, size_t length) {
    g_pdfBuffer.assign(data, data + length);
    printf("[PODOFO_TEST] Received PDF data: %zu bytes\n", length);
}

// Test 1: Basic PDF loading from buffer
int podofo_test_load_buffer(const char** error_msg) {
    try {
        printf("[PODOFO_TEST] Test 1: Loading PDF from buffer...\n");

        if (g_pdfBuffer.empty()) {
            *error_msg = "No PDF data set - call podofo_test_set_pdf_data first";
            return -1;
        }

        PdfMemDocument doc;
        printf("[PODOFO_TEST] PDF size: %zu bytes\n", g_pdfBuffer.size());

        bufferview buffer(g_pdfBuffer.data(), g_pdfBuffer.size());
        printf("[PODOFO_TEST] Created bufferview\n");

        doc.LoadFromBuffer(buffer);
        printf("[PODOFO_TEST] LoadFromBuffer succeeded!\n");

        return 0;
    } catch (const PdfError& e) {
        static char err[512];
        snprintf(err, sizeof(err), "PdfError: %s", e.what());
        *error_msg = err;
        return 1;
    } catch (const std::exception& e) {
        static char err[512];
        snprintf(err, sizeof(err), "std::exception: %s", e.what());
        *error_msg = err;
        return 2;
    } catch (...) {
        *error_msg = "Unknown exception";
        return 3;
    }
}

// Test 1.5: Test PdfCommon (which triggers global init)
int podofo_test_pdfcommon(const char** error_msg) {
    try {
        printf("[PODOFO_TEST] Test 1.5: Testing PdfCommon globals...\n");
        fflush(stdout);

        printf("[PODOFO_TEST] Calling GetMaxRecursionDepth()...\n");
        fflush(stdout);
        unsigned maxDepth = PdfCommon::GetMaxRecursionDepth();
        printf("[PODOFO_TEST] MaxRecursionDepth = %u\n", maxDepth);
        fflush(stdout);

        // Test 1.6: Try to access document catalog which triggers similar code paths
        printf("[PODOFO_TEST] Test 1.6: Testing document metadata access...\n");
        fflush(stdout);

        if (!g_pdfBuffer.empty()) {
            PdfMemDocument doc;
            bufferview buffer(g_pdfBuffer.data(), g_pdfBuffer.size());
            doc.LoadFromBuffer(buffer);

            printf("[PODOFO_TEST] Getting document metadata...\n");
            fflush(stdout);

            // Try accessing metadata which might trigger different code paths
            auto& metadata = doc.GetMetadata();
            printf("[PODOFO_TEST] Metadata access succeeded\n");
            fflush(stdout);

            // Try getting catalog
            printf("[PODOFO_TEST] Getting catalog...\n");
            fflush(stdout);
            auto& catalog = doc.GetCatalog();
            printf("[PODOFO_TEST] Catalog address: %p\n", (void*)&catalog);
            fflush(stdout);
        }

        return 0;
    } catch (const PdfError& e) {
        static char err[512];
        snprintf(err, sizeof(err), "PdfError: %s", e.what());
        *error_msg = err;
        return 1;
    } catch (const std::exception& e) {
        static char err[512];
        snprintf(err, sizeof(err), "std::exception: %s", e.what());
        *error_msg = err;
        return 2;
    } catch (...) {
        *error_msg = "Unknown exception";
        return 3;
    }
}

// Test 2: GetPages().GetCount()
int podofo_test_get_page_count(const char** error_msg) {
    try {
        printf("[PODOFO_TEST] Test 2: Getting page count...\n");
        fflush(stdout);

        if (g_pdfBuffer.empty()) {
            *error_msg = "No PDF data set";
            return -1;
        }

        printf("[PODOFO_TEST] Creating PdfMemDocument...\n");
        fflush(stdout);
        PdfMemDocument doc;
        printf("[PODOFO_TEST] PdfMemDocument created\n");
        fflush(stdout);

        bufferview buffer(g_pdfBuffer.data(), g_pdfBuffer.size());
        printf("[PODOFO_TEST] Loading from buffer...\n");
        fflush(stdout);
        doc.LoadFromBuffer(buffer);
        printf("[PODOFO_TEST] Document loaded\n");
        fflush(stdout);

        printf("[PODOFO_TEST] About to call GetPages()...\n");
        fflush(stdout);
        PdfPageCollection& pages = doc.GetPages();
        printf("[PODOFO_TEST] GetPages() returned address: %p\n", (void*)&pages);
        fflush(stdout);

        printf("[PODOFO_TEST] About to call GetCount() - THIS IS WHERE CRASH HAPPENS\n");
        fflush(stdout);

        // Get the root pages object first
        printf("[PODOFO_TEST] Getting catalog from document...\n");
        fflush(stdout);
        auto& catalog = doc.GetCatalog();
        printf("[PODOFO_TEST] Catalog obtained: %p\n", (void*)&catalog);
        fflush(stdout);

        printf("[PODOFO_TEST] Now calling GetCount()...\n");
        fflush(stdout);
        unsigned count = pages.GetCount();
        printf("[PODOFO_TEST] Page count: %u\n", count);
        fflush(stdout);

        return 0;
    } catch (const PdfError& e) {
        static char err[512];
        snprintf(err, sizeof(err), "PdfError: %s", e.what());
        *error_msg = err;
        return 1;
    } catch (const std::exception& e) {
        static char err[512];
        snprintf(err, sizeof(err), "std::exception: %s", e.what());
        *error_msg = err;
        return 2;
    } catch (...) {
        *error_msg = "Unknown exception";
        return 3;
    }
}

// Test 3: GetPageAt(0)
int podofo_test_get_page_at(const char** error_msg) {
    try {
        printf("[PODOFO_TEST] Test 3: Getting page at index 0...\n");

        if (g_pdfBuffer.empty()) {
            *error_msg = "No PDF data set";
            return -1;
        }

        PdfMemDocument doc;
        bufferview buffer(g_pdfBuffer.data(), g_pdfBuffer.size());
        doc.LoadFromBuffer(buffer);
        printf("[PODOFO_TEST] Document loaded\n");

        printf("[PODOFO_TEST] Calling GetPages().GetPageAt(0)...\n");
        PdfPage& page = doc.GetPages().GetPageAt(0);
        printf("[PODOFO_TEST] GetPageAt(0) succeeded!\n");

        printf("[PODOFO_TEST] Getting page rect...\n");
        Rect rect = page.GetRect();
        printf("[PODOFO_TEST] Page rect: %.1f x %.1f\n", rect.Width, rect.Height);

        return 0;
    } catch (const PdfError& e) {
        static char err[512];
        snprintf(err, sizeof(err), "PdfError: %s", e.what());
        *error_msg = err;
        return 1;
    } catch (const std::exception& e) {
        static char err[512];
        snprintf(err, sizeof(err), "std::exception: %s", e.what());
        *error_msg = err;
        return 2;
    } catch (...) {
        *error_msg = "Unknown exception";
        return 3;
    }
}

// Run all tests
int podofo_run_all_tests(void) {
    const char* error_msg = nullptr;
    int result;
    int failed = 0;
    int total = 4;

    printf("\n========== PODOFO iOS TEST SUITE ==========\n\n");

    // Test 1
    result = podofo_test_load_buffer(&error_msg);
    if (result != 0) {
        printf("[PODOFO_TEST] Test 1 FAILED: %s\n", error_msg);
        failed++;
    } else {
        printf("[PODOFO_TEST] Test 1 PASSED\n");
    }
    printf("\n");

    // Test 1.5 - PdfCommon
    result = podofo_test_pdfcommon(&error_msg);
    if (result != 0) {
        printf("[PODOFO_TEST] Test 1.5 FAILED: %s\n", error_msg);
        failed++;
    } else {
        printf("[PODOFO_TEST] Test 1.5 PASSED\n");
    }
    printf("\n");

    // Test 2
    result = podofo_test_get_page_count(&error_msg);
    if (result != 0) {
        printf("[PODOFO_TEST] Test 2 FAILED: %s\n", error_msg);
        failed++;
    } else {
        printf("[PODOFO_TEST] Test 2 PASSED\n");
    }
    printf("\n");

    // Test 3
    result = podofo_test_get_page_at(&error_msg);
    if (result != 0) {
        printf("[PODOFO_TEST] Test 3 FAILED: %s\n", error_msg);
        failed++;
    } else {
        printf("[PODOFO_TEST] Test 3 PASSED\n");
    }
    printf("\n");

    printf("========== RESULTS: %d/%d tests passed ==========\n\n", total - failed, total);

    return failed;
}

} // extern "C"
