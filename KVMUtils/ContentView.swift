//
//  ContentView.swift
//  KVMUtils
//
//  Created by Alvin Alford on 23/3/2026.
//

import SwiftUI
import SwiftData


struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]
    
    private var appSettings: AppSettings {
        AppSettings.shared(in: context)
    }
    
    @State private var virtualDisplay: CGVirtualDisplay? = nil
    
    @State private var virtualDisplayManager: VirtualDisplayManager = VirtualDisplayManager()
    
    @State private var monitor: USBMonitor? = nil
    @State private var isEnabled = false
    @State private var showPopup: Bool = false
    @State private var displaysList: [displayStruct] = []
    @State private var targetUSB: usbdeviceStruct? = nil
    @State private var targetDisplay: displayStruct? = nil
    
    @State private var isListening: Bool = false
    
    func handleUSBadd(usb: usbdeviceStruct) {
        if isListening {
            print("[CV] USB added: \(usb.productName ?? "unknown")")
            if let targetUSB = appSettings.targetUSB {
                if isSameUSB(targetUSB, usb) {
                    print("[CV] Target USB found, starting KVM")
                    startVirtualDisplay()
                }
            }
        }
    }
    
    func handleUSBremove(usb: usbdeviceStruct) {
        if isListening {
            print("[CV] USB removed: \(usb.productName ?? "unknown")")
            if let targetUSB = appSettings.targetUSB {
                if isSameUSB(targetUSB, usb) {
                    print("[CV] Target USB removed, stoping KVM")
                    stopVirtualDisplay()
                }
            }
        }
    }
    
    func startVirtualDisplay() {
        guard virtualDisplay == nil else {
            print("[CV] startVirtualDisplay called but display already exists, skipping")
            return
        }
        
        print("[CV] starting Display")
        if let targetDisplay = appSettings.targetDisplay {
            if let display = virtualDisplayManager.createVirtualDisplay(name: "VD", serialNum: 1, height: UInt32(targetDisplay.bounds.height), width: UInt32(targetDisplay.bounds.width), ppi: targetDisplay.ppi) {
                
                virtualDisplay = display
                
                Task {
                    virtualDisplayManager.mirrorToDisplay(targetDisplayID: targetDisplay.displayID, virtualDisplay: display)
                }
            }
        }
    }
    
    func stopVirtualDisplay() {
        if let display = self.virtualDisplay {
            self.virtualDisplay = nil
            self.virtualDisplayManager.destroyDisplay(display)
            
        }
        print("[CV] stopped virtual display")
    }
    
    func startListening() {
        isListening = true
        if monitor == nil {
            print("monitor nil")
            monitor = USBMonitor(addedCallback: handleUSBadd(usb:), removedCallback: handleUSBremove(usb:))
            if let monitor = monitor {
                monitor.startMonitoring()
            }
        }
        let currentUSBDevices = getUSBDevices()
        if let targetUSB = appSettings.targetUSB {
            if currentUSBDevices.contains(where: { isSameUSB($0, targetUSB) }) {
                print("target already connected")
                startVirtualDisplay()
            } else {
                print("target not connected when started")
                stopVirtualDisplay()
            }
        }
    }
    
    func stopListening() {
        isListening = false
        print("[CV] stopped listening")
    }
    
    var body: some View {
        ZStack {
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    isEnabled = newValue
                    if !newValue {
                        stopListening()
                        stopVirtualDisplay()
                    } else {
                        startListening()
                    }
                }
            )) {
                Text("KVMUtil is \(isEnabled ? "enabled" : "disabled")")
            }
                .toggleStyle(.switch)
                .padding()
            Button("Settings", systemImage: "gearshape.fill") {
                print("settings")
                openWindow(id: "settings")
            }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .background(.clear)
                .imageScale(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding()
            Button("Quit", systemImage: "power") {
                print("Quit")
                exit(0)
            }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .background(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .imageScale(.large)
                .padding()
        }
        .onAppear {
            if monitor == nil {
                monitor = USBMonitor(addedCallback: handleUSBadd(usb:), removedCallback: handleUSBremove(usb:))
                if let monitor = monitor {
                    monitor.startMonitoring()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
