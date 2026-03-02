//
//  ContentView.swift
//  DIQRScanner
//
//  Created by Balaji Venkatesh on 01/02/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showScanner: Bool = false
    @State private var scannedCode: String = ""
    var body: some View {
        NavigationStack {
            List {
                Section("Usage") {
                    Text(
                           """
                           **.qrScanner($isScanning) {**
                             // Code
                           **}**
                           """
                    )
                    .monospaced()
                }
                
                Section("Demo") {
                    Button("Show Scanner") {
                        showScanner.toggle()
                    }
                }
                
                Section("Scanned Code") {
                    Text(scannedCode)
                        .monospaced()
                }
            }
            .navigationTitle("QR Scanner")
            .qrScanner(isScanning: $showScanner) { code in
                self.scannedCode = code
            }
        }
    }
}

#Preview {
    ContentView()
}
