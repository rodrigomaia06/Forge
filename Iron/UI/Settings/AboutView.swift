//
//  AboutView.swift
//  Forge
//
//  Created by Karim Abou Zeid on 04.03.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            HStack {
                Image("AppIconRounded")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Forge \(versionString)")
                        .font(.headline)

                    // GPL attribution: Forge is a derived work of the open-source Iron app.
                    Text("Based on Iron by Karim Abou Zeid")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .listRowBackground(Color.clear)

            Section {
                Button {
                    UIApplication.shared.open(URL(string: "https://github.com/rodrigomaia06/Forge")!)
                } label: {
                    Label("Source code", image: "github.fill")
                }
            }

            Section(header: Text("Privacy")) {
                Text("Forge keeps your workouts on this iPhone. No account, no server, no tracking.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .navigationBarTitle("About", displayMode: .inline)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        #if DEBUG
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return "\(version ?? "?") (\(build ?? "?")) DEBUG"
        #else
        return "\(version ?? "?")"
        #endif
    }
}

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AboutView().mockEnvironment(weightUnit: .metric)
        }
    }
}
#endif
