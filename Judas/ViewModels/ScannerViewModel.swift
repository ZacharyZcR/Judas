import SwiftUI
import Combine
import Foundation

class ScannerViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isScanning: Bool = false
    @Published var customSubnet: String = ""
    @Published var scanMessage: String? = nil
    
    var onScanComplete: (() -> Void)? = nil
    
    let networkScanner = NetworkScanner()
    
    // 存储Combine发布者订阅的集合
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 设置监听器以更新设备列表和状态
        setupObservers()
    }
    
    private func setupObservers() {
        // 监听扫描状态变化 - 首要处理
        networkScanner.$isScanningInProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isInProgress in
                guard let self = self else { return }
                print("扫描状态变化: \(isInProgress)")
                self.isScanning = isInProgress
                
                // 当扫描停止时，清除"正在扫描"消息
                if !isInProgress && self.scanMessage == "正在扫描..." {
                    self.scanMessage = nil
                }
            }
            .store(in: &cancellables)
        
        // 监听错误消息
        networkScanner.$scanningErrorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.scanMessage = message
            }
            .store(in: &cancellables)
        
        // 监听网络扫描器发现的设备变化
        networkScanner.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newDevices in
                guard let self = self else { return }
                
                // 将IP地址列表转换为Device对象
                let devicesList = newDevices.map { ip -> Device in
                    return Device(ipAddress: ip)
                }
                
                self.devices = devicesList
            }
            .store(in: &cancellables)
        
        // 自动同步自定义子网值
        $customSubnet
            .sink { [weak self] newValue in
                self?.networkScanner.customSubnet = newValue
            }
            .store(in: &cancellables)
    }
    
    // 开始扫描网络
    func startScan() {
        print("ViewModel: 开始扫描")
        // 先显式设置UI状态，不依赖于回调
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = true
            self?.scanMessage = "正在扫描..."
            // 强制发送对象变更通知
            self?.objectWillChange.send()
        }
        
        // 然后开始实际扫描
        networkScanner.startScan()
    }
    
    // 停止扫描
    func stopScan() {
        print("ViewModel: 停止扫描")
        networkScanner.stopScan()
        
        // 触发完成回调
        DispatchQueue.main.async {
            self.onScanComplete?()
        }
    }
}
