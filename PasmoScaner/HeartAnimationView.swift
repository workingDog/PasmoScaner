//
//  HeartAnimationView.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/18.
//
import SwiftUI

/*
 
 see  https://github.com/amosgyamfi/open-swiftui-animations
 
 */

struct HeartAnimationView: View {
    @State private var triggerAnimation = false
    let heartCount = 6
    let animationDuration = 1.8
    let staggerInterval = 0.1
    
    var body: some View {
        ForEach(0..<heartCount, id: \.self) { index in
            HeartParticleView(
                trigger: $triggerAnimation,
                index: index,
                duration: animationDuration,
                stagger: staggerInterval
            )
        }
 //       .border(.red)
        .onAppear {
            triggerAnimation = true
        }
    }
}

// Represents a single floating heart particle
struct HeartParticleView: View {
    @Binding var trigger: Bool
    let index: Int
    let duration: Double
    let stagger: Double

    @State private var scale: CGFloat = 0.1
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var isAnimating = false // Internal state to manage loops

    private let xTarget: CGFloat = CGFloat.random(in: -40...40)
    // Ensure yTarget is not zero to avoid division by zero issues, although abs() handles it mathematically
    private let yTarget: CGFloat = CGFloat.random(in: -120 ... -80)
    private let scaleTarget: CGFloat = CGFloat.random(in: 0.7...1.1)

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 25))
            .foregroundColor(.red)
            .scaleEffect(scale)
             // Ensure calculations use CGFloat. abs() returns the same type (CGFloat).
            .offset(x: xTarget * (abs(yOffset) / abs(yTarget)), y: yOffset)
            .opacity(opacity)
            .onChange(of: trigger) {
                 // This logic starts the animation cycle when the parent trigger changes
                if trigger && !isAnimating {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * stagger) {
                        // Check trigger *again* before starting, in case it changed back quickly
                        if self.trigger {
                            startAnimationCycle()
                            isAnimating = true
                        }
                    }
                } else if !trigger {
                     // If trigger becomes false, stop animating
                    isAnimating = false
                    // Optionally reset to initial state immediately when stopped
                    // resetState() // You might want this depending on desired behavior
                }
            }
             // Add an .onAppear for initial setup if needed, though onChange handles the trigger
    }

    func startAnimationCycle() {
        // Only proceed if the view should be animating
        guard isAnimating || trigger else {
            isAnimating = false // Ensure flag is correct if trigger is false
            return
        }

        resetState() // Reset to start values for the new cycle

        withAnimation(.easeOut(duration: duration)) {
            scale = scaleTarget
            yOffset = yTarget
            opacity = 0.0
        }

        // Schedule the *next* cycle check
        DispatchQueue.main.asyncAfter(deadline: .now() + duration ) { // Removed extra 0.05, delay until animation ends
            // Check if we should continue looping
            if self.trigger && self.isAnimating {
                startAnimationCycle() // Loop
            } else {
                // If trigger became false during animation, ensure we stop
                isAnimating = false
                resetState() // Reset state when stopping
            }
        }
    }

    func resetState() {
        scale = 0.1
        yOffset = 0
        opacity = 1.0
    }
}

