import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("Your notes") {
                Text("QuireNote stores notebooks in the folder you choose. It does not operate an account system or a cloud service of its own.")
            }
            Section("Data use") {
                Text("Handwriting recognition runs on-device. QuireNote does not collect, sell, or share your notes, handwriting, filenames, or search terms.")
                Text("StoreKit transactions are processed by Apple. QuireNote receives only the entitlement needed to unlock Pro on this device.")
            }
            Section("Support and the full policy") {
                Link("Read the published privacy policy", destination: URL(string: "https://github.com/HectorTa1989/QuireNote-iPadOS/blob/master/PRIVACY.md")!)
                Text("Changes to this policy will be published at the link above before they take effect.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
