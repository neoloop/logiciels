import SwiftUI
import MessageUI

struct ReviewRequestView: View {
    let request: EquipmentRequest
    let onValidated: () -> Void

    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var authService: GraphAuthService
    @Environment(\.dismiss) private var dismiss

    private let excelService = GraphExcelService()

    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var pdfData: Data?
    @State private var showMailSheet = false
    @State private var showMailUnavailableAlert = false
    @State private var didFinish = false

    var body: some View {
        Form {
            Section("Demandeur") {
                LabeledContent("Nom", value: request.requesterName)
                LabeledContent("Email", value: request.requesterEmail)
            }
            Section("Bénéficiaire") {
                LabeledContent("Nom", value: request.beneficiaryName)
                LabeledContent("Email", value: request.beneficiaryEmail)
            }
            Section("Matériel") {
                LabeledContent("Type", value: request.equipmentLabel)
            }
            Section("Justification") {
                Text(request.justification)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await validate() }
                } label: {
                    if isProcessing {
                        HStack {
                            ProgressView()
                            Text("Validation en cours…")
                        }
                    } else {
                        Text("Valider la demande")
                    }
                }
                .disabled(isProcessing || didFinish)
            }
        }
        .navigationTitle("Vérifier et valider")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailSheet) {
            if let pdfData {
                MailComposeView(
                    recipients: [request.beneficiaryEmail],
                    ccRecipients: ccRecipients,
                    subject: "Demande de matériel à signer — \(request.equipmentLabel)",
                    body: mailBody,
                    attachmentData: pdfData,
                    attachmentFilename: "Demande_materiel_\(request.beneficiaryName).pdf",
                    onFinish: { _ in
                        didFinish = true
                        onValidated()
                        dismiss()
                    }
                )
            }
        }
        .alert("Mail non configuré", isPresented: $showMailUnavailableAlert) {
            Button("OK", role: .cancel) {
                didFinish = true
                onValidated()
                dismiss()
            }
        } message: {
            Text("La demande a bien été enregistrée dans Excel, mais aucun compte mail n'est configuré sur cet appareil pour envoyer le PDF. Configurez l'app Mail puis renvoyez le PDF manuellement depuis l'historique.")
        }
    }

    private var ccRecipients: [String] {
        var recipients = [request.requesterEmail]
        if !config.validatorEmail.isEmpty {
            recipients.append(config.validatorEmail)
        }
        return recipients
    }

    private var mailBody: String {
        """
        Bonjour \(request.beneficiaryName),

        Vous trouverez ci-joint la demande de matériel (\(request.equipmentLabel)) vous concernant.

        Merci de bien vouloir signer le document ci-joint puis de le renvoyer par retour de mail à \(config.validatorEmail.isEmpty ? "l'expéditeur" : config.validatorEmail).

        Cordialement,
        \(config.validatorName.isEmpty ? "" : config.validatorName)
        """
    }

    private func validate() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let token = try await authService.acquireToken(scopes: config.graphScopes)
            try await excelService.addRow(request, accessToken: token, config: config)

            let pdf = PDFGenerator.makeRequestPDF(for: request, validatorName: config.validatorName)
            self.pdfData = pdf

            if MFMailComposeViewController.canSendMail() {
                showMailSheet = true
            } else {
                showMailUnavailableAlert = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ReviewRequestView(request: EquipmentRequest(), onValidated: {})
            .environmentObject(AppConfig.shared)
            .environmentObject(GraphAuthService.shared)
    }
}
