import SwiftUI

struct BoardingScreen: View {
    var onFinish: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - CONTENT
            TabView(selection: $currentPage) {
                BoardingPage(
                    title: "Access Anytime",
                    subtitle: "Your documents are stored locally and available offline.",
                    image: "doc.text.viewfinder",
                    isSystem: true
                )
                .tag(0)

                BoardingPage(
                    title: "Store & Access",
                    highlighted: "Travel Documents",
                    subtitle: "Quickly, securely, and instantly.",
                    image: "img_boardingscreen",
                    isSystem: false
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // MARK: - DOT INDICATOR
            HStack(spacing: 8) {
                ForEach(0..<2) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.primary : Color.gray.opacity(0.3))
                        .frame(width: index == currentPage ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.35), value: currentPage)
                }
            }
            .padding(.top, 16)

            // MARK: - CTA BUTTON
            Button {
                if currentPage == 0 {
                    withAnimation { currentPage = 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(currentPage == 0 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
            
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .center
            )
        )
    }
}

struct BoardingPage: View {
    var title: String
    var highlighted: String? = nil
    var subtitle: String
    var image: String
    var isSystem: Bool

    @State private var animate = false

    var body: some View {
        VStack(spacing: 20) {

            Spacer()

            // MARK: - IMAGE
            Group {
                if isSystem {
                    Image(systemName: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110)
                        .foregroundStyle(.blue.opacity(0.9))
                } else {
                    Image(image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24)
                }
            }
            .accessibilityHidden(true)   // decorative; the text below carries the message
            .scaleEffect(animate ? 1 : 0.95)
            .opacity(animate ? 1 : 0)
            .animation(.easeOut(duration: 0.5), value: animate)

            // MARK: - TEXT
            VStack(spacing: 8) {

                // TITLE (modern iOS: not too big, semibold)
                Text(highlighted ?? title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)

                // SUBTITLE (proper hierarchy, readable)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
        }
        .onAppear {
            animate = true
        }
    }
}

struct BoardingScreen_Previews: PreviewProvider {
    static var previews: some View {
        BoardingScreen(onFinish: {})
    }
}
