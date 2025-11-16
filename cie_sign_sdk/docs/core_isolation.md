# Strategia di isolamento del core C++

## Obiettivo
Produrre un modulo `ciesign_core` compilabile in modo indipendente che esponga:
- API C per creare/distruggere contesti (`cie_sign_context_create`, `cie_sign_context_free`).
- Funzioni per la firma buffer (PKCS#7, PDF, XML) e per gestire TSA/CRL opzionali.
- Gestione esterna del trasporto APDU tramite callback registrati.

## Componenti da includere
- `src/CSP/IAS.*`, `src/PCSC/*` (escluso codice PC/SC specifico, mantenere solo `Token` come interfaccia).
- `src/CIESigner.*`, `src/SignatureGenerator.*`, `src/PdfSignatureGenerator.*`, `src/XAdESGenerator.*`, `src/SignedDocument.*` e tutte le dipendenze ASN.1/Crypto già nel progetto.
- `src/disigonsdk.cpp` verrà rifattorizzato: estrarre la logica di business in una nuova classe `CMobileSignController` che lavora su buffer.

## Dipendenze da sostituire / parametrizzare
| Modulo | Azione |
| --- | --- |
| File I/O (fopen/fread) | Introdurre versioni “from memory” e fornire adapter opzionali per file system. |
| libcurl in `TSAClient` | Definire interfaccia `ITsaTransport` registrata dalla piattaforma; se assente usare implementazione di default (solo desktop). |
| Logging (`UUCLogger`) | Aggiungere callback di log fornito dal client; disabilitare quello globale se nullo. |

## API C previste
```c
typedef struct cie_sign_ctx cie_sign_ctx;

typedef HRESULT (*cie_apdu_cb)(void *user_data,
                               const uint8_t *apdu, uint32_t apdu_len,
                               uint8_t *resp, uint32_t *resp_len);

cie_sign_ctx* cie_sign_ctx_create(const cie_apdu_cb cb, void *user_data,
                                  const uint8_t *atr, size_t atr_len);
void cie_sign_ctx_destroy(cie_sign_ctx*);

typedef struct {
    const uint8_t *input;
    size_t input_len;
    const char *pin;
    size_t pin_len;
    cie_document_type doc_type;
    cie_pdf_options pdf;
    cie_tsa_options tsa;
} cie_sign_request;

cie_status cie_sign_execute(cie_sign_ctx*, const cie_sign_request*, cie_sign_result*);
```

## Test harness
- Creare `tests/mock_token` con un `TokenTransmitCallback` che riproduce la sequenza APDU salvata da sessioni reali (permette test automatizzati).
- Test unitari C++ per:
  - caricamento certificato
  - generazione PKCS#7 su buffer noto (con firma mock)
  - percorso PDF (usando PoDoFo) con `PdfSignatureGenerator`.
- Pipeline CI che compila `ciesign_core` per Linux/macOS con mock per garantire regressioni minime.

## Roadmap tecnica
1. Creare target `ciesign_core` in CMake che include solo i file necessari e non installa strumenti desktop.
2. Rifattorizzare `disigonsdk.cpp` in moduli indipendenti dal file system (nuove API + wrapper legacy).
3. Integrare i nuovi header pubblici (`include/mobile`) con definizioni pulite.
4. Implementare test e mock.
5. Solo dopo procedere con build mobile e binding.
