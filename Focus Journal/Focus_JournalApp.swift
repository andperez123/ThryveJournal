import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("APP_DELEGATE: Configuring Firebase...")
        FirebaseApp.configure()
        print("APP_DELEGATE: Firebase configured!")
        
        // Attempt anonymous sign-in on launch
        print("APP_DELEGATE: Attempting anonymous sign-in...")
        signInAnonymously()
        
        return true
    }
    
    // Function to handle anonymous sign-in
    func signInAnonymously() {
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("🔥 APP_DELEGATE: Error signing in anonymously: \(error.localizedDescription)")
                print("  -- Full Error Details: \(error)")
                return
            }
            
            guard let user = authResult?.user else {
                print("⚠️ APP_DELEGATE: Anonymous sign-in completed, but no user data received.")
                return
            }
            print("✅ APP_DELEGATE: Signed in anonymously with user ID: \(user.uid)")
            // The userID is now available via Auth.auth().currentUser?.uid
            // Your JournalView's .onAppear will pick this up later.
        }
    }
}

@main
struct Focus_JournalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject var journalData = JournalData()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(journalData)
        }
    }
}
