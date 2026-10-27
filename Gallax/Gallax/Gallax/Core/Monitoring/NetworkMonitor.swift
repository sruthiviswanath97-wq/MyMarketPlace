//
//  NetworkMonitor.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation
import Network

protocol NetworkMonitoring: AnyObject {
    var isConnected: Bool { get }
}

@Observable
final class NetworkMonitor: NetworkMonitoring {

    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = true
    private(set) var isExpensive: Bool = false

    @ObservationIgnored
    var onReconnect: (() -> Void)?

    @ObservationIgnored
    private let monitor = NWPathMonitor()
    @ObservationIgnored
    private let queue = DispatchQueue(label: "com.gallax.networkmonitor")
    @ObservationIgnored
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = connected
                self.isExpensive = expensive
                if !wasConnected && connected {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    var statusLabel: String {
        isConnected ? (isExpensive ? "Online · Cellular" : "Online") : "Offline"
    }
}
