import SwiftUI

struct PaywallView: View {
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.09, blue: 0.11),
                    Color(red: 0.02, green: 0.02, blue: 0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 28) {
                    HStack(spacing: 12) {
                        Circle().fill(Macro.carbs.ringColor).frame(width: 16, height: 16)
                        Circle().fill(Macro.fat.ringColor).frame(width: 16, height: 16)
                    }

                    VStack(spacing: 10) {
                        Text("Unlock Carbs & Fat")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Protein tracking is free forever.\nTrack all three macros with a one-time unlock.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 14) {
                        benefitRow(icon: "circle.circle.fill", color: Macro.carbs.ringColor,
                                   text: "Switch between all three macros on the widget")
                        benefitRow(icon: "target", color: Macro.fat.ringColor,
                                   text: "Set daily carb and fat goals")
                        benefitRow(icon: "checkmark.seal.fill", color: .white.opacity(0.5),
                                   text: "Pay once. No subscription, ever.")
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        Task { await store.purchase() }
                    } label: {
                        Group {
                            if store.isPurchasing {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Unlock for \(store.displayPrice)")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(store.isPurchasing)

                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
    }
}

#Preview {
    PaywallView()
        .preferredColorScheme(.dark)
}
