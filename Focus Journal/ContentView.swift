import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "pencil")
                }

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
        }
    }
}





import PencilKit



#Preview {
    ContentView()
}
