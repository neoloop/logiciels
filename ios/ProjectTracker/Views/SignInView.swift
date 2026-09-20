import SwiftUI

struct SignInView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Suivi de projets")
                .font(.title.bold())
            Text("Connectez-vous avec votre compte Microsoft pour synchroniser vos projets avec le classeur Excel sur OneDrive.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button {
                auth.signIn()
            } label: {
                Label("Se connecter avec Microsoft", systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            if let error = auth.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Spacer()
        }
    }
}
