import SwiftUI
import MessageUI

/// Détail d'une demande en attente, avec les deux actions possibles : Valider
/// (écrit le statut "Traité", génère le PDF et ouvre le mail pré-rempli) ou
/// Refuser (écrit "Refusée", sans PDF ni mail).
struct PendingRequestDetailView: View {
    let row: ExcelEquipmentRequestRow
    let columnMap: ColumnMap
    let onHandled: () -> Void

    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var authService: GraphAuthService
    @Environment(\.dismiss) private var dismiss

    private let excelService = GraphExcelService()

    @State private var beneficiaryEmailInput: String
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var pdfData: Data?
    @State private var showMailSheet = false
    @State private var showMailUnavailableAlert = false
    @State private var showRejectConfirmation = false

    init(row: ExcelEquipmentRequestRow, columnMap: ColumnMap, onHandled: @escaping () -> Void) {
        self.row = row
        self.columnMap = columnMap
        self.onHandled = onHandled
        _beneficiaryEmailInput = State(initialValue: row.beneficiaryEmail)
    }

    private var equipmentRequest: EquipmentRequest {
        row.asEquipmentRequest(overrideBeneficiaryEmail: beneficiaryEmailInput)
    }

    private var canValidate: Bool {
        beneficiaryEmailInput.isValidEmail
    }

    var body: some View {
        Form {
            Section("Demandeur") {
                LabeledContent("Nom", value: row.requesterName)
                LabeledContent("Email", value: row.requesterEmail)
            }
            Section("Bénéficiaire") {
                LabeledContent("Nom", value: row.beneficiaryName)
                TextField("Email du bénéficiaire", text: $beneficiaryEmailInput)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                if !row.phone.isEmpty {
                    LabeledContent("Téléphone", value: row.phone)
                }
            }
            if row.beneficiaryEmail.isEmpty {
                Section {
                    Text("Le tableau Excel ne contient pas encore d'email pour le bénéficiaire. Saisissez-le ci-dessus : il sera aussi enregistré dans Excel lors de la validation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Matériel") {
                LabeledContent("Type", value: row.equipmentLabel)
                if !row.software.isEmpty {
                    LabeledContent("Logiciels", value: row.software)
                }
                if !row.date.isEmpty {
                    LabeledContent("Date de la demande", value: row.date)
                }
            }

            if !row.groupement.isEmpty || !row.opportunity.isEmpty || !row.reference.isEmpty {
                Section("Contexte") {
                    if !row.reference.isEmpty {
                        LabeledContent("Référence", value: row.reference)
                    }
                    if !row.groupement.isEmpty {
                        LabeledContent("Groupement", value: row.groupement)
                    }
                    if !row.opportunity.isEmpty {
                        LabeledContent("Opportunité", value: row.opportunity)
                    }
                }
            }

            Section("Observations") {
                Text(row.justification.isEmpty ? "—" : row.justification)
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
                            Text("Traitement en cours…")
                        }
                    } else {
                        Text("Valider la demande")
                    }
                }
                .disabled(isProcessing || !canValidate)

                Button("Refuser la demande", role: .destructive) {
                    showRejectConfirmation = true
                }
                .disabled(isProcessing)
            }
        }
        .navigationTitle("Demande à valider")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Refuser cette demande ?",
            isPresented: $showRejectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Refuser", role: .destructive) {
                Task { await reject() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le statut sera mis à jour dans Excel. Aucun mail ne sera envoyé.")
        }
        .sheet(isPresented: $showMailSheet) {
            if let pdfData {
                MailComposeView(
                    recipients: [beneficiaryEmailInput],
                    ccRecipients: ccRecipients,
                    subject: "Demande de matériel à signer — \(row.equipmentLabel)",
                    body: mailBody,
                    attachmentData: pdfData,
                    attachmentFilename: "Demande_materiel_\(row.beneficiaryName).pdf",
                    onFinish: { _ in
                        onHandled()
                        dismiss()
                    }
                )
            }
        }
        .alert("Mail non configuré", isPresented: $showMailUnavailableAlert) {
            Button("OK", role: .cancel) {
                onHandled()
                dismiss()
            }
        } message: {
            Text("La demande a bien été validée dans Excel, mais aucun compte mail n'est configuré sur cet appareil pour envoyer le PDF. Renvoyez-le manuellement.")
        }
    }

    private var ccRecipients: [String] {
        var recipients = [row.requesterEmail]
        if !config.validatorEmail.isEmpty {
            recipients.append(config.validatorEmail)
        }
        return recipients
    }

    private var mailBody: String {
        """
        Bonjour \(row.beneficiaryName),

        Vous trouverez ci-joint la demande de matériel (\(row.equipmentLabel)) vous concernant.

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
            try await excelService.updateStatus(
                .processed,
                for: row,
                columnMap: columnMap,
                beneficiaryEmail: beneficiaryEmailInput,
                accessToken: token,
                config: config
            )

            let pdf = PDFGenerator.makeRequestPDF(for: equipmentRequest, validatorName: config.validatorName)
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

    private func reject() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let token = try await authService.acquireToken(scopes: config.graphScopes)
            try await excelService.updateStatus(.rejected, for: row, columnMap: columnMap, accessToken: token, config: config)
            onHandled()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
