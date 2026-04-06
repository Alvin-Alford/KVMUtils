import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    
    //@Environment(AppSettings.self) var appSettings
    
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]
    
    // Computed to always get-or-create the single instance
    private var appSettings: AppSettings {
        AppSettings.shared(in: context)
    }
    
    @State private var showPopupDisplay: Bool = false
    @State private var showPopupUSB: Bool = false
    @State private var displaysList: [displayStruct] = []
    @State private var usbList: [usbdeviceStruct] = []
    @State private var monitor: USBMonitor? = nil
    
    func handleUSBadd(usb: usbdeviceStruct) {
        print("[Handling] USB added: \(usb.productName ?? "unknown")")
        if !usbList.contains(where: { isSameUSB($0, usb) }) {
            usbList.append(usb)
        }
    }
    
    func handleUSBremove(usb: usbdeviceStruct) {
        print("[Handling] USB removed: \(usb.productName ?? "unknown")")
        usbList.removeAll { isSameUSB($0, usb) }
    }
    
    var body: some View {
        VStack {
            HStack {
                Text(showPopupDisplay ? "Chosing Display" : "Current Target Display")
                    .font(Font.title2.bold())
                
                Button("Choose Display To Mimic") {
                    withAnimation {
                        if showPopupDisplay {
                            showPopupDisplay = false
                        } else {
                            showPopupDisplay = true
                        }
                    }
                    displaysList = listAllDisplays()
                }
            }
            
            if !showPopupDisplay {
                VStack(alignment: .leading) {
                    Text("Display: \(appSettings.targetDisplay?.displayName ?? "No Display Set")")
                    Text("Screen bounds: \(Int(appSettings.targetDisplay?.bounds.width ?? 0))x\(Int(appSettings.targetDisplay?.bounds.height ?? 0))")
                    Text("Serial Number: \(appSettings.targetDisplay?.serialNumber ?? "No Display Set")")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(10)
            }
            
            if showPopupDisplay {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(displaysList) { display in
                            Button {
                                print(display.displayName)
                                appSettings.targetDisplay = display
                                showPopupDisplay = false
                            } label: {
                                VStack(alignment: .leading) {
                                    Text("Display: \(display.displayName)")
                                    Text("Screen bounds: \(Int(display.bounds.width))x\(Int(display.bounds.height))")
                                    Text("Serial Number: \(display.serialNumber)")
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            
            HStack {
                Text(showPopupUSB ? "Chosing USB" : "Current Trigger USB Device")
                    .font(Font.title2.bold())
                
                Button("Choose USB device to trigger") {
                    withAnimation {
                        if showPopupUSB {
                            showPopupUSB = false
                        } else {
                            showPopupUSB = true
                        }
                    }
                    usbList = getUSBDevices()
                }
            }
            
            
            if !showPopupUSB {
                VStack(alignment: .leading) {
                    Text("USB: \(appSettings.targetUSB?.productName ?? "No device Selected")")
                    Text("Manufacturer \(appSettings.targetUSB?.manufacturer ?? "No device Selected")")
                    Text("Serial Number: \(appSettings.targetUSB?.serial ?? "No device Selected")")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(10)
            }
            
            if showPopupUSB {
                Text("Plug in chosen USB device")
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(usbList) { usbDevice in
                            Button {
                                print(usbDevice.productName ?? "Unknown USB Device")
                                appSettings.targetUSB = usbDevice
                                showPopupUSB = false
                            } label: {
                                VStack(alignment: .leading) {
                                    Text("USB: \(usbDevice.productName ?? "Unknown USB Device")")
                                    Text("Manufacturer \(usbDevice.productName ?? "Unknown Manufacturer")")
                                    Text("Serial Number: \(usbDevice.productName ?? "Unknown Serial")")
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            monitor = USBMonitor(addedCallback: handleUSBadd(usb:), removedCallback: handleUSBremove(usb:))
            if let monitor = monitor {
                monitor.startMonitoring()
            }
        }
        .background(
                    WindowReader { window in
                        window.styleMask.remove([.miniaturizable, .resizable])
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                        window.standardWindowButton(.zoomButton)?.isHidden = true
                        window.titleVisibility = .hidden
                        window.titlebarAppearsTransparent = true
                        window.makeKeyAndOrderFront(nil)
                    }
                )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
    }
}
