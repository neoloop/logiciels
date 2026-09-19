import SwiftUI

@main
struct GLPIInterventionsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthViewModel()
    @StateObject private var pushManager = PushNotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(pushManager)
                .onAppear { appDelegate.pushManager = pushManager }
        }
    }
}
