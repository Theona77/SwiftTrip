//
//  CreateCategoryView.swift
//  hh
//
//  Created by Theona Arlinton on 19/04/26.
//
import SwiftUI

struct CreateCategoryView: View {
    @Environment(\.dismiss) private var dismiss

    var onAdd: (String, String) -> Void

    @State private var categoryName = ""
    @State private var selectedIcon = "folder.fill"

    let icons = [
        "folder.fill", "bed.double.fill", "airplane", "tram.fill",
        "calendar.badge.plus", "figure.hiking", "ticket.fill",
        "car.fill", "fork.knife", "theatermasks.fill",
        "camera.fill", "mappin", "bag.fill", "creditcard.fill", "doc.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Category Name") {
                    TextField("e.g. Hotel, Flight…", text: $categoryName)
                }

                Section("Choose Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 48, height: 48)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.15) : Color(.systemGray6))
                                    .foregroundStyle(selectedIcon == icon ? .blue : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Create Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !categoryName.isEmpty else { return }
                        onAdd(categoryName, selectedIcon)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
