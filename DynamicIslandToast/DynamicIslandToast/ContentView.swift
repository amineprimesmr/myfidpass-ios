//
//  ContentView.swift
//  DynamicIslandToast
//
//  Created by Balaji Venkatesh on 04/01/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showToast: Bool = false
    var body: some View {
        NavigationStack {
            List {
                Section("Usage") {
                    Text(
                    """
                     **.dynamicIslandToast(**
                        isPresented,
                        toast
                    **)**
                    """
                    )
                    .monospaced()
                }
                
                Button("Show Toast") {
                    showToast.toggle()
                }
                .dynamicIslandToast(isPresented: $showToast, value: .example1)
            }
            .navigationTitle("Dynamic Island Toast")
        }
    }
}

#Preview {
    ContentView()
}
