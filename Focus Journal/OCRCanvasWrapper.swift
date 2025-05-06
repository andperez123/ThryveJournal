//
//  OCRCanvasWrapper.swift
//  Focus Journal
//
//  Created by Dev-Env    on 4/26/25.
//
import SwiftUI
import PencilKit

struct OCRCanvasWrapper: View {
    let canvas: PKCanvasView

    var body: some View {
        VStack {
            CanvasUIView(canvasView: canvas)
                .frame(maxWidth: .infinity, minHeight: 300)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct CanvasUIView: UIViewRepresentable {
    let canvasView: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        // Configure drawing tools
        let ink = PKInkingTool(.pen, color: .white, width: 3)
        canvasView.tool = ink
        
        // Configure canvas
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        
        // Configure for Apple Pencil
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        
        canvasView.becomeFirstResponder()
        
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update logic if needed
    }
}
