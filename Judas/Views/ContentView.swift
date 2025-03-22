import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var selectedTab = 0
    // 添加一个本地状态来直接控制UI
    @State private var isScanning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // 网络状态卡片
                networkStatusCard
                
                // 扫描类型选择器
                scanTypePicker
                
                // 主内容区域
                ZStack {
                    // 重要改动：使用本地isScanning状态控制视图
                    if isScanning {
                        // 扫描中状态
                        scanningView
                    } else if viewModel.devices.isEmpty {
                        // 空状态
                        emptyStateView
                    } else {
                        // 结果状态
                        deviceListView
                    }
                }
                .frame(maxHeight: .infinity)
                
                // 操作按钮 - 使用本地状态控制
                scanButtonView
                    .padding(.bottom, 8)
            }
            .padding(.horizontal)
            .navigationTitle("Judas 网络扫描")
            .onAppear {
                viewModel.networkScanner.getCurrentIPAddress()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .refreshable {
                viewModel.networkScanner.getCurrentIPAddress()
            }
        }
    }
    
    // 网络状态卡片
    private var networkStatusCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(viewModel.networkScanner.isNetworkConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(viewModel.networkScanner.isNetworkConnected ? "网络已连接" : "网络未连接")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.networkScanner.getCurrentIPAddress()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                if viewModel.networkScanner.isNetworkConnected {
                    Divider().padding(.vertical, 4)
                    
                    HStack(spacing: 12) {
                        networkInfoItem(title: "IP地址", value: viewModel.networkScanner.currentIPAddress)
                        
                        Spacer()
                        
                        networkInfoItem(title: "子网", value: viewModel.networkScanner.currentSubnet)
                    }
                }
                
                // 错误信息或状态消息
                if let message = viewModel.scanMessage {
                    Divider().padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: isScanning ? "hourglass" : "exclamationmark.triangle.fill")
                            .foregroundColor(isScanning ? .blue : .red)
                        
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(isScanning ? .blue : .red)
                    }
                    .padding(8)
                    .background(Color(isScanning ? .blue : .red).opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.top)
    }
    
    // 网络信息项
    private func networkInfoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
        }
    }
    
    // 扫描类型选择器
    private var scanTypePicker: some View {
        Picker("扫描模式", selection: $selectedTab) {
            Text("当前网络").tag(0)
            Text("自定义子网").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .disabled(isScanning)
        .onChange(of: selectedTab) { newValue in
            viewModel.networkScanner.scanType = newValue == 0 ? .localSubnet : .customSubnet
        }
    }
    
    // 扫描中视图
    private var scanningView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                    // 添加脉冲动画效果
                    .symbolEffect(.pulse)
                
                Text(selectedTab == 0 ? "正在扫描当前网络..." : "正在扫描自定义网络...")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 8)
                
                if !viewModel.devices.isEmpty {
                    Text("已发现 \(viewModel.devices.count) 个设备")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(12)
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: selectedTab == 0 ? "network" : "wifi.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 120, height: 120)
                    )
                
                Text(selectedTab == 0 ?
                    (viewModel.networkScanner.isNetworkConnected ? "尚未发现设备" : "未连接到网络") :
                     "尚未进行扫描")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(12)
    }
    
    // 设备列表视图
    private var deviceListView: some View {
        List {
            Section(header:
                HStack {
                    Text("发现的设备")
                    Spacer()
                    Text("\(viewModel.devices.count)个设备")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            ) {
                ForEach(viewModel.devices) { device in
                    NavigationLink(destination: DeviceDetailView(device: device)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "network")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.ipAddress)
                                    .font(.system(size: 16, weight: .medium))
                                
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    Text("设备在线")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = device.ipAddress
                        }) {
                            Label("复制IP地址", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // 自定义输入视图
    private var customInputView: some View {
        Group {
            if selectedTab == 1 {
                GroupBox {
                    HStack {
                        Image(systemName: "network.badge.shield.half.filled")
                            .foregroundColor(.blue)
                            .font(.headline)
                        
                        Text("子网前缀:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("例如: 192.168.1.", text: $viewModel.customSubnet)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .disabled(isScanning)
                            .overlay(
                                Group {
                                    if !viewModel.customSubnet.isEmpty {
                                        Button(action: {
                                            viewModel.customSubnet = ""
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.trailing, 8)
                                    }
                                },
                                alignment: .trailing
                            )
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
    
    // 扫描按钮
    private var scanButtonView: some View {
        VStack {
            // 自定义输入区域（如果需要）
            customInputView
            
            // 按钮
            Button(action: {
                if isScanning {
                    // 停止扫描
                    isScanning = false
                    viewModel.stopScan()
                } else {
                    // 开始扫描 - 关键改动：先更新UI状态，再开始扫描
                    print("扫描按钮被点击")
                    isScanning = true
                    
                    // 给UI一点时间更新后再启动扫描
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.startScan()
                        
                        // 添加扫描完成监听
                        viewModel.onScanComplete = {
                            isScanning = false
                        }
                    }
                }
            }) {
                HStack {
                    Image(systemName: isScanning ? "stop.fill" : "play.fill")
                        .font(.headline)
                    Text(isScanning ? "停止扫描" : "开始扫描")
                        .font(.headline)
                }
                .frame(height: 22)
                .frame(minWidth: 160)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(buttonBackgroundColor)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                )
                .foregroundColor(.white)
                .scaleEffect(isScanning ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isScanning)
            }
            .disabled(isButtonDisabled)
        }
    }
    
    // 按钮背景颜色
    private var buttonBackgroundColor: Color {
        if isButtonDisabled {
            return Color.gray
        } else if isScanning {
            return Color.red
        } else {
            return Color.blue
        }
    }
    
    // 按钮是否禁用
    private var isButtonDisabled: Bool {
        (selectedTab == 0 && !viewModel.networkScanner.isNetworkConnected) ||
        (selectedTab == 1 && viewModel.customSubnet.isEmpty && !isScanning)
    }
}
