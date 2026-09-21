import MessageUI
import SwiftUI

struct CommandesContentView: View {
    @EnvironmentObject private var store: CommandesDataStore
    @EnvironmentObject private var budgetStore: BudgetDataStore
    @EnvironmentObject private var seditStore: SeditDataStore
    @Binding var isShowingFilePicker: Bool
    @State private var isShowingSeditFilePicker = false
    @State private var selectedServiceCode: Int?
    @State private var selectedTab: Tab = .projets

    @State private var isShowingEmailPrompt = false
    @State private var isShowingMailComposer = false
    @State private var isShowingMailUnavailable = false
    @State private var recipientEmail = ""

    private enum Tab: String, CaseIterable {
        case projets = "Projets"
        case commandes = "Commandes"
        case ecarts = "Écarts BC"
    }

    private var filteredCommandes: [CommandeLine] { store.commandes(forService: selectedServiceCode) }
    private var filteredProjets: [ProjetLine] { store.projets(forService: selectedServiceCode) }

    /// Voté/Dispo per nomenclature for Investissement, cross-referenced from the main budget
    /// file (Situation Budgétaire) and filtered to the same selected service as the projects.
    private var investissementNomenclature: [NomenclatureSummary] {
        let items = selectedServiceCode.map { budgetStore.nomenclature(forService: $0) } ?? budgetStore.consolidatedNomenclature
        return items.filter { $0.section == .investissement }
    }

    private func filteredByService(_ items: [BCDiscrepancy]) -> [BCDiscrepancy] {
        guard let selectedServiceCode else { return items }
        return items.filter { $0.serviceCode == selectedServiceCode }
    }

    private var missingFromExpression: [BCDiscrepancy] {
        filteredByService(BCReconciliation.inSeditNotExpression(sedit: seditStore.commandes, expression: store.commandes(forService: nil)))
    }
    private var missingFromSedit: [BCDiscrepancy] {
        filteredByService(BCReconciliation.inExpressionNotSedit(expression: store.commandes(forService: nil), sedit: seditStore.commandes))
    }

    /// Sedit lines where the paying service ("Service Gestionnaire") differs from the
    /// ordering service ("Service Destinataire") — i.e. another service ordered against
    /// this budget. When a service is selected, restricted to orders charged to *its*
    /// budget (so you see who ordered on you, not the other direction).
    private var crossServiceOrders: [SeditCommandeLine] {
        let items = seditStore.commandes.filter {
            guard let gestionnaire = $0.serviceCode, let destinataire = $0.serviceDestinataire else { return false }
            return gestionnaire != destinataire
        }
        guard let selectedServiceCode else { return items }
        return items.filter { $0.serviceCode == selectedServiceCode }
    }

    /// Sedit lines where the issuing service ("Service émetteur") differs from the
    /// billed service ("Service de facturation"). When a service is selected, restricted
    /// to lines involving it in either role.
    private var emetteurFacturationMismatches: [SeditCommandeLine] {
        let items = seditStore.commandes.filter {
            guard let emetteur = $0.serviceEmetteur, let facturation = $0.serviceFacturation else { return false }
            return emetteur != facturation
        }
        guard let selectedServiceCode else { return items }
        return items.filter { $0.serviceEmetteur == selectedServiceCode || $0.serviceFacturation == selectedServiceCode }
    }

    /// Union of every service code seen anywhere: Expression/PPI (store.serviceCodes) plus
    /// whatever service fields show up in Sedit, even if they're services that never
    /// appear in Expression itself.
    private var allServiceCodes: [Int] {
        var codes = Set(store.serviceCodes)
        codes.formUnion(seditStore.commandes.compactMap(\.serviceCode))
        codes.formUnion(seditStore.commandes.compactMap(\.serviceDestinataire))
        codes.formUnion(seditStore.commandes.compactMap(\.serviceEmetteur))
        codes.formUnion(seditStore.commandes.compactMap(\.serviceFacturation))
        return codes.sorted { ServiceDisplayOverrides.sortRank(forServiceCode: $0) < ServiceDisplayOverrides.sortRank(forServiceCode: $1) }
    }

    private var scopeLabel: String {
        selectedServiceCode.map { store.serviceDisplayName($0) } ?? "Tous les services"
    }
    private var ecartsEmailKey: String {
        "ecarts.\(selectedServiceCode.map(String.init) ?? "all")"
    }

    var body: some View {
        List {
            Section {
                Picker("Vue", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if allServiceCodes.count > 1 {
                    Picker("Service", selection: $selectedServiceCode) {
                        Text("Tous les services").tag(Int?.none)
                        ForEach(allServiceCodes, id: \.self) { code in
                            Text(store.serviceDisplayName(code)).tag(Int?.some(code))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            switch selectedTab {
            case .projets:
                Section("Projets (\(filteredProjets.count))") {
                    if filteredProjets.isEmpty {
                        Text("Aucun projet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredProjets) { ProjetRow(projet: $0) }
                    }
                }
                if !investissementNomenclature.isEmpty {
                    Section("Budget Investissement — Voté / Dispo") {
                        ForEach(investissementNomenclature) { NomenclatureRow(summary: $0) }
                    }
                }
            case .commandes:
                Section("Commandes (\(filteredCommandes.count))") {
                    if filteredCommandes.isEmpty {
                        Text("Aucune commande")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredCommandes) { CommandeRow(commande: $0) }
                    }
                }
            case .ecarts:
                if seditStore.commandes.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compare le fichier Sedit avec Expression")
                                .font(.headline)
                            Text("Importe l'export Sedit (.xlsx) pour voir les commandes qui ne se retrouvent pas dans les deux fichiers, rapprochées par numéro de BC.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                isShowingSeditFilePicker = true
                            } label: {
                                Label("Choisir le fichier Sedit", systemImage: "folder")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section("Dans Sedit, pas dans Expression (\(missingFromExpression.count))") {
                        if missingFromExpression.isEmpty {
                            Text("Aucun écart")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(missingFromExpression) { BCDiscrepancyRow(discrepancy: $0) }
                        }
                    }
                    Section("Dans Expression, pas dans Sedit (\(missingFromSedit.count))") {
                        if missingFromSedit.isEmpty {
                            Text("Aucun écart")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(missingFromSedit) { BCDiscrepancyRow(discrepancy: $0) }
                        }
                    }
                    Section("Commandé par un autre service (\(crossServiceOrders.count))") {
                        if crossServiceOrders.isEmpty {
                            Text("Aucune commande inter-services")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(crossServiceOrders) {
                                SeditServiceMismatchRow(order: $0, fromCode: $0.serviceCode, fromLabel: "Budget", toCode: $0.serviceDestinataire, toLabel: "Commandé par")
                            }
                        }
                    }
                    Section("Émetteur ≠ Facturation (\(emetteurFacturationMismatches.count))") {
                        if emetteurFacturationMismatches.isEmpty {
                            Text("Aucun écart émetteur/facturation")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(emetteurFacturationMismatches) {
                                SeditServiceMismatchRow(order: $0, fromCode: $0.serviceEmetteur, fromLabel: "Émis par", toCode: $0.serviceFacturation, toLabel: "Facturé à")
                            }
                        }
                    }
                    Section {
                        Button {
                            isShowingSeditFilePicker = true
                        } label: {
                            Label("Réimporter le fichier Sedit", systemImage: "arrow.clockwise")
                        }
                        if let lastImportDate = seditStore.lastImportDate {
                            VStack(alignment: .leading, spacing: 4) {
                                if let name = seditStore.sourceFileName {
                                    Text(name).font(.caption).foregroundStyle(.secondary)
                                }
                                Text("Importé le \(lastImportDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if selectedTab != .ecarts, let lastImportDate = store.lastImportDate {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        if let name = store.sourceFileName {
                            Text(name).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Importé le \(lastImportDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable {
            // See DashboardView: re-reading via the saved bookmark can silently serve a
            // stale cached copy with third-party providers like OneDrive, so reopen the
            // live picker instead of relying on it. Reopens whichever file the current tab
            // actually shows.
            if selectedTab == .ecarts {
                isShowingSeditFilePicker = true
            } else {
                isShowingFilePicker = true
            }
        }
        .toolbar {
            if selectedTab == .ecarts && !seditStore.commandes.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startEmailFlow()
                    } label: {
                        Label("Envoyer par email", systemImage: "envelope")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingFilePicker = true
                } label: {
                    Label("Importer", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingSeditFilePicker,
            allowedContentTypes: [.excelWorkbook, .xlsxExtension, .legacyExcelWorkbook, .xlsExtension],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await seditStore.importFile(from: url) }
                }
            case .failure(let error):
                seditStore.errorMessage = error.localizedDescription
            }
        }
        .overlay {
            if seditStore.isImporting {
                ProgressView("Lecture du fichier Sedit…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(
            "Erreur Sedit",
            isPresented: Binding(
                get: { seditStore.errorMessage != nil },
                set: { if !$0 { seditStore.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(seditStore.errorMessage ?? "")
        }
        .sheet(isPresented: $isShowingEmailPrompt) {
            EmailRecipientPromptView(email: $recipientEmail) {
                EmailRecipientStore.save(recipientEmail, forKey: ecartsEmailKey)
                isShowingEmailPrompt = false
                isShowingMailComposer = true
            }
        }
        .sheet(isPresented: $isShowingMailComposer) {
            MailComposeView(
                recipient: recipientEmail,
                subject: BCEcartsEmailContent.subject(scopeLabel: scopeLabel),
                htmlBody: BCEcartsEmailContent.htmlBody(
                    scopeLabel: scopeLabel,
                    missingFromExpression: missingFromExpression,
                    missingFromSedit: missingFromSedit,
                    crossServiceOrders: crossServiceOrders,
                    emetteurFacturationMismatches: emetteurFacturationMismatches
                )
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
        recipientEmail = EmailRecipientStore.recipient(forKey: ecartsEmailKey) ?? ""
        isShowingEmailPrompt = true
    }
}
