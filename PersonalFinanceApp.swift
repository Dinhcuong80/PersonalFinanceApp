import SwiftUI
import SwiftData

@main
struct PersonalFinanceApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var securityService = SecurityService()
    
    private let dataController = DataController.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if securityService.isUnlocked {
                    MainTabView(securityService: securityService)
                } else {
                    LockScreenView(securityService: securityService)
                }
            }
            .modelContainer(dataController.container)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    securityService.lockAppIfNeeded()
                }
            }
        }
    }
}
