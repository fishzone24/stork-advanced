#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 项目目录
PROJECT_DIR="$HOME/stork_advanced"
CONFIG_FILE="$PROJECT_DIR/config.json"
ACCOUNTS_FILE="$PROJECT_DIR/accounts.js"
PROXIES_FILE="$PROJECT_DIR/proxies.txt"
PM2_NAME="stork-node"

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检测并安装环境依赖
install_dependencies() {
    print_info "正在检测系统环境依赖..."

    # 更新系统
    print_info "更新系统包列表..."
    sudo apt-get update -qq || { print_error "系统更新失败"; return 1; }

    # 安装 curl
    if ! command -v curl &> /dev/null; then
        print_info "安装 curl..."
        sudo apt-get install -y curl || { print_error "curl 安装失败"; return 1; }
    fi

    # 安装 git
    if ! command -v git &> /dev/null; then
        print_info "安装 git..."
        sudo apt-get install -y git || { print_error "git 安装失败"; return 1; }
    fi

    # 安装 Node.js 和 npm
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        print_info "安装 Node.js 和 npm..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - || { print_error "Node.js 源配置失败"; return 1; }
        sudo apt-get install -y nodejs || { print_error "Node.js 安装失败"; return 1; }
    fi

    # 安装 PM2
    if ! command -v pm2 &> /dev/null; then
        print_info "安装 PM2..."
        npm install -g pm2 || { print_error "PM2 安装失败"; return 1; }
    fi

    # 检查 npm 是否可用
    npm --version || { print_error "npm 未正确安装"; return 1; }
    
    # 检查 pm2 是否可用
    pm2 --version || { print_error "pm2 未正确安装"; return 1; }

    print_success "环境依赖安装完成！"
    return 0
}

# 安装项目
install_project() {
    print_info "开始安装项目..."
    
    # 检查是否已经克隆了仓库
    if [ -d "$PROJECT_DIR/.git" ]; then
        read -p "项目已存在，是否重新克隆？(y/n): " reclone
        if [[ "$reclone" == "y" || "$reclone" == "Y" ]]; then
            # 备份用户配置
            cp -f "$ACCOUNTS_FILE" "$ACCOUNTS_FILE.bak" 2>/dev/null
            cp -f "$PROXIES_FILE" "$PROXIES_FILE.bak" 2>/dev/null
            cp -f "$CONFIG_FILE" "$CONFIG_FILE.bak" 2>/dev/null
            
            # 清理目录
            print_info "清理项目目录..."
            rm -rf "$PROJECT_DIR"/* "$PROJECT_DIR"/.* 2>/dev/null || true
        else
            print_info "使用现有项目代码"
            cd "$PROJECT_DIR" || { print_error "无法进入项目目录"; return 1; }
            # 安装依赖
            print_info "安装 npm 依赖..."
            npm install || { print_error "依赖安装失败"; return 1; }
            
            # 安装 PM2 所需依赖
            print_info "安装 PM2 所需依赖..."
            npm install https-proxy-agent socks-proxy-agent || { print_error "PM2 依赖安装失败"; return 1; }
            
            # 创建修改版代码的文件
            create_enhanced_code
            
            # 创建 PM2 配置文件
            create_pm2_config
            
            print_success "项目安装完成！"
            return 0
        fi
    fi
    
    # 确保目录存在
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR" || { print_error "无法进入项目目录"; return 1; }
    
    # 克隆仓库
    print_info "克隆 Stork 仓库..."
    git clone https://github.com/sdohuajia/stork.git . || { 
        print_error "仓库克隆失败";
        print_info "尝试使用备选仓库...";
        git clone https://github.com/Stork-Project/stork-bot.git . || {
            print_error "备选仓库克隆也失败，请检查网络连接";
            return 1;
        }
    }
    
    # 恢复用户配置（如果有备份）
    if [ -f "$ACCOUNTS_FILE.bak" ]; then
        cp -f "$ACCOUNTS_FILE.bak" "$ACCOUNTS_FILE"
    fi
    if [ -f "$PROXIES_FILE.bak" ]; then
        cp -f "$PROXIES_FILE.bak" "$PROXIES_FILE"
    fi
    if [ -f "$CONFIG_FILE.bak" ]; then
        cp -f "$CONFIG_FILE.bak" "$CONFIG_FILE"
    fi
    
    # 安装依赖
    print_info "安装 npm 依赖..."
    npm install || { print_error "依赖安装失败"; return 1; }
    
    # 安装 PM2 所需依赖
    print_info "安装 PM2 所需依赖..."
    npm install https-proxy-agent socks-proxy-agent || { print_error "PM2 依赖安装失败"; return 1; }
    
    # 创建修改版代码的文件
    create_enhanced_code
    
    # 创建 PM2 配置文件
    create_pm2_config
    
    print_success "项目安装完成！"
    return 0
}

# 创建 PM2 配置文件
create_pm2_config() {
    print_info "创建 PM2 配置文件..."
    
    cat > "$PROJECT_DIR/ecosystem.config.js" << EOF
module.exports = {
  apps : [{
    name: "${PM2_NAME}",
    script: "enhanced-index.js",
    watch: false,
    max_memory_restart: "1G",
    log_date_format: "YYYY-MM-DD HH:mm:ss Z",
    env: {
      NODE_ENV: "production",
    }
  }]
};
EOF
    
    print_success "PM2 配置文件创建完成"
}

# 创建增强版代码解决 WAF 问题
create_enhanced_code() {
    print_info "创建增强版代理管理代码..."
    
    cat > "$PROJECT_DIR/proxy-manager.js" << 'EOF'
const fs = require('fs');
const path = require('path');
const https = require('https');
const { HttpsProxyAgent } = require('https-proxy-agent');
const { SocksProxyAgent } = require('socks-proxy-agent');

class ProxyManager {
  constructor(config) {
    this.config = config || {};
    this.proxies = [];
    this.userAgents = this.config.userAgents || [];
    this.currentUserAgentIndex = 0;
    this.loadProxies();
  }

  loadProxies() {
    try {
      const proxyFile = path.join(process.cwd(), 'proxies.txt');
      if (fs.existsSync(proxyFile)) {
        const content = fs.readFileSync(proxyFile, 'utf8');
        this.proxies = content.split('\n')
          .map(line => line.trim())
          .filter(line => line && !line.startsWith('#'));
        
        console.log(`[${new Date().toISOString()}] [信息] 已加载 ${this.proxies.length} 个代理`);
      } else {
        console.log(`[${new Date().toISOString()}] [警告] 代理文件不存在: ${proxyFile}`);
        this.proxies = [];
      }
    } catch (error) {
      console.error(`[${new Date().toISOString()}] [错误] 加载代理失败:`, error);
      this.proxies = [];
    }
  }

  // 为特定账户获取代理
  getProxyForAccount(accountIndex) {
    if (this.proxies.length === 0) {
      return null;
    }
    
    // 如果账户索引超出代理数量，使用最后一个代理
    if (accountIndex >= this.proxies.length) {
      console.log(`[${new Date().toISOString()}] [警告] 账户索引 ${accountIndex} 超出代理数量 ${this.proxies.length}，使用最后一个代理`);
      return this.proxies[this.proxies.length - 1];
    }
    
    return this.proxies[accountIndex];
  }

  getCurrentUserAgent() {
    if (this.userAgents.length === 0) {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
    }
    
    this.currentUserAgentIndex = (this.currentUserAgentIndex + 1) % this.userAgents.length;
    return this.userAgents[this.currentUserAgentIndex];
  }

  maskProxy(proxy) {
    if (!proxy) return 'none';
    
    // 对于 http://user:pass@host:port 格式的代理
    if (proxy.includes('@')) {
      const [auth, hostPort] = proxy.split('@');
      const [protocol, userPass] = auth.split('://');
      const [user, pass] = userPass.split(':');
      return `${protocol}://${user}:****@${hostPort}`;
    }
    
    // 对于 host:port 格式的代理
    return proxy;
  }

  getProxyAgent(proxy) {
    if (!proxy) return null;

    try {
      // 处理SOCKS代理
      if (proxy.startsWith('socks')) {
        return new SocksProxyAgent(proxy);
      } 
      // 处理HTTP/HTTPS代理
      else {
        // 如果代理格式只是IP:端口，添加http://前缀
        if (!proxy.includes('://')) {
          proxy = `http://${proxy}`;
        }
        return new HttpsProxyAgent(proxy);
      }
    } catch (error) {
      console.error(`[${new Date().toISOString()}] [错误] 创建代理代理失败:`, error);
      return null;
    }
  }

  testProxy(proxy) {
    if (!proxy) return Promise.resolve(false);
    
    const proxyAgent = this.getProxyAgent(proxy);
    if (!proxyAgent) return Promise.resolve(false);
    
    const testUrl = 'https://api.ipify.org?format=json';
    
    return new Promise((resolve) => {
      const req = https.get(testUrl, { 
        agent: proxyAgent,
        timeout: 10000,
        headers: {
          'User-Agent': this.getCurrentUserAgent()
        }
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          try {
            const result = JSON.parse(data);
            resolve(!!result.ip);
          } catch (e) {
            resolve(false);
          }
        });
      });
      
      req.on('error', () => {
        resolve(false);
      });
      
      req.on('timeout', () => {
        req.destroy();
        resolve(false);
      });
    });
  }
}

module.exports = ProxyManager;
EOF

    print_info "创建增强版主代码文件..."
    
    cat > "$PROJECT_DIR/enhanced-index.js" << 'EOF'
const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');
const ProxyManager = require('./proxy-manager');

// 加载配置
let config;
try {
  const configPath = path.join(process.cwd(), 'config.json');
  config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  console.log(`[${new Date().toISOString()}] [信息] 成功从 config.json 加载配置`);
} catch (error) {
  console.error(`[${new Date().toISOString()}] [错误] 加载配置失败:`, error);
  config = {
    logLevel: "info",
    taskInterval: 60,
    botOptions: {
      headless: true,
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox"
      ]
    },
    maxRetries: 3,
    retryDelay: 5000
  };
}

// 加载账户
let accounts = [];
try {
  const accountsPath = path.join(process.cwd(), 'accounts.js');
  const accountsModule = require(accountsPath);
  accounts = accountsModule.accounts || [];
  console.log(`[${new Date().toISOString()}] [信息] 成功从 accounts.js 加载账户`);
} catch (error) {
  console.error(`[${new Date().toISOString()}] [错误] 加载账户失败:`, error);
  process.exit(1);
}

// 初始化代理管理器
const proxyManager = new ProxyManager(config);

// 主函数
async function main() {
  // 检查账户
  if (accounts.length === 0) {
    console.error(`[${new Date().toISOString()}] [错误] 没有可用账户`);
    process.exit(1);
  }

  // 处理每个账户
  for (let i = 0; i < accounts.length; i++) {
    await processAccount(accounts[i], i);
  }

  // 设置下次运行
  console.log(`[${new Date().toISOString()}] [信息] 任务完成，${config.taskInterval} 秒后再次运行`);
  setTimeout(main, config.taskInterval * 1000);
}

// 处理单个账户
async function processAccount(account, accountIndex) {
  console.log(`[${new Date().toISOString()}] [信息] 正在处理 ${account.username} (账户 ${accountIndex + 1}/${accounts.length})`);
  
  // 获取此账户对应的代理
  const proxy = proxyManager.getProxyForAccount(accountIndex);
  console.log(`[${new Date().toISOString()}] [信息] 使用代理: ${proxyManager.maskProxy(proxy)}`);
  
  if (!proxy) {
    console.warn(`[${new Date().toISOString()}] [警告] 账户 ${account.username} 没有对应的代理配置`);
  }
  
  // 测试代理是否有效
  const isProxyValid = await proxyManager.testProxy(proxy);
  if (!isProxyValid) {
    console.error(`[${new Date().toISOString()}] [错误] 账户 ${account.username} 的代理无效`);
    return;
  }
  
  let retries = 0;
  let success = false;
  
  while (retries < config.maxRetries && !success) {
    let browser = null;
    
    try {
      const userAgent = proxyManager.getCurrentUserAgent();
      
      // 配置浏览器启动参数
      const launchOptions = {
        ...config.botOptions,
        args: [
          ...config.botOptions.args,
          proxy ? `--proxy-server=${proxy}` : '',
        ].filter(Boolean)
      };
      
      // 启动浏览器
      browser = await puppeteer.launch(launchOptions);
      
      // 打开页面
      const page = await browser.newPage();
      
      // 设置用户代理和请求头
      await page.setUserAgent(userAgent);
      await page.setExtraHTTPHeaders(config.headers || {});
      
      // 设置视口大小
      await page.setViewport({ width: 1920, height: 1080 });
      
      // 设置避免指纹识别
      await page.evaluateOnNewDocument(() => {
        // 重写 WebDriver 属性
        Object.defineProperty(navigator, 'webdriver', {
          get: () => false,
        });
        
        // 重写 navigator.plugins
        Object.defineProperty(navigator, 'plugins', {
          get: () => {
            return [
              { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer', description: 'Portable Document Format' },
              { name: 'Chrome PDF Viewer', filename: '', description: '' },
              { name: 'Native Client', filename: '', description: '' }
            ];
          },
        });
        
        // 重写 navigator.languages
        Object.defineProperty(navigator, 'languages', {
          get: () => ['en-US', 'en'],
        });
        
        // 隐藏 Puppeteer 特征
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) => (
          parameters.name === 'notifications' ?
            Promise.resolve({ state: Notification.permission }) :
            originalQuery(parameters)
        );
      });
      
      // 执行登录
      await login(page, account);
      
      // 执行其他任务...
      await performTasks(page);
      
      success = true;
      console.log(`[${new Date().toISOString()}] [信息] ${account.username} 处理成功`);
      
    } catch (error) {
      retries++;
      console.error(`[${new Date().toISOString()}] [错误] 处理账户 ${account.username} 失败 (尝试 ${retries}/${config.maxRetries}):`, error.message);
      
      if (retries < config.maxRetries) {
        console.log(`[${new Date().toISOString()}] [信息] ${config.retryDelay / 1000} 秒后重试...`);
        await new Promise(resolve => setTimeout(resolve, config.retryDelay));
      }
    } finally {
      if (browser) {
        await browser.close();
      }
    }
  }
  
  if (!success) {
    console.error(`[${new Date().toISOString()}] [错误] 处理账户 ${account.username} 失败，已达到最大重试次数`);
  }
}

// 登录函数
async function login(page, account) {
  try {
    console.log(`[${new Date().toISOString()}] [信息] 尝试登录 ${account.username}`);
    
    // 访问登录页面
    await page.goto('https://app.stork.network/login', {
      waitUntil: 'networkidle2',
      timeout: config.requestTimeout || 30000
    });
    
    // 等待登录表单加载
    await page.waitForSelector('input[type="email"]', { timeout: 10000 });
    
    // 输入邮箱和密码
    await page.type('input[type="email"]', account.username);
    await page.type('input[type="password"]', account.password);
    
    // 点击登录按钮
    await Promise.all([
      page.click('button[type="submit"]'),
      page.waitForNavigation({ waitUntil: 'networkidle2' })
    ]);
    
    // 检查是否成功登录
    const url = page.url();
    if (url.includes('dashboard')) {
      console.log(`[${new Date().toISOString()}] [信息] ${account.username} 登录成功`);
      return true;
    } else {
      throw new Error('登录失败，未重定向到仪表板');
    }
    
  } catch (error) {
    console.error(`[${new Date().toISOString()}] [错误] 登录失败:`, error.message);
    throw error;
  }
}

// 执行任务函数
async function performTasks(page) {
  try {
    // 等待页面加载完成
    await page.waitForSelector('.dashboard-container', { timeout: 10000 });
    
    // 在这里添加您需要完成的任务
    console.log(`[${new Date().toISOString()}] [信息] 执行任务...`);
    
    // 等待一段时间模拟人的行为
    await page.waitForTimeout(2000 + Math.random() * 3000);
    
    // 示例：点击某个链接或按钮
    // await page.click('.some-button-class');
    
    console.log(`[${new Date().toISOString()}] [信息] 任务执行完成`);
    
  } catch (error) {
    console.error(`[${new Date().toISOString()}] [错误] 执行任务失败:`, error.message);
    throw error;
  }
}

// 启动程序
console.log(`[${new Date().toISOString()}] [信息] 启动 Stork 节点程序...`);
main().catch(error => {
  console.error(`[${new Date().toISOString()}] [错误] 应用程序启动失败:`, error.message);
  process.exit(1);
});
EOF

    print_success "增强版代码创建完成"
}

# 配置项目
configure_project() {
    print_info "开始配置项目..."

    # 创建项目目录
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR" || { print_error "无法进入项目目录"; return 1; }

    # 配置账户
    configure_accounts
    
    # 配置代理
    configure_proxies
    
    # 创建配置文件
    create_config_file

    print_success "项目配置完成！"
    return 0
}

# 配置账户
configure_accounts() {
    print_info "配置账户信息..."
    
    if [ -f "$ACCOUNTS_FILE" ]; then
        read -p "账户文件已存在，是否重新配置？(y/n): " reconfigure
        if [[ "$reconfigure" != "y" && "$reconfigure" != "Y" ]]; then
            print_info "使用现有账户配置"
            return 0
        fi
    fi

    echo "export const accounts = [" > "$ACCOUNTS_FILE"
    
    print_info "请输入账户信息（输入空邮箱完成）:"
    local count=0
    while true; do
        read -p "邮箱: " email
        [[ -z "$email" ]] && break
        read -p "密码: " password
        echo "  { username: \"$email\", password: \"$password\" }," >> "$ACCOUNTS_FILE"
        ((count++))
    done
    
    echo "];" >> "$ACCOUNTS_FILE"
    print_success "已配置 $count 个账户"
}

# 配置代理
configure_proxies() {
    print_info "配置代理信息..."
    
    if [ -f "$PROXIES_FILE" ]; then
        read -p "代理文件已存在，是否重新配置？(y/n): " reconfigure
        if [[ "$reconfigure" != "y" && "$reconfigure" != "Y" ]]; then
            print_info "使用现有代理配置"
            return 0
        fi
    fi

    > "$PROXIES_FILE"
    
    print_info "请输入代理地址（支持格式：http://用户名:密码@IP:端口 或 IP:端口）"
    print_info "输入空行完成输入"
    print_warning "注意：每个账户应对应一个代理，请确保代理数量与账户数量一致！"
    
    local count=0
    while true; do
        read -p "代理地址: " proxy
        [[ -z "$proxy" ]] && break
        echo "$proxy" >> "$PROXIES_FILE"
        ((count++))
    done
    
    print_success "已配置 $count 个代理"
}

# 创建配置文件
create_config_file() {
    print_info "创建配置文件..."
    
    cat > "$CONFIG_FILE" << EOF
{
  "logLevel": "info",
  "taskInterval": 60,
  "botOptions": {
    "headless": true,
    "args": [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-accelerated-2d-canvas",
      "--disable-gpu",
      "--window-size=1920x1080"
    ],
    "userDataDir": "./user_data",
    "ignoreHTTPSErrors": true
  },
  "maxRetries": 3,
  "retryDelay": 5000,
  "userAgents": [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:89.0) Gecko/20100101 Firefox/89.0"
  ],
  "requestTimeout": 30000,
  "headers": {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1"
  }
}
EOF
    
    print_success "配置文件创建完成"
}

# 显示最新的日志
print_info "最新日志:"
if [ -f "$PROJECT_DIR/stork.log" ]; then
    tail -n 10 "$PROJECT_DIR/stork.log"
else
    print_warning "日志文件不存在"
fi

# 查看项目状态
check_status() {
    print_info "检查 Stork 节点状态..."
    
    if pm2 list | grep -q "$PM2_NAME"; then
        print_success "Stork 节点正在运行中"
        
        # 显示 PM2 状态信息
        pm2 show "$PM2_NAME"
        
        # 显示最新的日志
        print_info "最新日志:"
        pm2 logs "$PM2_NAME" --lines 10 --nostream
    else
        print_error "Stork 节点未运行"
    fi
}

# 启动项目
start_project() {
    print_info "启动 Stork 节点程序..."
    
    cd "$PROJECT_DIR" || { print_error "无法进入项目目录"; return 1; }
    
    # 检查是否有 PM2 进程存在
    if pm2 list | grep -q "$PM2_NAME"; then
        print_warning "发现已有 Stork 节点运行中"
        read -p "是否结束现有进程并重新启动？(y/n): " restart
        if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
            pm2 delete "$PM2_NAME" > /dev/null 2>&1
            print_info "已停止旧进程"
        else
            print_info "保留现有进程"
            return 0
        fi
    fi
    
    # 使用 PM2 启动
    print_info "使用 PM2 启动节点..."
    pm2 start ecosystem.config.js || { print_error "PM2 启动失败"; return 1; }
    
    # 保存 PM2 配置，确保重启后自动运行
    print_info "保存 PM2 配置..."
    pm2 save

    print_success "Stork 节点已在 PM2 中启动"
    print_info "使用 'pm2 logs $PM2_NAME' 查看日志"
    print_info "使用 'pm2 monit' 监控进程状态"
    
    return 0
}

# 查看日志
view_logs() {
    if pm2 list | grep -q "$PM2_NAME"; then
        print_info "显示 Stork 节点日志..."
        pm2 logs "$PM2_NAME"
    else
        print_error "没有正在运行的 Stork 节点进程"
        print_info "请先启动节点"
    fi
}

# 停止项目
stop_project() {
    print_info "停止 Stork 节点程序..."
    
    if pm2 list | grep -q "$PM2_NAME"; then
        pm2 stop "$PM2_NAME"
        print_success "Stork 节点已停止"
        
        read -p "是否完全删除进程？(y/n): " delete_proc
        if [[ "$delete_proc" == "y" || "$delete_proc" == "Y" ]]; then
            pm2 delete "$PM2_NAME"
            print_success "Stork 节点进程已删除"
        fi
    else
        print_warning "没有正在运行的 Stork 节点进程"
    fi
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}==============================================${NC}"
        echo -e "${GREEN}         Stork 高级节点管理脚本           ${NC}"
        echo -e "${BLUE}==============================================${NC}"
        echo -e "脚本版本: 1.0.0"
        echo -e "说明: 此脚本支持多账户一对一代理，使用PM2管理，解决WAF阻止问题"
        echo -e "${BLUE}==============================================${NC}"
        echo -e "请选择操作:"
        echo -e "1) ${GREEN}安装/配置${NC} - 安装依赖并配置节点"
        echo -e "2) ${GREEN}启动节点${NC} - 使用PM2启动节点"
        echo -e "3) ${GREEN}停止节点${NC} - 停止运行中的节点"
        echo -e "4) ${GREEN}查看日志${NC} - 查看节点运行日志"
        echo -e "5) ${GREEN}查看状态${NC} - 监控节点运行状态"
        echo -e "6) ${GREEN}更新配置${NC} - 更新账户和代理配置"
        echo -e "7) ${GREEN}监控面板${NC} - 打开PM2监控界面"
        echo -e "8) ${GREEN}退出脚本${NC}"
        echo -e "${BLUE}==============================================${NC}"
        
        read -p "请输入选项 [1-8]: " choice
        
        case $choice in
            1)
                install_dependencies && configure_project && install_project
                read -p "按回车键继续..." dummy
                ;;
            2)
                start_project
                read -p "按回车键继续..." dummy
                ;;
            3)
                stop_project
                read -p "按回车键继续..." dummy
                ;;
            4)
                view_logs
                # 已有返回功能，不需要按回车键
                ;;
            5)
                check_status
                read -p "按回车键继续..." dummy
                ;;
            6)
                configure_accounts
                configure_proxies
                create_config_file
                read -p "按回车键继续..." dummy
                ;;
            7)
                pm2 monit
                # PM2 monit有自己的界面，不需要按回车键
                ;;
            8)
                echo -e "${GREEN}感谢使用 Stork 高级节点管理脚本！${NC}"
                exit 0
                ;;
            *)
                print_error "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# 检查是否为一键执行模式
if [ "$1" == "--auto" ]; then
    install_dependencies && configure_project && install_project && start_project
    echo "====================================================================="
    echo "Stork 节点已自动配置并在 PM2 中启动"
    echo "使用以下命令查看运行日志："
    echo "pm2 logs ${PM2_NAME}"
    echo ""
    echo "使用以下命令查看监控界面："
    echo "pm2 monit"
    echo "====================================================================="
    exit 0
fi

# 脚本入口
main_menu 