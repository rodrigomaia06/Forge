//
//  SettingsView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 11.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI

struct SettingsView : View {
    @EnvironmentObject var settingsStore: SettingsStore
    
    private var mainSection: some View {
        Section {
            NavigationLink(destination: ExerciseMuscleGroupsView()) {
                Text("Exercises")
            }

            NavigationLink(destination: GeneralSettingsView(), isActive: $generalSelected) {
                Text("General")
            }

            NavigationLink(destination: BackupAndExportView()) {
                Text("Backup & Export")
            }
        }
    }
    
    private var aboutSection: some View {
        Section {
            NavigationLink(destination: AboutView()) {
                Text("About")
            }
        }
    }
    
    #if DEBUG
    private var developerSettings: some View {
        Section {
            NavigationLink(destination: DeveloperSettings()) {
                Text("Developer")
            }
        }
    }
    #endif

    var body: some View {
        NavigationStack {
            Form {
                mainSection

                aboutSection

                #if DEBUG
                developerSettings
                #endif
            }
            .forgeScreenTitle("Settings")
        }
    }
    
    // select the general tab by default on iPad
    @State private var generalSelected = UIDevice.current.userInterfaceIdiom == .pad ? true : false
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .mockEnvironment(weightUnit: .metric)
    }
}
#endif
