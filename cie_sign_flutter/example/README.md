# CIE Sign Flutter - Example App

App di esempio che dimostra l'utilizzo del plugin `cie_sign_flutter` per la firma digitale di documenti PDF tramite Carta d'Identità Elettronica (CIE).

## Funzionalità

- Firma PDF con CIE via NFC
- Modalità Mock per test senza CIE fisica
- Selezione campi firma esistenti nel PDF
- Firma manuale (disegnata) o automatica (da nominativo CIE)
- Anteprima PDF prima e dopo la firma
- Condivisione del documento firmato

## PDF di Esempio

L'app include due documenti PDF di esempio nella cartella `assets/`:

### sample.pdf - Dichiarazione di Conformità

Documento singola pagina con design professionale:

| Caratteristica | Dettaglio |
|----------------|-----------|
| Pagine | 1 |
| Campi firma | 1 |
| Layout | Header blu, sezioni numerate, box firma stilizzato |

**Campo firma:**
- `Signature1` - Firma digitale principale

**Contenuto:**
- Dichiarazione di conformità per test firma CIE
- Caratteristiche tecniche (algoritmo, formato, certificato)
- Area firma con box azzurro e bordo blu

---

### multipage_contract.pdf - Contratto di Servizio

Documento multi-pagina che simula un contratto professionale completo:

| Caratteristica | Dettaglio |
|----------------|-----------|
| Pagine | 3 |
| Campi firma | 5 |
| Layout | Header blu, footer con numerazione, sezioni strutturate |

**Campi firma per pagina:**

| Pagina | Campo | Descrizione |
|--------|-------|-------------|
| 1 | `Firma_Rappresentante` | Firma del legale rappresentante |
| 2 | `Firma_Cliente` | Firma del cliente |
| 3 | `Firma_Fornitore` | Firma del fornitore |
| 3 | `Firma_Finale` | Firma finale del cliente |
| 3 | `Firma_Testimone` | Firma del testimone |

**Struttura del contratto:**

- **Pagina 1**: Premesse, Oggetto, Durata, Corrispettivo
- **Pagina 2**: Obblighi delle parti, SLA, Responsabilità
- **Pagina 3**: Riservatezza, Risoluzione, Foro competente, Firme finali

## Utilizzo

### Requisiti

- Dispositivo iOS/Android con NFC
- CIE 3.0 (oppure usare la modalità Mock)
- PIN della CIE

### Modalità di Firma

1. **Firma Manuale**: Disegna la tua firma sul pad dedicato
2. **Firma Automatica**: Genera automaticamente la firma dal nominativo presente nella CIE (font Style Script)

### Selezione Campi

Quando si carica un PDF con campi firma esistenti:
- I campi vengono rilevati automaticamente
- È possibile selezionare quali campi firmare
- I campi già firmati sono indicati come tali

## Build

```bash
cd cie_sign_flutter/example
flutter pub get
flutter run
```

### iOS

```bash
cd ios
pod install
cd ..
flutter run -d <device_id>
```

## Struttura

```
example/
├── assets/
│   ├── sample.pdf              # PDF singola pagina
│   ├── multipage_contract.pdf  # PDF multi-pagina (3 pagine, 5 firme)
│   └── signature.png           # Firma di esempio
├── lib/
│   ├── main.dart               # App principale
│   └── pdf_preview_page.dart   # Viewer PDF
└── pubspec.yaml
```
