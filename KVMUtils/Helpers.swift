//
//  Helpers.swift
//  KVMUtils
//
//  Created by Alvin Alford on 23/3/2026.
//

import Foundation
import CoreGraphics
import AppKit
import SwiftUI
import IOKit
import IOKit.usb

struct usbdeviceStruct: Codable, Identifiable, Sendable {
    let id: UUID
    let vendorID: Int?
    let productID: Int?
    let productName: String?
    let serial: String?
    let manufacturer: String?
}

func isSameUSB(_ lhs: usbdeviceStruct, _ rhs: usbdeviceStruct) -> Bool {
    return lhs.productID == rhs.productID &&
           lhs.vendorID == rhs.vendorID &&
           lhs.serial == rhs.serial &&
           lhs.manufacturer == rhs.manufacturer &&
           lhs.productName == rhs.productName
}

func getUSBDevices () -> [usbdeviceStruct] {
    let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
    var iterator: io_iterator_t = 0

    let result = IOServiceGetMatchingServices(
        kIOMainPortDefault,
        matchingDict,
        &iterator
    )

    guard result == KERN_SUCCESS else {
        print("Failed to get USB devices")
        return []
    }

    defer { IOObjectRelease(iterator) }
    var shoppingCart: [usbdeviceStruct]  = []
    while case let device = IOIteratorNext(iterator), device != 0 {
        defer { IOObjectRelease(device) }
        
        var properties: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(device, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
            let props = properties?.takeRetainedValue() as? [String: Any] {
            let vendorID  = props["idVendor"]  as? Int
            let productID = props["idProduct"] as? Int
            let productName = props["USB Product Name"] as? String
            let serial = props["USB Serial Number"] as? String
            let manufacturer = props["USB Vendor Name"] as? String
            print("Vendor ID: \(vendorID ?? -1), Product ID: \(productID ?? -1)")
            shoppingCart.append(usbdeviceStruct(id: UUID(), vendorID: vendorID, productID: productID, productName: productName, serial: serial, manufacturer: manufacturer))
        }

        IOObjectRelease(device)
    }
    return shoppingCart
}

class USBMonitor {
    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    var addedCallback: (usbdeviceStruct) -> Void
    var removedCallback: (usbdeviceStruct) -> Void
    
    init(addedCallback: @escaping (usbdeviceStruct) -> Void, removedCallback: @escaping (usbdeviceStruct) -> Void) {
        self.addedCallback = addedCallback
        self.removedCallback = removedCallback
    }

    func startMonitoring() {
        // Create a notification port
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notificationPort else { return }

        // Add the port's run loop source to the main run loop
        let runLoopSource = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        // Match any USB device
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary

        // --- Device ADDED callback ---
        let addSelf = Unmanaged.passRetained(self)
        IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matchingDict,
            { refCon, iterator in
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refCon!).takeUnretainedValue()
                monitor.handleDeviceAdded(iterator: iterator)
            },
            addSelf.toOpaque(),
            &addedIterator
        )
        // Arm the iterator (drain existing devices on startup)
        handleDeviceAdded(iterator: addedIterator)

        // --- Device REMOVED callback ---
        let removeSelf = Unmanaged.passUnretained(self)
        IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            matchingDict,
            { refCon, iterator in
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refCon!).takeUnretainedValue()
                monitor.handleDeviceRemoved(iterator: iterator)
            },
            removeSelf.toOpaque(),
            &removedIterator
        )
        // Arm the iterator
        handleDeviceRemoved(iterator: removedIterator)
    }

    private func handleDeviceAdded(iterator: io_iterator_t) {
        while case let device = IOIteratorNext(iterator), device != 0 {
            var name = [CChar](repeating: 0, count: 128)
            IORegistryEntryGetName(device, &name)
            let deviceName = String(cString: name)
            print("USB Device Added: \(deviceName)")

            // Optionally read properties
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(device, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                let props = properties?.takeRetainedValue() as? [String: Any] {
                let vendorID  = props["idVendor"]  as? Int
                let productID = props["idProduct"] as? Int
                let productName = props["USB Product Name"] as? String
                let serial = props["USB Serial Number"] as? String
                let manufacturer = props["USB Vendor Name"] as? String
                print("Vendor ID: \(vendorID ?? -1), Product ID: \(productID ?? -1)")
                addedCallback(usbdeviceStruct(id: UUID(), vendorID: vendorID, productID: productID, productName: productName, serial: serial, manufacturer: manufacturer))
            }

            IOObjectRelease(device)
        }
    }

    private func handleDeviceRemoved(iterator: io_iterator_t) {
        while case let device = IOIteratorNext(iterator), device != 0 {
            var name = [CChar](repeating: 0, count: 128)
            IORegistryEntryGetName(device, &name)
            print("USB Device Removed: \(String(cString: name))")
            
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(device, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                let props = properties?.takeRetainedValue() as? [String: Any] {
                let vendorID  = props["idVendor"]  as? Int
                let productID = props["idProduct"] as? Int
                let productName = props["USB Product Name"] as? String
                let serial = props["USB Serial Number"] as? String
                let manufacturer = props["USB Vendor Name"] as? String
                print("Vendor ID: \(vendorID ?? -1), Product ID: \(productID ?? -1)")
                removedCallback(usbdeviceStruct(id: UUID(), vendorID: vendorID, productID: productID, productName: productName, serial: serial, manufacturer: manufacturer))
            }
            
            IOObjectRelease(device)
        }
    }

    func stopMonitoring() {
        if addedIterator != 0   { IOObjectRelease(addedIterator) }
        if removedIterator != 0 { IOObjectRelease(removedIterator) }
        if let port = notificationPort {
            IONotificationPortDestroy(port)
        }
    }
}


struct displayStruct: Codable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let vendorID: CGDirectDisplayID
    let productID: CGDirectDisplayID
    let serialNumber: String
    let bounds: CGRect
    let size: CGSize
    let isMain: Bool
    let ppi: Double
    let displayID: CGDirectDisplayID
}

func isSameDisplay(_ lhs: displayStruct, _ rhs: displayStruct) -> Bool {
    return lhs.productID == rhs.productID &&
           lhs.vendorID == rhs.vendorID &&
           lhs.serialNumber == rhs.serialNumber &&
           lhs.bounds == rhs.bounds &&
           lhs.size == rhs.size &&
           lhs.ppi == rhs.ppi &&
           lhs.displayName == rhs.displayName
}

struct nsDisplayStruct {
    let displayID: CGDirectDisplayID
    let displayName: String
}

func listAllDisplays() -> [displayStruct] {
    var displayCount: UInt32 = 0
    var displays = [CGDirectDisplayID](repeating: 0, count: 256)
    //print(displays)

    let error = CGGetActiveDisplayList(256, &displays, &displayCount)
    var nsDisplays: [nsDisplayStruct] = []
    NSScreen.screens.forEach{ nsDisplays.append(nsDisplayStruct(displayID: $0.cgDirectDisplayID!, displayName: $0.localizedName)) }
    print(nsDisplays)
    if error == .success {
        print("Active displays (\(displayCount)):")
        var shoppingCart: [displayStruct] = []
        for i in 0..<Int(displayCount) {
            let displayID = displays[i]
            let bounds = CGDisplayBounds(displayID)
            let serialNumber = String(CGDisplaySerialNumber(displayID))
            let size = CGDisplayScreenSize(displayID)
            let isMain = CGDisplayIsMain(displayID) != 0
            let vendorID = CGDisplayVendorNumber(displayID)
            let productID = CGDisplayModelNumber(displayID)
            let ppi = Double(CGDisplayPixelsWide(displayID)) / (Double(CGDisplayScreenSize(displayID).width) / 25.4)
            let displayName = nsDisplays.first(where: { $0.displayID == displayID })?.displayName ?? "Unknown"
            
            shoppingCart.append(displayStruct(id: UUID(), displayName: displayName, vendorID: vendorID, productID: productID, serialNumber: serialNumber, bounds: bounds, size: size, isMain: isMain, ppi: ppi, displayID: displayID))
        }
        return shoppingCart
    } else {
        return []
    }
}


class VirtualDisplayManager {
    private var displays: [CGVirtualDisplay] = []
    
    func createVirtualDisplay(
        name: String,
        serialNum: UInt32,
        height: UInt32,
        width: UInt32,
        ppi: Double,
        refreshRate: Double = 60.0
    ) -> CGVirtualDisplay? {
        print("[VDM] createVirtualDisplay called, current displays count: \(displays.count)")
        
        guard let descriptor = CGVirtualDisplayDescriptor() else { return nil }

        descriptor.queue = DispatchQueue.global(qos: .userInteractive)
        descriptor.name = name
        descriptor.whitePoint = CGPoint(x: 0.3125, y: 0.3291)
        descriptor.redPrimary = CGPoint(x: 0.6797, y: 0.3203)
        descriptor.greenPrimary = CGPoint(x: 0.2559, y: 0.6983)
        descriptor.bluePrimary = CGPoint(x: 0.1494, y: 0.0557)

        descriptor.maxPixelsWide = width
        descriptor.maxPixelsHigh = height

        descriptor.sizeInMillimeters = CGSize(
            width: 25.4 * Double(width) / ppi,
            height: 25.4 * Double(height) / ppi
        )

        descriptor.serialNum = serialNum
        descriptor.productID = 0xF0F0
        descriptor.vendorID = 0xF0F0

        guard let display = CGVirtualDisplay(descriptor: descriptor) else {
            print("failed to make vd with descriptor")
            return nil
        }
        
        guard let mode = CGVirtualDisplayMode(
            width: width,
            height: height,
            refreshRate: refreshRate
        ) else { return nil }

        guard let settings = CGVirtualDisplaySettings() else { return nil }

        settings.hiDPI = 1
        settings.modes = [mode]

        if display.applySettings(settings) {
            displays.append(display)
            return display
        } else {
            print("failed to apply settigns")
        }

        return nil
    }

    func mirrorToDisplay(targetDisplayID: CGDirectDisplayID, virtualDisplay: CGVirtualDisplay) {
        
        let displayID = virtualDisplay.displayID
        
        var config: CGDisplayConfigRef?
        var error = CGBeginDisplayConfiguration(&config)

        guard error == .success, let config = config else {
            print("Failed to begin display configuration")
            return
        }

        error = CGConfigureDisplayMirrorOfDisplay(config, targetDisplayID, displayID)

        if error == .success {
            error = CGCompleteDisplayConfiguration(config, .permanently)
            if error == .success {
                print("Successfully configured mirroring")
                return
            } else {
                print("Failed to complete configuration: \(error)")
            }
        } else {
            print("Failed to configure mirroring: \(error)")
            CGCancelDisplayConfiguration(config)
        }
        print("mirror finished")
        return
    }	
    
    func destroyDisplay(_ display: CGVirtualDisplay) {
        guard displays.contains(where: { $0.displayID == display.displayID }) else {
            print("destroyDisplay skipped, display not found")
            return
        }
        
        displays.removeAll { $0.displayID == display.displayID }
        print("destroying display")
        
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct WindowReader: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
