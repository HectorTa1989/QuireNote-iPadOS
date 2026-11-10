import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                VStack(spacing: 8) {
                    Text("Pay once. Keep your files.")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("The free tier includes three notebooks. Quire Pro unlocks unlimited notebooks with one purchase—no subscription.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await purchases.purchasePro() }
                } label: {
                    HStack {
                        if purchases.isPurchasing { ProgressView().tint(.white) }
                        Text("Unlock Pro — \(purchases.proProduct?.displayPrice ?? "$19.99")")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchases.proProduct == nil || purchases.isPurchasing)

                Button("Restore Purchase") {
                    Task { await purchases.restorePurchases() }
                }
                Text("Family Sharing supported when enabled for the App Store product.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .navigationTitle("Quire Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: purchases.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }
}
