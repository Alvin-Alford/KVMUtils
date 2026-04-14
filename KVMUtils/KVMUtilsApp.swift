//
//  KVMUtilsApp.swift
//  KVMUtils
//
//  Created by Alvin Alford on 23/3/2026.
//

import SwiftUI
import SwiftData
import Observation
import Foundation
import ServiceManagement


//@Observable
//class AppSettings {
//    var targetUSB: usbdeviceStruct? = nil
//    var targetDisplay: displayStruct? = nil
//}

func toggleLoginItem() {
    let appService = SMAppService.mainApp
    
    do {
        if appService.status == .enabled {
            try appService.unregister()
            print("Unregistered from login items.")
        } else {
            try appService.register()
            print("Registered for login items.")
        }
    } catch {
        print("Failed to toggle login item: \(error.localizedDescription)")
    }
}


@Model
class AppSettings {
    // Store as Data — SwiftData handles Data natively, no transformer needed
    private var targetDisplayData: Data?
    private var targetUSBData: Data?
    
    // Computed wrappers for ergonomic access
    var targetDisplay: displayStruct? {
        get {
            guard let data = targetDisplayData else { return nil }
            return try? JSONDecoder().decode(displayStruct.self, from: data)
        }
        set {
            targetDisplayData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var targetUSB: usbdeviceStruct? {
        get {
            guard let data = targetUSBData else { return nil }
            return try? JSONDecoder().decode(usbdeviceStruct.self, from: data)
        }
        set {
            targetUSBData = try? JSONEncoder().encode(newValue)
        }
    }
    
    init() {}
    
    static func shared(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        let results = try? context.fetch(descriptor)
        if let existing = results?.first { return existing }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}

@main
struct KVMUtilsApp: App {
    let container: ModelContainer = {
        let schema = Schema([AppSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: config)
    }()
    
    //@State private var appSettings = AppSettings()
    
    
    var body: some Scene {
        MenuBarExtra("KVMUtils", systemImage: "display.2") {
            ContentView()
                .frame(width: 300, height: 180)
                //.environment(appSettings)
                .modelContainer(container)
                .onAppear {
                    let appService = SMAppService.mainApp
                    
                    do {
                        if appService.status != .enabled {
                            try appService.register()
                            print("Registered to login items.")
                        }
                    } catch {
                        print("Failed to toggle login item: \(error.localizedDescription)")
                    }
                }
        }
            .menuBarExtraStyle(.window)
        
        Window("Settings", id: "settings") {
            SettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                //.environment(appSettings)
                .modelContainer(container) 
        }
            .defaultSize(width: 500, height: 500)
            .restorationBehavior(.disabled)
            .handlesExternalEvents(matching: ["settings"])
    }
}
