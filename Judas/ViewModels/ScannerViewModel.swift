import Foundation
import Combine

class ScannerViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isScanning = false
    private let networkScanner = NetworkScanner()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        networkScanner.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ipAddresses in
                self?.devices = ipAddresses.map { Device(ipAddress: $0) }
            }
            .store(in: &cancellables)
    }
    
    func startScan() {
        isScanning = true
        networkScanner.startScan()
    }
    
    func stopScan() {
        isScanning = false
        // 实现停止扫描功能
    }
}
