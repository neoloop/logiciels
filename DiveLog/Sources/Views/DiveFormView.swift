import SwiftUI
import SwiftData
import CoreLocation

struct DiveFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()

    var dive: Dive?

    @State private var date: Date = .now
    @State private var depthText: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 45
    @State private var buddies: [String] = []
    @State private var newBuddyName: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var locationName: String?
    @State private var notes: String = ""
    @State private var isLocating = false
    @State private var locationErrorMessage: String?

    private var isEditing: Bool { dive != nil }

    private var isDepthValid: Bool {
        Double(depthText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        Form {
            Section("Date") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Profondeur") {
                HStack {
                    TextField("Profondeur", text: $depthText)
                        .keyboardType(.decimalPad)
                    Text("m")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Durée") {
                Stepper("Heures : \(hours)", value: $hours, in: 0...10)
                Stepper("Minutes : \(minutes)", value: $minutes, in: 0...59, step: 5)
            }

            Section("Lieu") {
                if let locationName {
                    Label(locationName, systemImage: "mappin.and.ellipse")
                } else if let latitude, let longitude {
                    Label("\(latitude, specifier: "%.4f"), \(longitude, specifier: "%.4f")", systemImage: "mappin.and.ellipse")
                }

                Button {
                    captureLocation()
                } label: {
                    if isLocating {
                        ProgressView()
                    } else {
                        Label(
                            latitude == nil ? "Utiliser ma position actuelle" : "Mettre à jour la position",
                            systemImage: "location"
                        )
                    }
                }
                .disabled(isLocating)

                if let locationErrorMessage {
                    Text(locationErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Avec qui") {
                ForEach(buddies, id: \.self) { buddy in
                    Text(buddy)
                }
                .onDelete { offsets in
                    buddies.remove(atOffsets: offsets)
                }

                HStack {
                    TextField("Ajouter un binôme", text: $newBuddyName)
                    Button("Ajouter") {
                        addBuddy()
                    }
                    .disabled(newBuddyName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Notes") {
                TextField("Notes (optionnel)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(isEditing ? "Modifier la plongée" : "Nouvelle plongée")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") { save() }
                    .disabled(!isDepthValid)
            }
        }
        .onAppear(perform: populateFieldsIfNeeded)
    }

    private func populateFieldsIfNeeded() {
        guard let dive else { return }
        date = dive.date
        depthText = String(format: "%.0f", dive.depth)
        hours = dive.durationMinutes / 60
        minutes = dive.durationMinutes % 60
        buddies = dive.buddies
        latitude = dive.latitude
        longitude = dive.longitude
        locationName = dive.locationName
        notes = dive.notes
    }

    private func addBuddy() {
        let trimmed = newBuddyName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        buddies.append(trimmed)
        newBuddyName = ""
    }

    private func captureLocation() {
        isLocating = true
        locationErrorMessage = nil
        Task {
            do {
                let location = try await locationService.requestCurrentLocation()
                latitude = location.coordinate.latitude
                longitude = location.coordinate.longitude
                locationName = await locationService.placemarkName(for: location)
            } catch {
                locationErrorMessage = "Impossible d'obtenir la position. Vérifiez l'accès à la localisation."
            }
            isLocating = false
        }
    }

    private func save() {
        let depthValue = Double(depthText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let totalMinutes = hours * 60 + minutes

        if let dive {
            dive.date = date
            dive.depth = depthValue
            dive.durationMinutes = totalMinutes
            dive.buddies = buddies
            dive.latitude = latitude
            dive.longitude = longitude
            dive.locationName = locationName
            dive.notes = notes
        } else {
            let newDive = Dive(
                date: date,
                depth: depthValue,
                durationMinutes: totalMinutes,
                buddies: buddies,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName,
                notes: notes
            )
            modelContext.insert(newDive)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        DiveFormView(dive: nil)
    }
    .modelContainer(for: Dive.self, inMemory: true)
}
