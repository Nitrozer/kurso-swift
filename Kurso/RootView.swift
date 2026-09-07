import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        AppShell()
            .task {
                #if DEBUG
                DebugSeed.run(context: context)
                #endif
            }
    }
}
