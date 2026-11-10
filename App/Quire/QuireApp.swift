import SwiftUI

@main
struct QuireApp: App {
    @StateObject private var library = LibraryModel()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(purchases)
                .task {
                    await purchases.load()
                    await library.restoreLibrary()
                }
        }
    }
}
