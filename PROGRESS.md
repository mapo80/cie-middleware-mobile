# Progresso Implementazione SDK Mobile

## 2025-11-16

### 1. Abstraction layer per piattaforme native
- Creato il file `cie_sign_sdk/include/mobile/cie_platform.h` contenente le nuove interfacce:
  - `cie_platform_nfc_adapter` per incapsulare apertura, transceive e chiusura della sessione NFC.
  - `cie_platform_logger` per log opzionali.
  - `cie_platform_config` che descrive come inizializzare il contesto (`nfc`, `logger`, fallback legacy).
- Questo layer servirà per implementare gli adapter specifici di iOS (CoreNFC) e Android (NfcAdapter) mantenendo un'unica API C.

### 2. Nuova API di creazione del contesto
- Aggiornato `cie_sign_sdk/include/mobile/cie_sign.h` con la funzione `cie_sign_ctx_create_with_platform`.
- L’implementazione in `cie_sign_sdk/src/mobile/cie_sign_core.cpp`:
  - Supporta sia l’approccio legacy (APDU callback + ATR) sia il nuovo `cie_platform_config`.
  - Gestisce l’apertura/chiusura dell’adapter NFC e instrada le APDU tramite uno shim interno.
  - Archivia eventuale logger per utilizzi futuri (al momento solo memorizzato, non ancora utilizzato dal core).

### 3. Pulizia e compatibilità
- La funzione storica `cie_sign_ctx_create` ora delega alla nuova API garantendo retrocompatibilità.
- In distruzione del contesto viene effettuata la chiusura dell’adapter se definita.

### Prossimi passi
- Utilizzare il logger nella catena di FIRMA (strumentazione errori / tracing).
- Implementare gli adapter NFC reali su Android (Kotlin) e iOS (Swift) sfruttando le nuove strutture.
- Aggiornare i test mock per creare il contesto tramite `cie_sign_ctx_create_with_platform`.
