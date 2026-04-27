//
//  CreateTripView.swift
//  hh
//
//  Created by Theona Arlinton on 19/04/26.
//
import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss

    var onAdd: (TripModel) -> Void

    @State private var tripName   = ""
    @State private var startDate  = Date()
    @State private var endDate    = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var description = ""

    var isValid: Bool { !tripName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip Name", text: $tripName)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Date",   selection: $endDate,   displayedComponents: [.date, .hourAndMinute])
                }
                Section("Notes") {
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Create Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newTrip = TripModel(
                            name: tripName,
                            startDate: startDate,
                            endDate: endDate,
                            description: description,
                            imageName: "img_banner",         // default placeholder
                            isSaved: false,
                            categories: CategoryModel.defaultCategories
                        )
                        onAdd(newTrip)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
        }
    }
}
