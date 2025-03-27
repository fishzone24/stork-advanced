# Stork 高级节点管理工具

## 简介

这是一个用于管理 Stork 节点的高级脚本工具，它解决了 WAF 封锁问题，并支持多账户一对一代理配置。该工具使用 PM2 进程管理器提供更好的稳定性、监控和自动重启功能。

## 功能特点

- **一对一账户代理映射**：每个账户固定使用一个指定的代理
- **自动解决 WAF 封锁**：优化浏览器指纹和请求头，避免被网站检测和封锁
- **多账户批量管理**：支持同时运行多个账户
- **PM2 进程管理**：提供进程监控、日志管理和自动重启功能
- **友好的用户界面**：简单易用的菜单操作
- **全面的日志系统**：详细记录所有操作和错误信息

## 一键安装命令

只需在终端中运行以下命令，即可一键下载、配置和启动 Stork 节点：

```bash
wget -O stork_advanced.sh https://raw.githubusercontent.com/fishzone24/stork-advanced/main/stork_advanced.sh && chmod +x stork_advanced.sh && ./stork_advanced.sh --auto
```

> 注意：一键安装模式会自动引导您配置账户和代理信息。

## 手动安装步骤

如果您希望手动安装，请按照以下步骤操作：

1. 下载脚本：
   ```bash
   wget -O stork_advanced.sh https://raw.githubusercontent.com/fishzone24/stork-advanced/main/stork_advanced.sh
   ```

2. 添加执行权限：
   ```bash
   chmod +x stork_advanced.sh
   ```

3. 运行脚本：
   ```bash
   ./stork_advanced.sh
   ```

4. 按照菜单提示进行操作：
   - 选择选项 1 安装依赖并配置节点
   - 配置您的账户和代理信息
   - 使用选项 2 启动节点

## 代理配置

代理配置遵循以下格式：
- `http://用户名:密码@IP:端口`
- `socks5://用户名:密码@IP:端口`
- `IP:端口`（将自动添加 http:// 前缀）

确保代理数量与账户数量一致，脚本会自动将第一个代理分配给第一个账户，依此类推。

## 解决 WAF 封锁

该脚本通过以下方式解决 WAF 封锁问题：
1. 使用随机用户代理
2. 隐藏浏览器自动化特征
3. 添加真实浏览器的请求头
4. 模拟真实用户行为

## 使用 PM2 的优势

本脚本使用 PM2 进程管理器替代了传统的 screen 会话管理，提供以下优势：

1. **进程监控**：实时监控CPU和内存使用情况
2. **日志管理**：集中管理和查看日志
3. **自动重启**：进程崩溃时自动重启
4. **启动脚本**：系统重启后自动启动
5. **集群模式**：支持多进程负载均衡

## 常见问题

### 如何查看节点运行状态？
```bash
./stork_advanced.sh
# 选择选项 5
# 或者直接运行
pm2 show stork-node
```

### 如何查看运行日志？
```bash
./stork_advanced.sh
# 选择选项 4
# 或者直接运行
pm2 logs stork-node
```

### 如何停止节点？
```bash
./stork_advanced.sh
# 选择选项 3
# 或者直接运行
pm2 stop stork-node
```

### 如何更新账户或代理？
```bash
./stork_advanced.sh
# 选择选项 6
```

### 如何打开监控界面？
```bash
./stork_advanced.sh
# 选择选项 7
# 或者直接运行
pm2 monit
```

## 许可证

此项目采用 MIT 许可证 - 详情请参阅 LICENSE 文件。 