import Foundation
import FirebaseFirestore
import FirebaseAuth

class JournalData: ObservableObject {
    @Published var userID: String? = nil
    @Published var answer1: String = "" // What did you accomplish today?
    @Published var answer2: String = "" // What challenged you today?
    @Published var answer3: String = "" // What are you grateful for today?
    @Published var answer4: String = "" // What do you want to focus on tomorrow?
    @Published var tasks: [String] = []
    @Published var insights: [String] = []
    @Published var aiSummary: String = ""
    
    func saveEntryToFirestore() {
        print("JOURNAL_DATA: Attempting to save entry...")
        guard let userID = self.userID else {
            print("🔥 JOURNAL_DATA: Error - User ID not set. Cannot save entry.")
            return
        }
        print("JOURNAL_DATA: Saving with UserID: \(userID)")
        let db = Firestore.firestore()

        let data: [String: Any] = [
            "userID": userID,
            "answer1": answer1,
            "answer2": answer2,
            "answer3": answer3,
            "answer4": answer4,
            "tasks": tasks,
            "insights": insights,
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("journalEntries").addDocument(data: data) { error in
            if let error = error {
                print("🔥 JOURNAL_DATA: Error saving journal entry to Firestore: \(error.localizedDescription)")
            } else {
                print("✅ JOURNAL_DATA: Journal entry successfully saved to Firestore!")
            }
        }
    }

    func fetchLatestEntry(completion: @escaping ([String: Any]?) -> Void) {
        print("JOURNAL_DATA: Attempting to fetch latest entry...")
        guard let userID = self.userID else {
            print("⚠️ JOURNAL_DATA: User ID not available for fetching.")
            completion(nil)
            return
        }
        print("JOURNAL_DATA: Fetching for UserID: \(userID)")

        let db = Firestore.firestore()
        db.collection("journalEntries")
          .whereField("userID", isEqualTo: userID)
          .order(by: "timestamp", descending: true)
          .limit(to: 1)
          .getDocuments { (querySnapshot, error) in
              if let error = error {
                  print("🔥 JOURNAL_DATA: Error getting latest document: \(error)")
                  completion(nil)
              } else if let document = querySnapshot?.documents.first {
                  print("✅ JOURNAL_DATA: Successfully fetched latest document ID: \(document.documentID) for user \(userID).")
                  completion(document.data())
              } else {
                  print("ℹ️ JOURNAL_DATA: No previous documents found for user \(userID).")
                  completion(nil)
              }
          }
    }

    /// Returns the last `limit` journal entries for the current user
    /// in **reverse‑chronological** order (newest first).
    func fetchRecentEntries(limit: Int = 3,
                            completion: @escaping ([[String: Any]]) -> Void) {
        print("JOURNAL_DATA: Attempting to fetch last \\(limit) entries…")
        guard let userID = self.userID else {
            print("⚠️ JOURNAL_DATA: User ID not available."); completion([]); return
        }

        Firestore.firestore()
            .collection("journalEntries")
            .whereField("userID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments { snap, err in
                if let err = err {
                    print("🔥 JOURNAL_DATA: Error fetching recent entries – \(err)")
                    completion([])
                } else {
                    // Map DocumentSnapshot to dictionary INCLUDING documentID
                    let docs = snap?.documents.compactMap { doc -> [String: Any]? in
                        var data = doc.data()
                        data["id"] = doc.documentID // Add the document ID here
                        return data
                    } ?? []
                    print("✅ JOURNAL_DATA: Pulled \(docs.count) recent docs.")
                    completion(docs)
                }
            }
    }
}
