import SwiftUI

@main
struct DeckBuilderForHSApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .preferredColorScheme(appModel.preferences.theme.colorScheme)
        }
    }
}
