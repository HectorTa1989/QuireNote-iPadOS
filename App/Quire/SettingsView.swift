import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        List {
            Section("QuireNote Pro") {
                if purchases.isPro {
                    Label("Pro is unlocked", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    NavigationLink("Unlock QuireNote Pro") { PaywallView() }
                }
                Button("Restore Purchase") {
                    Task { await purchases.restorePurchases() }
                }
            }

            Section("About") {
                NavigationLink("Privacy") { PrivacyPolicyView() }
                LabeledContent("Version", value: "\(Bundle.main.releaseVersion) (\(Bundle.main.buildVersion))")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Bundle {
    var releaseVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildVersion: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
