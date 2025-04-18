# Judas - iOS内网扫描工具

## 概述

Judas是一款专为iOS设备设计的轻量级内网扫描工具。该工具允许用户在连接到内部网络时进行设备发现和端口扫描，帮助用户了解网络环境中的设备和服务。

正如其名称所暗示的，Judas能够在不引人注目的情况下"潜入"内部网络，执行全面的网络侦察任务 - 就像一个沉默的"内应"。

## 功能特性

- **内网设备发现**：快速扫描当前网络中的所有活跃设备
- **自定义子网扫描**：支持扫描自定义IP范围
- **端口扫描**：检测开放端口和运行服务
- **服务识别**：自动识别常见网络服务及其用途
- **直观界面**：清晰展示扫描结果和设备信息
- **实时进度跟踪**：直观显示扫描进度和状态
- **分类浏览**：按服务类型过滤扫描结果
- **快捷操作**：一键访问Web服务、复制连接命令等

## 截图

## 应用截图展示

<div align="center">
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/1.png" width="30%" alt="主界面"/>
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/2.png" width="30%" alt="设备扫描"/>
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/3.png" width="30%" alt="设备详情"/>
</div>

<div align="center">
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/4.png" width="30%" alt="端口扫描"/>
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/5.png" width="30%" alt="服务识别"/>
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/6.png" width="30%" alt="扫描结果"/>
</div>

<div align="center">
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/7.png" width="30%" alt="自定义扫描"/>
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/8.png" width="30%" alt="扫描进度"/>
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/9.png" width="30%" alt="服务分类"/>
</div>

<div align="center">
  <img src="https://raw.githubusercontent.com/ZacharyZcR/Judas/refs/heads/main/image/10.png" width="30%" alt="操作选项"/>
</div>


## 安装说明

### 方法1：使用Xcode构建

1. 克隆仓库：`git clone https://github.com/yourusername/judas.git`
2. 使用Xcode打开项目文件
3. 选择您的设备并构建应用
4. 在您的iOS设备上信任开发者证书

### 方法2：使用AltStore侧载

1. 在您的设备上安装[AltStore](https://altstore.io/)
2. 下载本仓库中的`.ipa`文件
3. 通过AltStore安装`.ipa`文件:
   - 打开AltStore
   - 前往"My Apps"选项卡
   - 点击左上角的加号
   - 选择下载的Judas.ipa文件
4. 等待安装完成，应用将出现在您的主屏幕上

### 方法3：TestFlight（即将推出）

我们计划在未来通过TestFlight提供测试版本。敬请关注更新。

## 使用指南

1. 确保您的设备已连接到目标Wi-Fi网络
2. 启动Judas应用
3. 选择"当前网络"或"自定义子网"模式
4. 点击"开始扫描"按钮
5. 等待扫描完成
6. 点击发现的设备查看详细信息和开放端口
7. 使用快捷操作与设备交互

## 技术实现

Judas完全使用SwiftUI构建，采用以下技术：

- **Network框架**：进行TCP端口扫描和连接检测
- **URLSession**：检测HTTP服务
- **Combine**：管理异步操作和状态更新
- **Foundation**：处理网络地址和数据
- **MVVM架构**：保持代码清晰和可维护

## 合法免责声明

Judas仅供安全研究、网络排障和教育目的使用。用户需自行承担使用该工具的法律责任。未经授权扫描他人网络可能违反相关法律法规。请确保您仅在有权限的网络上使用此工具。

## 为何命名为Judas？

如同圣经中的犹大(Judas)角色，这款工具能够潜入内部网络并"背叛"网络的秘密—揭示设备和服务的存在。这个名称反映了工具的本质：一个内网的"知情者"，能够在不被察觉的情况下收集信息。

## 贡献

欢迎贡献代码和提出改进建议！请遵循以下步骤：

1. Fork仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

## 未来计划

- [ ] 添加网络流量分析功能
- [ ] 实现自动化服务识别
- [ ] 支持更多网络协议扫描
- [ ] 设备漏洞检测
- [ ] 添加暗黑模式支持
- [ ] 支持导出扫描结果

## 许可证

该项目采用MIT许可证。详情请参阅LICENSE文件。

## 联系方式

如有问题或建议，请通过GitHub Issues联系我们。
