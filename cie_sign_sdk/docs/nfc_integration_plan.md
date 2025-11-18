# NFC Integration Plan (CIE fisica)

## Obiettivo
Portare nell'SDK mobile (Android/iOS/Flutter) la possibilità di firmare un PDF utilizzando una CIE reale, riusando esclusivamente la logica IAS già presente nel core C++ (`cie_sign_sdk`). Il plugin nativo deve limitarsi a fornire il trasporto NFC (`cie_platform_nfc_adapter`) e le opzioni di firma (PDF, PIN, campi firma), così da garantire parità funzionale tra Android e iOS.

## Stato attuale

| Componente | File chiave | Note |
| --- | --- | --- |
| Core IAS C++ | `cie_sign_sdk/src/CSP/IAS.{h,cpp}`, `CIESigner.cpp`, `mobile/cie_sign_core.cpp` | Gestisce selezione AID, DH, PIN verify, firma. Viene istanziato da `cie_sign_ctx_create_with_platform` tramite l'adapter NFC. |
| Bridge Android | `cie_sign_flutter/android/src/main/kotlin/it/ipzs/cie_sign_flutter/CieSignFlutterPlugin.kt`, `android/cieSignSdk/src/main/java/it/ipzs/ciesign/sdk/CieSignSdk.kt`, `android/cieSignSdk/src/main/cpp/nfc_sign_android.cpp` | Il plugin Flutter converte gli argomenti MethodChannel e passa l'`IsoDep` alla JNI. Il bridge C++ crea l'adapter e invoca `cie_sign_execute`. |
| Flutter sample | `cie_sign_flutter/example/lib/main.dart` | UI mock + NFC reale (senza gestione avanzata dello stato lettore). |
| Progetto BPPB di riferimento | `/Users/politom/Downloads/bppb-android-app-master@b023b074cc3/feasdk/src/main/java/it/andreid/feasdk/nfc/*` | Contiene `NFCHelper`, `Ias`, utility APDU. Le parti IAS resteranno in C++, ma il codice serve come riferimento per gestione eventi/UX. |

## Gap identificati

1. **Segnalazione stato NFC**: il plugin Flutter non espone oggi eventi tipo “NFC non supportato”, “in ascolto”, “avvicina la carta”, utili in UI reali.
2. **Logging diagnostico IAS**: i log C++ non sono visibili lato Flutter; per i test con carta fisica servono messaggi sull’intera sequenza IAS (select AID, PIN errato, etc.).
3. **Test/strumentazione reali**: non esiste ancora un test end-to-end che eserciti l’adapter `IsoDep` simulando transcript APDU reali.
4. **Documentazione**: non è descritto come preparare l’ambiente per un test con CIE fisica né come ripristinare il mock.

## Piano di integrazione

1. **Rafforzare l’adapter NFC**
   - Aggiornare `CieSignFlutterPlugin` per pubblicare gli stessi eventi di `NFCHelper` (onListening/onError/onTagDiscovered) verso Dart via MethodChannel secondario.
   - Validare ATR reali in `CieSignSdk.buildAtr()` (storico/higher layer) e aggiungere metriche (es. log `atr.hex()`).
   - Documentare in `PROGRESS.md` e `docs/mobile_architecture.md` come avviene l’iniezione dell’adapter (`cie_platform_nfc_adapter`).

2. **Logging IAS lato core**
   - Integrare il `cie_platform_logger` già presente in `cie_sign_ctx_create_with_platform` per loggare le principali fasi IAS (`IAS::SelectAID_*`, `InitDHParam`, `VerifyPIN`, `Sign`), includendo codici SW.
   - Prevedere flag di build/config (es. `CIE_SIGN_ENABLE_VERBOSE_NFC`) per attivare log solo in debug.

3. **Test NFC mock con transcript reali**
   - Registrare un transcript APDU reale (usando la CIE) e salvarlo in `tests/mock/data/cias_transcript.json`.
   - Estendere `mock_transport.cpp` per riprodurre il transcript quando l’ATR non è `MOCK`, verificando che `cie_sign_execute` completi la firma senza hardware.
   - Aggiornare `tests/mock/mock_sign_test.cpp` con un caso “real transcript” per proteggere regressioni IAS.

4. **Esperienza utente Flutter**
   - In `cie_sign_flutter/example/lib/main.dart`, aggiungere uno stato dedicato per la firma reale:
     - Avvisi se NFC non supportato/attivo.
     - Loader che resta in ascolto finché `onTagDiscovered` non arriva.
     - Messaggi di errore leggibili (PIN errato, carta rimossa).
   - Prevedere la possibilità di cancellare la sessione (già `cancelNfcSigning`) e aggiornarne la UI.

5. **Test manuali con CIE fisica**
   - Scrivere una checklist in `docs/tests_android.md`:
     1. Abilitare NFC sul device.
     2. Avviare `cie_sign_flutter/example`.
     3. Inserire PIN reale.
     4. Avvicinare la carta e monitorare logcat (filtrare `CieSignNfc` + log IAS).
     5. Recuperare il PDF firmato (Download/app path) e verificarlo con `pdfsig` o `cie_sign_sdk/tests`.
   - Fornire un comando `adb logcat | rg CieSignNfc` per supporto debug.

6. **Allineamento iOS**
   - Verificare che `ios/Classes/Bridge/CieSignMobileBridge.mm` passi l’ATR reale (`NFCTagReaderSession` → `NFCISO7816Tag.historicalBytes`).
   - Replicare il logging IAS anche sul bridge iOS (usando `cie_platform_logger`).
   - Aggiornare la documentazione iOS con la procedura per testare su dispositivo reale (CIE + CoreNFC).

7. **Pulizia & fallback**
   - Garantire che, in assenza di hardware, il mock resti funzionante (ATR `MOCK…`).
   - Esporre un flag configurabile da Dart per forzare il mock anche su device reali (utile per demo senza carta).

## Deliverable attesi

- Adapter NFC con eventi/log condivisi.
- Log IAS dettagliati consultabili via `flutter run`/`adb logcat`.
- Test C++ che riproduce un transcript reale senza hardware.
- Documentazione aggiornata (piano + guide Android/iOS).
- Checklist per test manuali con CIE fisica.
