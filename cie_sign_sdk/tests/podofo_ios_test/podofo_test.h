// Header for PoDoFo iOS test
#ifndef PODOFO_TEST_H
#define PODOFO_TEST_H

#ifdef __cplusplus
extern "C" {
#endif

int podofo_test_load_buffer(const char** error_msg);
int podofo_test_get_page_count(const char** error_msg);
int podofo_test_get_page_at(const char** error_msg);
int podofo_run_all_tests(void);

#ifdef __cplusplus
}
#endif

#endif // PODOFO_TEST_H
