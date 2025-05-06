import SwiftUI
import PencilKit
import Vision
import FirebaseAuth


struct AIResponse: Codable {
    let tasks: [String]
    let insights: [String]
}
struct JournalView: View {
    @EnvironmentObject var journalData: JournalData

    @State private var recognizedText1 = ""
    @State private var recognizedText2 = ""
    @State private var recognizedText3 = ""
    @State private var recognizedText4 = ""
    @State private var finalOutput = ""
    @State private var navigationTag: String?
    @State private var isLoading = false
    @State private var scale1: CGFloat = 1.0
    @State private var scale2: CGFloat = 1.0
    @State private var scale3: CGFloat = 1.0
    @State private var scale4: CGFloat = 1.0
    @State private var zoomScales: [CGFloat] = [1.0, 1.0, 1.0, 1.0]
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?

    private let canvas1: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }()
    private let canvas2: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }()
    private let canvas3: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }()
    private let canvas4: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 32) {
                            ForEach(journalQuestions.indices, id: \.self) { index in
                                VStack(spacing: 12) {
                                    journalQuestions[index]
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    OCRCanvasWrapper(canvas: canvases[index])
                                        .scaleEffect(zoomScales[index])
                                        .frame(minHeight: 220, maxHeight: 320)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(uiColor: .secondarySystemBackground))
                                        )
                                        .gesture(
                                            MagnificationGesture()
                                                .onChanged { value in zoomScales[index] = value.magnitude }
                                                .onEnded { value in
                                                    withAnimation(.spring()) {
                                                        zoomScales[index] = min(max(1.0, value), 2.5)
                                                    }
                                                }
                                        )
                                }
                            }
                            .padding(.horizontal, 20)

                            VStack {
                                Button(action: analyzeJournal) {
                                    Text("Analyze Journal")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(journalData.userID == nil ? Color.white.opacity(0.7) : .white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.accentColor.opacity(journalData.userID == nil ? 0.5 : 1.0))
                                        )
                                }
                                .disabled(journalData.userID == nil)
                                .padding(.horizontal, 20)
                                
                                // Use value-based NavigationLink for programmatic navigation
                                // This link is never visible, its value is triggered by setting navigationTag
                                NavigationLink(value: "Dashboard",
                                               label: { EmptyView() })
                                
                            }
                            .frame(maxWidth: .infinity) // Ensure the VStack takes full width for centering
                            .padding(.horizontal, 20) // Apply horizontal padding here
                            .padding(.vertical, 20)
                        }
                        .padding(.top, 40)
                        // Add dynamic bottom padding (adjusted value)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 140)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isLoading {
                        ProgressView("Analyzing your journal...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                            .padding(25)
                            .background(.regularMaterial)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                    }
                }
            }
            .onAppear {
                print("JOURNAL_VIEW: .onAppear triggered")
                // Assign the listener handle to the state variable
                self.authStateHandle = Auth.auth().addStateDidChangeListener { auth, user in
                    if let user = user {
                        // User is signed in (or signed in anonymously)
                        if journalData.userID == nil { // Set it only if not already set
                            journalData.userID = user.uid
                            print("✅ JOURNAL_VIEW [Auth Listener]: UserID set in journalData: \(user.uid)")
                        }
                    } else {
                        // User is signed out
                        if journalData.userID != nil { // Clear it if user signs out
                            journalData.userID = nil
                            print("⚠️ JOURNAL_VIEW [Auth Listener]: User signed out, userID cleared.")
                        }
                    }
                }
            }
            // Add onDisappear to remove the listener
            .onDisappear {
                print("JOURNAL_VIEW: .onDisappear triggered")
                if let handle = authStateHandle {
                    print("JOURNAL_VIEW: Removing Auth listener.")
                    Auth.auth().removeStateDidChangeListener(handle)
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            // Re-add navigationDestination to handle the value type (String)
            .navigationDestination(for: String.self) { value in
                if value == "Dashboard" {
                    DashboardView()
                }
                // Add other destinations if needed
            }
        }
    }

    // Helper arrays
    private var journalQuestions: [Text] {
        [
            Text("What do you want to focus on tomorrow?"),
            Text("What is something you\'re grateful for?"),
            Text("What will you do to feel fulfilled?"),
            Text("What will you do to make progress?")
        ]
    }

    private var canvases: [PKCanvasView] {
        [canvas1, canvas2, canvas3, canvas4]
    }


    // journalPrompt helper removed

    private func runAllOCR(completion: @escaping () -> Void) {
        let dispatchGroup = DispatchGroup()
        
        // Helper function to get image from canvas
        func getImageFromCanvas(_ canvas: PKCanvasView) -> UIImage? {
            if canvas.drawing.bounds.isEmpty { return nil }
            
            let renderer = UIGraphicsImageRenderer(bounds: canvas.bounds)
            let image = renderer.image { context in
                // Ensure a white background
                UIColor.white.setFill()
                context.fill(canvas.bounds)
                
                // Draw the canvas view hierarchy
                canvas.drawHierarchy(in: canvas.bounds, afterScreenUpdates: true)
            }
            
            print("Generated image using drawHierarchy with size: \(image.size)")
            return image
        }
        
        // Process each canvas with debug info
        func processCanvas(_ canvas: PKCanvasView, number: Int, completion: @escaping (String) -> Void) {
            dispatchGroup.enter()
            print("\nProcessing canvas \(number)")
            print("Canvas \(number) drawing strokes: \(canvas.drawing.strokes.count)")
            
            if canvas.drawing.bounds.isEmpty {
                print("Canvas \(number) has no drawing content")
                completion("")
                dispatchGroup.leave()
                return
            }
            
            print("Canvas \(number) has original drawing bounds: \(canvas.drawing.bounds)")
            
            if let image = getImageFromCanvas(canvas) {
                print("Successfully created image for canvas \(number) with size: \(image.size)")
                HandwritingRecognizer.recognizeHandwriting(from: image) { result in
                    if let text = result {
                        print("Canvas \(number) recognized text: '\(text)'")
                        completion(text)
                    } else {
                        print("No text recognized for canvas \(number)")
                        completion("")
                    }
                    dispatchGroup.leave()
                }
            } else {
                print("Failed to create image for canvas \(number)")
                completion("")
                dispatchGroup.leave()
            }
        }
        
        // Process each canvas
        processCanvas(canvas1, number: 1) { text in
            self.recognizedText1 = text
        }
        
        processCanvas(canvas2, number: 2) { text in
            self.recognizedText2 = text
        }
        
        processCanvas(canvas3, number: 3) { text in
            self.recognizedText3 = text
        }
        
        processCanvas(canvas4, number: 4) { text in
            self.recognizedText4 = text
        }

        dispatchGroup.notify(queue: .main) {
            // Update journalData with recognized text
            self.journalData.answer1 = self.recognizedText1
            self.journalData.answer2 = self.recognizedText2
            self.journalData.answer3 = self.recognizedText3
            self.journalData.answer4 = self.recognizedText4
            
            // Debug print
            print("\nFinal recognized texts:")
            print("Answer 1: '\(self.journalData.answer1)'")
            print("Answer 2: '\(self.journalData.answer2)'")
            print("Answer 3: '\(self.journalData.answer3)'")
            print("Answer 4: '\(self.journalData.answer4)'\n")
            
            completion()
        }
    }

    private func analyzeJournal() {
        print("JOURNAL_VIEW: analyzeJournal() called")
        isLoading = true
        
        // 1. Pull a few recent entries for extra context
        let contextLimit = 3   // tweak as you like; 3 keeps the prompt short
        print("JOURNAL_VIEW: Calling fetchRecentEntries(limit: \(contextLimit))…")
        journalData.fetchRecentEntries(limit: contextLimit) { recentEntries in
            print("JOURNAL_VIEW: fetchRecentEntries completion handler. Got \(recentEntries.count) entries.")
            // 2. Run OCR after fetching (whether successful or not)
            print("JOURNAL_VIEW: Calling runAllOCR...")
            runAllOCR { [self] in // Capture self explicitly
                print("JOURNAL_VIEW: runAllOCR completion handler.")
                // 3. Compile text, including previous entry if available
                var compiledText = "Current Entry:\n"
                compiledText += "1. What did you accomplish today?\n\(self.journalData.answer1)\n\n"
                compiledText += "2. What challenged you today?\n\(self.journalData.answer2)\n\n"
                compiledText += "3. What are you grateful for today?\n\(self.journalData.answer3)\n\n"
                compiledText += "4. What do you want to focus on tomorrow?\n\(self.journalData.answer4)\n"

                if !recentEntries.isEmpty {
                    compiledText += "\n\nPrevious \(recentEntries.count) Entries (newest→oldest):\n"
                    for (idx, entry) in recentEntries.enumerated() {
                        compiledText += "\nEntry \(idx + 1):\n"
                        compiledText += "Accomplishments: \(entry["answer1"] as? String ?? "N/A")\n"
                        compiledText += "Challenges: \(entry["answer2"] as? String ?? "N/A")\n"
                        compiledText += "Gratitude: \(entry["answer3"] as? String ?? "N/A")\n"
                        compiledText += "Focus: \(entry["answer4"] as? String ?? "N/A")\n"
                        if let tasks = entry["tasks"] as? [String], !tasks.isEmpty {
                            compiledText += "Tasks: \(tasks.joined(separator: ", "))\n"
                        }
                        if let insights = entry["insights"] as? [String], !insights.isEmpty {
                            compiledText += "Insights: \(insights.joined(separator: ", "))\n"
                        }
                    }
                }

                print("\nJOURNAL_VIEW: Compiled text being sent to AI:\n\(compiledText)\n")
                
                // 4. Send to ChatGPT
                print("JOURNAL_VIEW: Calling sendTextToChatGPT...")
                sendTextToChatGPT(compiledText) { aiResponse in
                    print("JOURNAL_VIEW: sendTextToChatGPT completion handler. AI Response exists: \(aiResponse != nil)")
                    DispatchQueue.main.async {
                        if let aiResponse = aiResponse {
                            self.journalData.tasks = aiResponse.tasks
                            self.journalData.insights = aiResponse.insights
                            // Save the NEW entry data (including AI results)
                            print("JOURNAL_VIEW: Calling saveEntryToFirestore...")
                            self.journalData.saveEntryToFirestore()
                            // Set the tag AFTER data is ready and saved
                            print("JOURNAL_VIEW: Navigating to Dashboard...")
                            self.navigationTag = "Dashboard"
                        } else {
                            print("🔥 JOURNAL_VIEW: Failed to generate AI Response.")
                            self.navigationTag = nil
                        }
                        print("JOURNAL_VIEW: Setting isLoading = false")
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

// MARK: - Other Helper functions remain same

// MARK: - Helper functions outside of JournalView

func recognizeHandwriting(from image: UIImage, completion: @escaping (String?) -> Void) {
    guard let cgImage = image.cgImage else {
        completion(nil)
        return
    }

    let request = VNRecognizeTextRequest { request, error in
        guard error == nil else {
            completion(nil)
            return
        }

        let recognizedStrings = request.results?.compactMap {
            ($0 as? VNRecognizedTextObservation)?
                .topCandidates(1).first?.string
        }

        completion(recognizedStrings?.joined(separator: "\n"))
    }

    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
        try? handler.perform([request])
    }
}

extension PKCanvasView {
    func asImage() -> UIImage {
        let bounds = self.bounds
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { context in
            self.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
    }
}



func sendTextToChatGPT(_ text: String, completion: @escaping (AIResponse?) -> Void) {
    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
        completion(nil)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(APIKeys.openAIKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let messages: [[String: String]] = [
        [
            "role": "system",
            "content": """
You are a personal life assistant. 
Based on the user's journal entries (both the current one and potentially a previous one provided for context), analyze and organize the output into two sections:

1.  Tasks To Accomplish:
    Generate a list of clear, actionable reminders based on the user's *current* entry, considering context from the previous entry if available (e.g., following up on 'focus for tomorrow'). These should be specific tasks the user can complete.

2.  Life Insights:
    Provide 2-3 meaningful observations about recurring patterns, habits, emotions, or goals mentioned across *both* entries if a previous one is provided, or just the current one otherwise. Compare and contrast if possible. These insights should help the user reflect and grow.

Format your entire response as a structured JSON like this:

{
  "tasks": [
    "Task 1",
    "Task 2",
    "Task 3"
  ],
  "insights": [
    "Insight 1",
    "Insight 2",
    "Insight 3"
  ]
}

Only output valid JSON — no extra commentary, no markdown, no explanations.
"""
        ],
        [
            "role": "user",
            "content": text
        ]
    ]

    let parameters: [String: Any] = [
        "model": "gpt-4",
        "messages": messages,
        "temperature": 0.4
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("🔥 Network error occurred: \(error.localizedDescription)")
            completion(nil)
            return
        }

        guard let data = data else {
            print("🚨 No data received from OpenAI")
            completion(nil)
            return
        }

        // Print raw API Response
        if let rawString = String(data: data, encoding: .utf8) {
            print("🔵 Raw OpenAI API Response:")
            print(rawString)
        } else {
            print("🚨 Failed to convert data to string")
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let choices = json?["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String,
               let contentData = content.data(using: .utf8) {

                print("🟣 Parsed content for decoding:")
                print(content)

                let decodedResponse = try JSONDecoder().decode(AIResponse.self, from: contentData)
                completion(decodedResponse)
            } else {
                print("🚨 Could not find 'choices -> message -> content' in JSON response")
                completion(nil)
            }
        } catch {
            print("🚨 Failed to decode AI response: \(error)")
            completion(nil)
        }
    }.resume()
}

