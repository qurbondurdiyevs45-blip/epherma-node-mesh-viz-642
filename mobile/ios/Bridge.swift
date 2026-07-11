import Foundation
import UIKit
import Combine

@objc(EphemeraBridge)
class EphemeraBridge: NSObject {
    
    private var batteryLevelObserver: AnyCancellable?
    private var thermalStateObserver: AnyCancellable?
    
    override init() {
        super.init()
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    @objc
    func getSystemHealth(_ resolve: @escaping (NSDictionary) -> Void, reject: @escaping (String, String, Error?) -> Void) {
        let thermalState = ProcessInfo.processInfo.thermalState
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        let healthData: [String: Any] = [
            "thermalState": stringFromThermalState(thermalState),
            "thermalThrottlingActive": thermalState == .serious || thermalState == .critical,
            "batteryLevel": batteryLevel,
            "batteryState": stringFromBatteryState(batteryState),
            "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        resolve(healthData as NSDictionary)
    }

    @objc
    func getPerformanceMetrics(_ resolve: @escaping (NSDictionary) -> Void, reject: @escaping (String, String, Error?) -> Void) {
        var hostStats = host_basic_info()
        var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &hostStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }

        if result != KERN_SUCCESS {
            reject("E_CPU_INFO", "Failed to bridge host_info stats", nil)
            return
        }

        let metrics: [String: Any] = [
            "processorCount": hostStats.max_cpus,
            "physicalMemoryBytes": ProcessInfo.processInfo.physicalMemory,
            "activeProcessorCount": ProcessInfo.processInfo.activeProcessorCount,
            "systemUptime": ProcessInfo.processInfo.systemUptime
        ]
        
        resolve(metrics as NSDictionary)
    }

    private func stringFromThermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "NOMINAL"
        case .fair: return "FAIR"
        case .serious: return "SERIOUS"
        case .critical: return "CRITICAL"
        @unknown default: return "UNKNOWN"
        }
    }

    private func stringFromBatteryState(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unplugged: return "UNPLUGGED"
        case .charging: return "CHARGING"
        case .full: return "FULL"
        case .unknown: return "UNKNOWN"
        @unknown default: return "UNKNOWN"
        }
    }

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
}