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
        
        VStack(spacing: 5) {
            
            Button {
                Task {
                    cardModel.clear()
                    await cardModel.scan()
                }
            } label: {
                ZStack(alignment: .top) {
                    Image("nekochan")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 270)
                        .frame(maxWidth: .infinity)

                    Text("SCAN")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.blue)
                        .padding(.top, 5)
                }
                .frame(height: 270)
                .clipShape(.rect(cornerRadius: 30))
            }
            .buttonStyle(.plain)

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
                        Label {
                            VStack(alignment: .leading) {
                                Text(item.descriptor.title)
                                Text(item.descriptor.subtitle)
                            }
                        } icon: {
                            Image(systemName: item.descriptor.systemImage)
                                .foregroundStyle(item.descriptor.color)
                        }
                    }
                }
            }
            
            if let error = cardModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }

    }
    
}
