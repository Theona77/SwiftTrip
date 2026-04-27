//
//  BottomActionBar.swift
//  hh
//

import SwiftUI

struct BottomActionBar: View {
    
    // Text Searching
    @Binding var searchText: String
    
    // Ini untuk flow camera, file dan gallery
    var launcher: ScanFlowLauncher

    // Apakah search aktif jadi keyboard muncul
    @FocusState private var isFocused: Bool
    var onFocusChange: ((Bool) -> Void)? = nil

    // dianggap searching jika sedang fokus atau searchText ini ada isinya
    private var isSearching: Bool {
        isFocused || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(isFocused ? .primary : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    // Tap the icon to focus — doesn't block TextField's own tap
                    .onTapGesture { isFocused = true }

                TextField("Search documents", text: $searchText)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit { isFocused = false }

                // Jika focus
                if isFocused {
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }

                    Button("Cancel") {
                        searchText = ""
                        isFocused = false
                    }
                    .font(.subheadline)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            
            
            // Jika tidak searching
            if !isFocused {
                Menu {
                    Button { launcher.show(source: .camera) } label: {
                        Label("Take Picture", systemImage: "camera")
                    }
                    Button { launcher.show(source: .photos) } label: {
                        Label("Photos / Gallery", systemImage: "photo.on.rectangle")
                    }
                    Button { launcher.show(source: .files) } label: {
                        Label("Files", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onChange(of: isFocused) { _, focused in   // also fixed deprecation
            onFocusChange?(focused)
        }
        // ← .onTapGesture removed entirely
        // ← .allowsHitTesting(true) removed (was default anyway)
    }
}
