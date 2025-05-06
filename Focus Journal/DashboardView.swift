import SwiftUI
import FirebaseFirestore // Import Firestore to use Timestamp

// Model for a Journal Entry, conforming to Identifiable
struct JournalEntry: Identifiable {
    let id: String // Use Firestore document ID or Timestamp string as ID
    let data: [String: Any]

    // Computed properties to access data safely
    var timestamp: Timestamp? { data["timestamp"] as? Timestamp }
    var accomplished: String { data["answer1"] as? String ?? "" }
    var challenged: String { data["answer2"] as? String ?? "" }
    var grateful: String { data["answer3"] as? String ?? "" }
    var focus: String { data["answer4"] as? String ?? "" }
    var aiTasks: [String] { data["tasks"] as? [String] ?? [] }
    var aiInsights: [String] { data["insights"] as? [String] ?? [] }

    // Formatted date string
    var dateFormatted: String {
        guard let ts = timestamp else { return "Date Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: ts.dateValue())
    }
}

struct DashboardView: View {
    @EnvironmentObject var journalData: JournalData // Inject JournalData
    @State private var pastEntries: [JournalEntry] = [] // Use the struct here

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { // Adjusted spacing

                    // ───── Tasks ─────
                    Text("Tasks")
                        .font(.title2.weight(.bold))
                        .padding(.horizontal)

                    if journalData.tasks.isEmpty {
                        EmptyStateCard(message: "No specific tasks identified yet.")
                    } else {
                        // Group tasks within a card-like background
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(journalData.tasks, id: \.self) { task in
                                Text("• \(task)")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // ───── Insights ─────
                    Text("Insights")
                        .font(.title2.weight(.bold))
                        .padding(.horizontal)
                        .padding(.top) // Add some top padding

                    if journalData.insights.isEmpty {
                        EmptyStateCard(message: "No specific insights generated yet.")
                    } else {
                        // Group insights within a card-like background
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(journalData.insights, id: \.self) { tip in
                                Text("• \(tip)")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Divider().padding(.vertical, 16) // Adjusted padding

                    // ───── Past Entries ─────
                    Text("Past Entries")
                        .font(.title2.weight(.bold))
                        .padding(.horizontal)
                        
                    if pastEntries.isEmpty {
                         EmptyStateCard(message: "No past entries found.")
                    } else {
                        // Loop through entries and display using PastEntryCard
                        ForEach(pastEntries) { entry in
                            PastEntryCard(entry: entry)
                        }
                    }
                    
                    Spacer(minLength: 20) // Add spacer at the bottom
                }
                .padding(.top, 16) // Add padding at the top of the VStack
            }
            .background(Color(uiColor: .systemGroupedBackground)) // Add a background to the ScrollView
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                fetchPastEntries()
            }
        }
    }

    private func fetchPastEntries() {
        journalData.fetchRecentEntries(limit: 10) { entries in
            // Map the dictionaries to IdentifiableEntry, using timestamp as ID
            // Filter out any entries missing a valid timestamp
            self.pastEntries = entries.compactMap { dict -> JournalEntry? in
                guard let id = dict["id"] as? String else {
                    print("⚠️ Warning: Past entry missing or has invalid ID.")
                    return nil // Skip entries without a valid ID
                }
                return JournalEntry(id: id, data: dict)
            }
        }
    }
}

// MARK: –‑ Reusable UI Pieces
private struct PillLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.accentColor) // Uses AccentColor
            )
    }
}

private struct EmptyStateCard: View {
    let message: String
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
            .frame(maxWidth: .infinity, minHeight: 60)
            .overlay(
                Text(message)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center),
                alignment: .center
            )
            .padding(.horizontal) // Apply padding here to affect the card itself
    }
}

private struct PastEntryCard: View {
    let entry: JournalEntry // Use the new model
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // headline — date & time
            Text(entry.dateFormatted) // Use computed property
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            Divider()

            // Use the helper for label/value pairs
            LabeledContent("Accomplished", entry.accomplished)
            LabeledContent("Challenged", entry.challenged)
            LabeledContent("Grateful for", entry.grateful)
            LabeledContent("Focus", entry.focus)

            // Use computed properties for tasks/insights
            if !entry.aiTasks.isEmpty {
                PillLabel(text: "AI Tasks")
                Text("• " + entry.aiTasks.joined(separator: "\n• "))
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !entry.aiInsights.isEmpty {
                PillLabel(text: "AI Insights")
                Text("• " + entry.aiInsights.joined(separator: "\n• "))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal) // Apply horizontal padding to the card stack
        .padding(.vertical, 4) // Add vertical padding between cards
    }

    // Helper for tidy label/value pairs
    private func LabeledContent(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption).foregroundColor(.secondary)
            if value.isEmpty {
                Text("—").foregroundColor(.secondary)
            } else {
                Text(value)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(JournalData())
}
