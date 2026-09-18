import MessageUI
import SwiftUI

struct ServiceDetailView: View {
    @EnvironmentObject private var store: BudgetDataStore
    let service: ServiceSummary

    @State private var isShowingEmailPrompt = false
    @State private var isShowingMailComposer = false
    @State private var isShowingMailUnavailable = false
    @State private var recipientEmail = ""

    private var nomenclature: [NomenclatureSummary] {
        store.nomenclature(forService: service.serviceCode)
    }
    private var fonctionnement: [NomenclatureSummary] {
        nomenclature.filter { $0.section == .fonctionnement }
    }
    private var investissement: [NomenclatureSummary] {
        nomenclature.filter { $0.section == .investissement }
    }
    private var autre: [NomenclatureSummary] {
        nomenclature.filter { $0.section == .autre }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Budget voté").foregroundStyle(.secondary)
                        Spacer()
                        Text(service.voté.currencyEUR).font(.headline)
                    }
                    ProgressView(value: service.percentEngaged)
                        .tint(service.isOverBudget ? .red : .accentColor)
                    HStack {
                        Text("Engagé : \(service.engagé.currencyEUR)")
                            .foregroundStyle(service.isOverBudget ? .red : .primary)
                        Spacer()
                        Text("Disponible : \(service.disponible.currencyEUR)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }

            if !fonctionnement.isEmpty {
                Section("Fonctionnement") {
                    ForEach(fonctionnement) { NomenclatureRow(summary: $0) }
                }
            }
            if !investissement.isEmpty {
                Section("Investissement") {
                    ForEach(investissement) { NomenclatureRow(summary: $0) }
                }
            }
            if !autre.isEmpty {
                Section("Autre") {
                    ForEach(autre) { NomenclatureRow(summary: $0) }
                }
            }
        }
        .navigationTitle(service.serviceLabel)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    startEmailFlow()
                } label: {
                    Label("Envoyer par email", systemImage: "envelope")
                }
            }
        }
        .sheet(isPresented: $isShowingEmailPrompt) {
            EmailRecipientPromptView(email: $recipientEmail) {
                EmailRecipientStore.save(recipientEmail, forService: service.serviceCode)
                isShowingEmailPrompt = false
                isShowingMailComposer = true
            }
        }
        .sheet(isPresented: $isShowingMailComposer) {
            MailComposeView(
                recipient: recipientEmail,
                subject: BudgetEmailContent.subject(for: service),
                htmlBody: BudgetEmailContent.htmlBody(service: service, nomenclature: nomenclature)
            )
        }
        .alert("Mail non configuré", isPresented: $isShowingMailUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Configure l'app Mail avec un compte pour pouvoir envoyer un email depuis l'app.")
        }
    }

    private func startEmailFlow() {
        guard MFMailComposeViewController.canSendMail() else {
            isShowingMailUnavailable = true
            return
        }
        recipientEmail = EmailRecipientStore.recipient(forService: service.serviceCode) ?? ""
        isShowingEmailPrompt = true
    }
}
