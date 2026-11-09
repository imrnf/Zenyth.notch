//
//  StatsManager.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import Combine
import Darwin
import Foundation
import IOKit
import SwiftUI

@MainActor
final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published var isMonitoring: Bool = false
    @Published var cpuUsage: Double = 0.0          // Percentage 0-100
    @Published var memoryUsage: Double = 0.0       // Percentage 0-100
    @Published var memoryUsedGB: Double = 0.0
    @Published var memoryTotalGB: Double = 0.0
    @Published var gpuUsage: Double = 0.0          // Percentage 0-100
    @Published var networkDownloadMBs: Double = 0.0 // MB/s
    @Published var networkUploadMBs: Double = 0.0   // MB/s
    @Published var diskFreeGB: Double = 0.0
    @Published var diskTotalGB: Double = 0.0

    // History for Sparkline graphs (max 20 data points)
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 15)
    @Published var memoryHistory: [Double] = Array(repeating: 0, count: 15)
    @Published var gpuHistory: [Double] = Array(repeating: 0, count: 15)
    @Published var networkHistory: [Double] = Array(repeating: 0, count: 15)

    private var timer: Timer?
    private var previousCPUInfo: processor_info_array_t?
    private var previousCPUInfoCount: mach_msg_type_number_t = 0
    private var previousNetBytesIn: UInt64 = 0
    private var previousNetBytesOut: UInt64 = 0
    private var previousNetTime: Date = Date()

    private init() {
        let totalMemBytes = ProcessInfo.processInfo.physicalMemory
        self.memoryTotalGB = Double(totalMemBytes) / (1024 * 1024 * 1024)
        updateDiskStats()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        refreshAll()

        timer?.invalidate()
        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        timer?.invalidate()
        timer = nil

        if let prev = previousCPUInfo {
            let prevSize = vm_size_t(previousCPUInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), prevSize)
            previousCPUInfo = nil
            previousCPUInfoCount = 0
        }
    }

    func refreshAll() {
        updateCPUStats()
        updateMemoryStats()
        updateGPUStats()
        updateNetworkStats()
        updateDiskStats()
    }

    // MARK: - CPU
    private func updateCPUStats() {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else { return }

        if let prevInfo = previousCPUInfo {
            var totalUser: UInt64 = 0
            var totalSystem: UInt64 = 0
            var totalIdle: UInt64 = 0
            var totalNice: UInt64 = 0

            for i in 0..<Int(processorCount) {
                let offset = Int32(CPU_STATE_MAX) * Int32(i)
                let user = UInt64(max(0, info[Int(offset + CPU_STATE_USER)] - prevInfo[Int(offset + CPU_STATE_USER)]))
                let sys = UInt64(max(0, info[Int(offset + CPU_STATE_SYSTEM)] - prevInfo[Int(offset + CPU_STATE_SYSTEM)]))
                let idle = UInt64(max(0, info[Int(offset + CPU_STATE_IDLE)] - prevInfo[Int(offset + CPU_STATE_IDLE)]))
                let nice = UInt64(max(0, info[Int(offset + CPU_STATE_NICE)] - prevInfo[Int(offset + CPU_STATE_NICE)]))

                totalUser += user
                totalSystem += sys
                totalIdle += idle
                totalNice += nice
            }

            let totalTicks = totalUser + totalSystem + totalIdle + totalNice
            if totalTicks > 0 {
                let usage = Double(totalUser + totalSystem + totalNice) / Double(totalTicks) * 100.0
                self.cpuUsage = min(100.0, max(0.0, usage))
                self.appendHistory(value: self.cpuUsage, to: &self.cpuHistory)
            }

            let prevSize = vm_size_t(previousCPUInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), prevSize)
        }

        previousCPUInfo = info
        previousCPUInfoCount = processorInfoCount
    }

    // MARK: - Memory
    private func updateMemoryStats() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        let usedGB = Double(used) / (1024 * 1024 * 1024)
        self.memoryUsedGB = usedGB
        if memoryTotalGB > 0 {
            self.memoryUsage = min(100.0, max(0.0, (usedGB / memoryTotalGB) * 100.0))
            self.appendHistory(value: self.memoryUsage, to: &self.memoryHistory)
        }
    }

    // MARK: - GPU
    private func updateGPUStats() {
        let matching = IOServiceMatching(kIOAcceleratorClassName)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = properties?.takeRetainedValue() as? [String: Any],
               let stats = dict["PerformanceStatistics"] as? [String: Any] {
                if let util = stats["Device Utilization %"] as? NSNumber {
                    self.gpuUsage = min(100.0, max(0.0, util.doubleValue))
                    self.appendHistory(value: self.gpuUsage, to: &self.gpuHistory)
                    IOObjectRelease(service)
                    break
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    // MARK: - Network
    private func updateNetworkStats() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = cursor {
            let flags = Int32(current.pointee.ifa_flags)
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let isUp = (flags & IFF_UP) != 0

            if isUp && !isLoopback && current.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = current.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self)
                    totalBytesIn += UInt64(networkData.pointee.ifi_ibytes)
                    totalBytesOut += UInt64(networkData.pointee.ifi_obytes)
                }
            }
            cursor = current.pointee.ifa_next
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(previousNetTime)
        if elapsed > 0.5 && previousNetBytesIn > 0 {
            let deltaIn = totalBytesIn >= previousNetBytesIn ? (totalBytesIn - previousNetBytesIn) : 0
            let deltaOut = totalBytesOut >= previousNetBytesOut ? (totalBytesOut - previousNetBytesOut) : 0

            self.networkDownloadMBs = (Double(deltaIn) / (1024 * 1024)) / elapsed
            self.networkUploadMBs = (Double(deltaOut) / (1024 * 1024)) / elapsed
            self.appendHistory(value: self.networkDownloadMBs, to: &self.networkHistory)
        }

        self.previousNetBytesIn = totalBytesIn
        self.previousNetBytesOut = totalBytesOut
        self.previousNetTime = now
    }

    // MARK: - Disk
    private func updateDiskStats() {
        var stat = statfs()
        if statfs("/", &stat) == 0 {
            let blockSize = UInt64(stat.f_bsize)
            let freeBytes = UInt64(stat.f_bavail) * blockSize
            let totalBytes = UInt64(stat.f_blocks) * blockSize

            self.diskFreeGB = Double(freeBytes) / (1024 * 1024 * 1024)
            self.diskTotalGB = Double(totalBytes) / (1024 * 1024 * 1024)
        }
    }

    private func appendHistory(value: Double, to array: inout [Double]) {
        array.append(value)
        if array.count > 15 {
            array.removeFirst(array.count - 15)
        }
    }
}

