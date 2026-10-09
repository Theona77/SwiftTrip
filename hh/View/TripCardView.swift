import SwiftUI

struct TripCardView: View {
    @EnvironmentObject var vm: HomeViewModel
    let trip: TripModel
    var isEditing: Bool = false
    var onDelete: (() -> Void)? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
               

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Image(trip.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)  
                        .frame(width: 280, height: 160)
                        .clipped()
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 24,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 24
                            )
                        )

                    Button {
                        vm.toggleSaved(for: trip)
                    } label: {
                        Image(systemName: trip.isSaved ? "heart.fill" : "heart")
                            .foregroundStyle(trip.isSaved ? .red : .white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(trip.isSaved ? "Remove \(trip.name) from saved" : "Save \(trip.name)")
                    .padding(10)

                    if isEditing {
                        Button {
                            onDelete?()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                                .background(Color.white.clipShape(Circle()))
                        }
                        .accessibilityLabel("Delete \(trip.name)")
                        .offset(x: -238, y: 10)
                    }
                }
                .frame(width: 280, height: 160)  // Fix 1: explicit frame on ZStack, not inner image only

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.upcomingOpt)
                        .font(.caption.bold())
                        .foregroundStyle(trip.statusColor)   

                    HStack {
                        Text(trip.name).font(.headline)
                        Spacer()
                        Text("\(trip.allDocuments.count) docs")
                            .font(.caption).foregroundStyle(.gray)
                    }

                    Text("\(trip.startDate, style: .date) – \(trip.endDate, style: .date)")
                        .font(.caption).foregroundStyle(.gray)

                    Text("View Documents")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.primary)
                        .foregroundStyle(Color(.systemBackground))
                        .clipShape(Capsule())
                }
                .padding()
            }
            .frame(width: 280)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.05)))
        }
    }
}
