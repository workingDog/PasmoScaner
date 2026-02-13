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
            
            Button("Scan") {
                Task {
                    cardModel.clear()
                    await cardModel.scan()
                }
            }.buttonStyle(.borderedProminent)
            
            Spacer()
            
            if let balance = cardModel.balance {
                Text("Balance: ¥\(balance)")
            }
            
            List(cardModel.history) { item in
                HStack {
                    VStack {
                        HStack {
                            Text("¥\(item.balance)")
                            Spacer()
                            Text(item.date.formatted(date: .numeric, time: .omitted))
                        }
                        Label(item.type.title, systemImage: item.type.systemImage)
          //              Label(item.machineType.title, systemImage: item.machineType.systemImage)
                    }
                }
            }
            
            if let error = cardModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
        .padding()
    }
    
}
