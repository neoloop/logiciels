import UIKit

/// Génère le formulaire PDF de demande de matériel, à faire signer par le bénéficiaire.
enum PDFGenerator {
    static func makeRequestPDF(for request: EquipmentRequest, validatorName: String) -> Data {
        let pageWidth: CGFloat = 595.2 // A4 @ 72dpi
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.boldSystemFont(ofSize: 22)
        let labelFont = UIFont.boldSystemFont(ofSize: 12)
        let valueFont = UIFont.systemFont(ofSize: 13)
        let smallFont = UIFont.systemFont(ofSize: 10)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            func draw(_ text: String, font: UIFont, color: UIColor = .black, spacingAfter: CGFloat = 4) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: attributes,
                    context: nil
                )
                (text as NSString).draw(in: CGRect(x: margin, y: y, width: contentWidth, height: bounding.height), withAttributes: attributes)
                y += bounding.height + spacingAfter
            }

            func drawField(label: String, value: String) {
                draw(label.uppercased(), font: labelFont, color: .darkGray, spacingAfter: 2)
                draw(value.isEmpty ? "—" : value, font: valueFont, spacingAfter: 14)
            }

            func drawSeparator() {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                UIColor.lightGray.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                y += 16
            }

            draw("Demande de matériel", font: titleFont, spacingAfter: 4)
            draw("Générée le \(EquipmentRequest.dateFormatter.string(from: Date()))", font: smallFont, color: .gray, spacingAfter: 20)
            drawSeparator()

            drawField(label: "Date de la demande", value: EquipmentRequest.dateFormatter.string(from: request.date))
            drawField(label: "Type de matériel demandé", value: request.equipmentLabel)

            drawSeparator()
            drawField(label: "Demandeur (personne qui fait la demande)", value: "\(request.requesterName) — \(request.requesterEmail)")
            drawField(label: "Bénéficiaire (personne qui recevra le matériel)", value: "\(request.beneficiaryName) — \(request.beneficiaryEmail)")

            drawSeparator()
            drawField(label: "Justification de la demande", value: request.justification)

            drawSeparator()
            drawField(label: "Validé par", value: validatorName.isEmpty ? "—" : validatorName)

            y += 20
            draw("En signant ci-dessous, le bénéficiaire confirme avoir pris connaissance de cette demande de matériel et accepte les conditions d'utilisation du matériel professionnel.", font: smallFont, color: .darkGray, spacingAfter: 40)

            // Zone de signature.
            let signatureBoxHeight: CGFloat = 90
            let boxWidth = (contentWidth - 24) / 2

            let dateBox = CGRect(x: margin, y: y, width: boxWidth, height: signatureBoxHeight)
            let signatureBox = CGRect(x: margin + boxWidth + 24, y: y, width: boxWidth, height: signatureBoxHeight)

            UIColor.gray.setStroke()
            let boxLinePath = UIBezierPath(rect: dateBox)
            boxLinePath.lineWidth = 0.75
            boxLinePath.stroke()
            UIBezierPath(rect: signatureBox).stroke()

            ("Date" as NSString).draw(
                at: CGPoint(x: dateBox.minX + 6, y: dateBox.minY + 6),
                withAttributes: [.font: labelFont, .foregroundColor: UIColor.darkGray]
            )
            ("Signature du bénéficiaire" as NSString).draw(
                at: CGPoint(x: signatureBox.minX + 6, y: signatureBox.minY + 6),
                withAttributes: [.font: labelFont, .foregroundColor: UIColor.darkGray]
            )
        }
    }
}
