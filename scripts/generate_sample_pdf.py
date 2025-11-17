#!/usr/bin/env python3
from __future__ import annotations

import io
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from pypdf.generic import (
    ArrayObject,
    DictionaryObject,
    FloatObject,
    NameObject,
    NumberObject,
    TextStringObject,
)
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas


FIELD_NAME = "SignatureField1"


def build_base_pdf() -> io.BytesIO:
    buffer = io.BytesIO()
    c = canvas.Canvas(buffer, pagesize=letter)
    width, height = letter
    margin = 72
    c.setFont("Helvetica-Bold", 22)
    c.drawString(margin, height - margin, "CIE Mobile SDK - Documento di Test")
    c.setFont("Helvetica", 13)
    body = [
        "Questo PDF contiene un campo firma predefinito (SignatureField1).",
        "Il rettangolo rosso indica il punto firma che verra' sostituito dalla grafica.",
        "La firma mock/real andrà posizionata in quell'area.",
    ]
    y = height - margin - 36
    for line in body:
        c.drawString(margin, y, line)
        y -= 18
    placeholder_width = width * 0.4
    placeholder_height = height * 0.12
    placeholder_x = width * 0.1
    placeholder_y = height * 0.1
    c.setStrokeColor(colors.red)
    c.setFillColor(colors.Color(1, 0, 0, alpha=0.05))
    c.setLineWidth(3)
    c.rect(
        placeholder_x,
        placeholder_y,
        placeholder_width,
        placeholder_height,
        stroke=1,
        fill=1,
    )
    c.setFillColor(colors.red)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(
        placeholder_x + 10,
        placeholder_y + placeholder_height - 24,
        "Area firma: SignatureField1",
    )
    c.setFont("Helvetica", 12)
    c.setFillColor(colors.black)
    c.drawString(
        placeholder_x + 10,
        placeholder_y + placeholder_height - 44,
        "Dimensioni: 40% larghezza x 12% altezza (pageIndex=0).",
    )
    c.drawString(
        placeholder_x + 10,
        placeholder_y + 12,
        "L'immagine della firma verra' inserita qui dallo SDK.",
    )
    c.showPage()
    c.save()
    buffer.seek(0)
    return buffer


def add_signature_field(writer: PdfWriter, rect: tuple[float, float, float, float]) -> None:
    page = writer.pages[0]
    if "/Annots" in page:
        annotations = page["/Annots"]
        if not isinstance(annotations, ArrayObject):
            annotations = ArrayObject(annotations)
            page[NameObject("/Annots")] = annotations
    else:
        annotations = ArrayObject()
        page[NameObject("/Annots")] = annotations

    widget = DictionaryObject()
    widget.update(
        {
            NameObject("/Type"): NameObject("/Annot"),
            NameObject("/Subtype"): NameObject("/Widget"),
            NameObject("/FT"): NameObject("/Sig"),
            NameObject("/T"): TextStringObject(FIELD_NAME),
            NameObject("/F"): NumberObject(4),
            NameObject("/Rect"): ArrayObject([FloatObject(v) for v in rect]),
            NameObject("/P"): page.indirect_reference,
        }
    )
    widget_ref = writer._add_object(widget)  # pylint: disable=protected-access
    annotations.append(widget_ref)

    acro_form = writer._root_object.get(NameObject("/AcroForm"))  # pylint: disable=protected-access
    if acro_form is None:
        acro_form = DictionaryObject()
        writer._root_object[NameObject("/AcroForm")] = acro_form  # pylint: disable=protected-access
    fields = acro_form.get(NameObject("/Fields"))
    if fields is None:
        fields = ArrayObject()
        acro_form[NameObject("/Fields")] = fields
    fields.append(widget_ref)
    acro_form[NameObject("/SigFlags")] = NumberObject(3)


def main() -> None:
    buffer = build_base_pdf()
    reader = PdfReader(buffer)
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)

    width, height = letter
    left = width * 0.1
    bottom = height * 0.1
    right = left + (width * 0.4)
    top = bottom + (height * 0.12)
    add_signature_field(writer, (left, bottom, right, top))

    outputs = [
        Path("cie_sign_flutter/example/assets/sample.pdf"),
        Path("cie_sign_sdk/data/fixtures/sample.pdf"),
    ]
    for output in outputs:
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("wb") as fh:
            writer.write(fh)
        print(f"Wrote sample PDF with signature field to {output}")


if __name__ == "__main__":
    main()
