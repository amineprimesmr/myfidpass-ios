//
//  ContentView.swift
//  CustomBottomBar
//
//  Created by Balaji Venkatesh on 05/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            
            let fillColor = Color.gray.opacity(0.15)
            AnimatedBottomBar(hint: "Type Here", text: $text, isFocused: $isFocused) {
                Button {
                    
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(fillColor, in: .circle)
                }
                
                Button {
                    
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(fillColor, in: .circle)
                }
                
                Button {
                    
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(fillColor, in: .circle)
                }
            } trailingAction: {
                Button {
                    if isFocused {
                        /// Keyboard opened
                        isFocused = false
                    } else {
                        /// Mic Action
                        print("Mic Action")
                    }
                } label: {
                    ZStack {
                        Image(systemName: "checkmark")
                            .fontWeight(.medium)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.green.gradient, in: .circle)
                            .blur(radius: isFocused ? 0 : 5)
                            .opacity(isFocused ? 1 : 0)
                        
                        Image(systemName: "mic.fill")
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(fillColor, in: .circle)
                            .blur(radius: !isFocused ? 0 : 5)
                            .opacity(!isFocused ? 1 : 0)
                    }
                }
            } mainAction: {
                Button {
                    
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 10)
    }
}

#Preview {
    ContentView()
}
