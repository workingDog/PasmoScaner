//
//  ContentView.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/04.
//
import SwiftUI



struct ContentView: View {
    @State private var cardModel = TransitCardModel()
    
    var body: some View {
        VStack(spacing: 16) {

            Image(systemName: "wave.3.right")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            
            Text("Hold your PASMO near the top of iPhone")
                .font(.headline)
            
            Text("Tap anywhere to scan")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let balance = cardModel.balance {
                Text("Balance: ¥\(balance)")
            }
            
            List(cardModel.history) { item in
                HStack {
                    Text("¥\(item.amount)")
                    Spacer()
                    Text(item.date.formatted(date: .numeric, time: .omitted))
                }
            }
            
            if let error = cardModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
        .padding()
        .contentShape(Rectangle()) // makes whole screen tappable
        .onTapGesture {
            Task {
                cardModel.clear()
                await cardModel.scan()
            }
        }
    }
}
