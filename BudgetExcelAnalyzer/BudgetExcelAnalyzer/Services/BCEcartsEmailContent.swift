import Foundation

/// Builds the subject/HTML body for the "send by email" action on the Écarts BC screen.
enum BCEcartsEmailContent {

    static func subject(scopeLabel: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "fr_FR")
        return "Écarts BC — \(scopeLabel) — \(formatter.string(from: date))"
    }

    static func htmlBody(
        scopeLabel: String,
        missingFromExpression: [BCDiscrepancy],
        missingFromSedit: [BCDiscrepancy],
        crossServiceOrders: [SeditCommandeLine]
    ) -> String {
        """
        <html>
        <body style="font-family:-apple-system,Helvetica,sans-serif;font-size:13px;color:#1a2332;">
          <h2 style="color:#003366;margin-bottom:4px;">Écarts BC — \(escape(scopeLabel))</h2>
          <p style="color:#5a6778;margin-top:0;">Rapprochement Sedit ↔ Expression</p>

          \(table(
            title: "Dans Sedit, pas dans Expression",
            rows: missingFromExpression.map { row(bc: $0.bc, libelle: $0.libelle, montant: $0.montant, service: serviceLabel($0.serviceCode)) }
          ))

          \(table(
            title: "Dans Expression, pas dans Sedit",
            rows: missingFromSedit.map { row(bc: $0.bc, libelle: $0.libelle, montant: $0.montant, service: serviceLabel($0.serviceCode)) }
          ))

          \(table(
            title: "Commandé par un autre service",
            rows: crossServiceOrders.map {
                row(
                    bc: $0.numeroCommande,
                    libelle: $0.libelle,
                    montant: $0.montantTTC,
                    service: "\(serviceLabel($0.serviceCode)) → \(serviceLabel($0.serviceDestinataire))"
                )
            }
          ))
        </body>
        </html>
        """
    }

    private static func table(title: String, rows: [String]) -> String {
        guard !rows.isEmpty else {
            return """
            <h3 style="color:#003366;margin-bottom:4px;">\(escape(title))</h3>
            <p style="color:#5a6778;">Aucun écart.</p>
            """
        }
        return """
        <h3 style="color:#003366;margin-bottom:4px;">\(escape(title)) (\(rows.count))</h3>
        <table cellspacing="0" cellpadding="6" style="border-collapse:collapse;width:100%;margin-bottom:20px;">
          <thead>
            <tr style="background:#f0f2f5;text-align:left;">
              <th>BC</th>
              <th>Libellé</th>
              <th>Service</th>
              <th style="text-align:right">Montant</th>
            </tr>
          </thead>
          <tbody>\(rows.joined())</tbody>
        </table>
        """
    }

    private static func row(bc: String, libelle: String, montant: Double, service: String) -> String {
        """
        <tr>
          <td style="border-bottom:1px solid #eef0f3;">\(escape(bc))</td>
          <td style="border-bottom:1px solid #eef0f3;">\(escape(libelle))</td>
          <td style="border-bottom:1px solid #eef0f3;">\(escape(service))</td>
          <td style="border-bottom:1px solid #eef0f3;text-align:right">\(montant.currencyEUR)</td>
        </tr>
        """
    }

    private static func serviceLabel(_ code: Int?) -> String {
        guard let code else { return "—" }
        return ServiceDisplayOverrides.displayName(forServiceCode: code, fallback: "Service \(code)")
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
