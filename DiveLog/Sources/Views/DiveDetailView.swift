import SwiftUI
import MapKit
import CoreLocation

struct DiveDetailView: View {
    let dive: Dive
    @State private var isPresentingEdit = false

    private var cameraPosition: MapCameraPosition {
        guard let latitude = dive.latitude, let longitude = dive.longitude else {
            return .automatic
        }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        return .region(region)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: DiveFormatters.dateFormatter.string(from: dive.date))
                LabeledContent("Statut", value: dive.status.label)
                LabeledContent("Profondeur", value: DiveFormatters.depth(dive.depth))
                LabeledContent("Durée", value: DiveFormatters.duration(dive.durationMinutes))
            }

            if !dive.buddies.isEmpty {
                Section("Avec qui") {
                    ForEach(dive.buddies, id: \.self) { buddy in
                        Text(buddy)
                    }
                }
            }

            if let latitude = dive.latitude, let longitude = dive.longitude {
                Section(dive.locationName ?? "Position") {
                    Map(position: .constant(cameraPosition)) {
                        Marker(
                            dive.locationName ?? "Plongée",
                            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        )
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                }
            }

            if !dive.notes.isEmpty {
                Section("Notes") {
                    Text(dive.notes)
                }
            }
        }
        .navigationTitle("Détail")
        .toolbar {
            if dive.status == .planned {
                ToolbarItem(placement: .primaryAction) {
                    Button("Réalisée") { dive.status = .completed }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { isPresentingEdit = true }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            NavigationStack {
                DiveFormView(dive: dive)
            }
        }
    }
}
