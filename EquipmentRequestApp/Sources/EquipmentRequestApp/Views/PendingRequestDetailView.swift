import SwiftUI
import MessageUI

/// Détail d'une demande en attente, avec les deux actions possibles : Valider
/// (écrit le statut "Traité", génère le PDF et ouvre le mail pré-rempli) ou
/// Refuser (écrit "Refusée", sans PDF ni mail).
struct PendingRequestDetailView: View {
    let request: JsonEquipmentRequest
    let document: RequestsDocument
    let etag: String?
    let onHandled: () -> Void

    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var authService: GraphAuthService
    @Environment(\.dismiss) private var dismiss

    private let jsonService = GraphJsonService()

    @State private var beneficiaryEmailInput: String
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var pdfData: Data?
    @State private var showMailSheet = false
    @State private var showMailUnavailableAlert = false
    @State private var showRejectConfirmation = false

    init(request: JsonEquipmentRequest, document: RequestsDocument, etag: String?, onHandled: @escaping () -> Void) {
        self.request = request
        self.document = document
        self.etag = etag
        self.onHandled = onHandled
        _beneficiaryEmailInput = State(initialValue: request.beneficiaryEmail)
    }

    private var equipmentRequest: EquipmentRequest {
        request.asEquipmentRequest(overrideBeneficiaryEmail: beneficiaryEmailInput)
    }

    private var canValidate: Bool {
        beneficiaryEmailInput.isValidEmail
    }

    var body: some View {
        Form {
            Section("Demandeur") {
                LabeledContent("Nom", value: request.requesterName)
                LabeledContent("Email", value: request.requesterEmail)
            }
            Section("Bénéficiaire") {
                LabeledContent("Nom", value: request.beneficiaryName)
                TextField("Email du bénéficiaire", text: $beneficiaryEmailInput)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                if !request.phone.isEmpty {
                    LabeledContent("Téléphone", value: request.phone)
                }
            }
            if request.beneficiaryEmail.isEmpty {
                Section {
                    Text("Aucun email de bénéficiaire enregistré pour cette demande. Saisissez-le ci-dessus : il sera enregistré lors de la validation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Matériel") {
                LabeledContent("Type", value: request.equipment)
                if !request.software.isEmpty {
                    LabeledContent("Logiciels", value: request.software)
                }
                if !request.date.isEmpty {
                    LabeledContent("Date de la demande", value: request.date)
                }
            }

            if !request.groupement.isEmpty || !request.opportunity.isEmpty || !request.reference.isEmpty {
                Section("Contexte") {
                    if !request.reference.isEmpty {
                        LabeledContent("Référence", value: request.reference)
                    }
                    if !request.groupement.isEmpty {
                        LabeledContent("Groupement", value: request.groupement)
                    }
                    if !request.opportunity.isEmpty {
                        LabeledContent("Opportunité", value: request.opportunity)
                    }
                }
            }

            Section("Observations") {
                Text(request.justification.isEmpty ? "—" : request.justification)
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
            Text("Le statut sera mis à jour. Aucun mail ne sera envoyé.")
        }
        .sheet(isPresented: $showMailSheet) {
            if let pdfData {
                MailComposeView(
                    recipients: [beneficiaryEmailInput],
                    ccRecipients: ccRecipients,
                    subject: "Demande de matériel à signer — \(request.equipment)",
                    body: mailBody,
                    attachmentData: pdfData,
                    attachmentFilename: "Demande_materiel_\(request.beneficiaryName).pdf",
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
            Text("La demande a bien été validée, mais aucun compte mail n'est configuré sur cet appareil pour envoyer le PDF. Renvoyez-le manuellement.")
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

        Vous trouverez ci-joint la demande de matériel (\(request.equipment)) vous concernant.

        Merci de bien vouloir signer le document ci-joint puis de le renvoyer par retour de mail à \(config.validatorEmail.isEmpty ? "l'expéditeur" : config.validatorEmail).

        Cordialement,
        \(config.validatorName.isEmpty ? "" : config.validatorName)
        """
    }

    private func applyStatusChange(_ status: RequestStatus, updatedBeneficiaryEmail: String?) async throws {
        var updatedDocument = document
        guard let index = updatedDocument.requests.firstIndex(where: { $0.id == request.id }) else { return }
        updatedDocument.requests[index].requestStatus = status
        if let updatedBeneficiaryEmail, !updatedBeneficiaryEmail.isEmpty {
            updatedDocument.requests[index].beneficiaryEmail = updatedBeneficiaryEmail
        }
        let token = try await authService.acquireToken(scopes: config.graphScopes)
        try await jsonService.save(updatedDocument, expectedEtag: etag, accessToken: token, config: config)
    }

    private func validate() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await applyStatusChange(.processed, updatedBeneficiaryEmail: beneficiaryEmailInput)

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
            try await applyStatusChange(.rejected, updatedBeneficiaryEmail: nil)
            onHandled()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
