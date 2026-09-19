import SwiftUI

struct NewRequestView: View {
    @State private var request = EquipmentRequest()
    @State private var showReview = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Demandeur (qui fait la demande)") {
                    TextField("Nom complet", text: $request.requesterName)
                        .textContentType(.name)
                    TextField("Email", text: $request.requesterEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Bénéficiaire (pour qui est le matériel)") {
                    TextField("Nom complet", text: $request.beneficiaryName)
                        .textContentType(.name)
                    TextField("Email", text: $request.beneficiaryEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Matériel demandé") {
                    Picker("Type de matériel", selection: $request.equipmentType) {
                        ForEach(EquipmentType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    if request.equipmentType == .other {
                        TextField("Préciser le matériel", text: $request.equipmentOtherDetail)
                    }
                }

                Section("Justification") {
                    TextEditor(text: $request.justification)
                        .frame(minHeight: 100)
                }

                Section {
                    Button("Continuer") {
                        showReview = true
                    }
                    .disabled(!request.isValid)
                }
            }
            .navigationTitle("Demande de matériel")
            .navigationDestination(isPresented: $showReview) {
                ReviewRequestView(request: request, onValidated: {
                    request = EquipmentRequest()
                })
            }
        }
    }
}

#Preview {
    NewRequestView()
        .environmentObject(AppConfig.shared)
        .environmentObject(GraphAuthService.shared)
}
