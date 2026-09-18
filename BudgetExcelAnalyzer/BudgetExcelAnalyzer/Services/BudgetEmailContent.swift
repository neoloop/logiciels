import Foundation

/// Builds the subject/HTML body for the "send by email" action, one per service.
enum BudgetEmailContent {

    static func subject(for service: ServiceSummary, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "fr_FR")
        return "Budget \(service.serviceLabel) — \(formatter.string(from: date))"
    }

    static func htmlBody(service: ServiceSummary, nomenclature: [NomenclatureSummary]) -> String {
        let sections: [BudgetSection] = [.fonctionnement, .investissement, .autre]
        let bodyRows = sections.compactMap { section -> String? in
            let items = nomenclature.filter { $0.section == section }
            guard !items.isEmpty else { return nil }
            return """
            <tr><td colspan="5" style="background:#f0f2f5;font-weight:bold;padding:10px 8px 4px;">\(section.label.uppercased())</td></tr>
            \(items.map(row).joined())
            """
        }.joined()

        return """
        <html>
        <body style="font-family:-apple-system,Helvetica,sans-serif;font-size:13px;color:#1a2332;">
          <h2 style="color:#003366;margin-bottom:4px;">\(escape(service.serviceLabel))</h2>
          <p style="color:#5a6778;margin-top:0;">Situation budgétaire</p>
          <p>
            Budget voté : <strong>\(service.voté.currencyEUR)</strong><br>
            Engagé : <strong>\(service.engagé.currencyEUR)</strong><br>
            Disponible : <strong>\(service.disponible.currencyEUR)</strong>
          </p>
          <table cellspacing="0" cellpadding="6" style="border-collapse:collapse;width:100%;">
            <thead>
              <tr style="background:#f0f2f5;text-align:left;">
                <th>Article</th>
                <th>Nomenclature</th>
                <th style="text-align:right">Voté</th>
                <th style="text-align:right">Engagé</th>
                <th style="text-align:right">Disponible</th>
              </tr>
            </thead>
            <tbody>\(bodyRows)</tbody>
          </table>
        </body>
        </html>
        """
    }

    private static func row(_ item: NomenclatureSummary) -> String {
        """
        <tr>
          <td style="border-bottom:1px solid #eef0f3;">\(escape(item.articleCode))</td>
          <td style="border-bottom:1px solid #eef0f3;">\(escape(item.articleLabel))</td>
          <td style="border-bottom:1px solid #eef0f3;text-align:right">\(item.voté.currencyEUR)</td>
          <td style="border-bottom:1px solid #eef0f3;text-align:right">\(item.engagé.currencyEUR)</td>
          <td style="border-bottom:1px solid #eef0f3;text-align:right">\(item.disponible.currencyEUR)</td>
        </tr>
        """
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
