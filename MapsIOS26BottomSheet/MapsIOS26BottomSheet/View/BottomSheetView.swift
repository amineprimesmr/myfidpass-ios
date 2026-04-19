//
//  BottomSheetView.swift
//  MapsIOS26BottomSheet
//
//  Created by Balaji Venkatesh on 27/06/25.
//

import SwiftUI

struct BottomSheetView: View {
    @Binding var sheetDetent: PresentationDetent
    /// Bottom Sheet Properties
    @State private var searchText: String = ""
    @FocusState var isFocused: Bool
    var body: some View {
        ScrollView(.vertical) {
            
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                TextField("Search...", text: $searchText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.gray.opacity(0.25), in: .capsule)
                    .focused($isFocused)
                
                /// Profile/Close Button for Search Field
                Button {
                    if isFocused {
                        isFocused = false
                    } else {
                        /// Profile Button Action
                    }
                } label: {
                    ZStack {
                        if isFocused {
                            Group {
                                if #available(iOS 26, *) {
                                    Image(systemName: "xmark")
                                        .frame(width: 48, height: 48)
                                        .glassEffect(in: .circle)
                                } else {
                                    Image(systemName: "xmark")
                                        .frame(width: 48, height: 48)
                                        .background(.ultraThinMaterial, in: .circle)
                                }
                            }
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary)
                            .transition(.blurReplace)
                        } else {
                            Text("BV")
                                .font(.title2.bold())
                                .frame(width: 48, height: 48)
                                .foregroundStyle(.white)
                                .background(.gray, in: .circle)
                                .transition(.blurReplace)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 80)
            .padding(.top, 5)
        }
        /// Animating Focus Changes
        .animation(.interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0), value: isFocused)
        /// Updating Sheet size when textfield is active
        .onChange(of: isFocused) { oldValue, newValue in
            sheetDetent = newValue ? .large : .height(350)
        }
    }
}
