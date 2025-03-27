#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 项目目录
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows 系统
    PROJECT_DIR="./stork_advanced"
else
    # Linux/Unix 系统
    PROJECT_DIR="$(pwd)/stork_advanced"
fi

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
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        # Windows 系统
        print_info "Windows系统，跳过系统更新"
    else
        # Linux/Unix 系统
        sudo apt-get update -qq || { print_error "系统更新失败"; return 1; }
    fi

    # 安装 curl
    if ! command -v curl &> /dev/null; then
        print_info "安装 curl..."
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
            print_info "Windows系统，请手动安装curl"
        else
            sudo apt-get install -y curl || { print_error "curl 安装失败"; return 1; }
        fi
    fi

    # 安装 git
    if ! command -v git &> /dev/null; then
        print_info "安装 git..."
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
            print_info "Windows系统，请手动安装git"
        else
            sudo apt-get install -y git || { print_error "git 安装失败"; return 1; }
        fi
    fi

    # 安装 Node.js 和 npm
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        print_info "安装 Node.js 和 npm..."
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
            print_info "Windows系统，请手动安装Node.js和npm"
        else
            curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - || { print_error "Node.js 源配置失败"; return 1; }
            sudo apt-get install -y nodejs || { print_error "Node.js 安装失败"; return 1; }
        fi
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
            cd "$PROJECT_DIR" || { print_error "无法进入项目目录"; return 1; }
            git clean -fdx || true
            cd .. || { print_error "无法返回上级目录"; return 1; }
            rm -rf "$PROJECT_DIR"
            mkdir -p "$PROJECT_DIR"
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
    print_info "当前目录: $(pwd)"
    
    # 确保目录存在
    if [ ! -d "$PROJECT_DIR" ]; then
        mkdir -p "$PROJECT_DIR"
        print_info "创建项目目录: $PROJECT_DIR"
    fi
    
    # 确保我们在正确的目录中
    if [ "$(pwd)" != "$PROJECT_DIR" ]; then
        print_info "切换到项目目录: $PROJECT_DIR"
        cd "$PROJECT_DIR" || { 
            print_error "无法进入项目目录: $PROJECT_DIR"
            return 1
        }
    fi
    
    print_info "创建 ecosystem.config.cjs 在 $(pwd)"
    
    # 创建 ecosystem.config.cjs
    cat > "ecosystem.config.cjs" << EOF
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

    # 检查文件是否创建成功
    if [ ! -f "ecosystem.config.cjs" ]; then
        print_error "ecosystem.config.cjs 创建失败"
        return 1
    else
        print_success "ecosystem.config.cjs 创建成功: $(pwd)/ecosystem.config.cjs"
    fi
    
    # 修改 package.json 中的 type 字段
    if [ -f "package.json" ]; then
        print_info "修改 package.json 配置..."
        # 如果文件不存在，创建一个新的
        if [ ! -f "package.json" ]; then
            cat > "package.json" << EOF
{
  "name": "stork-node",
  "version": "1.0.0",
  "type": "commonjs",
  "dependencies": {
    "puppeteer": "^latest",
    "https-proxy-agent": "^latest",
    "socks-proxy-agent": "^latest"
  }
}
EOF
        else
            # 如果文件存在，修改 type 字段
            print_info "将 package.json 中的 type 修改为 commonjs"
            sed -i 's/"type": "module"/"type": "commonjs"/' "package.json"
        fi
        
        # 检查 package.json 是否包含 type: commonjs
        if grep -q '"type": "commonjs"' "package.json"; then
            print_success "package.json 成功配置为 commonjs 类型"
        else
            print_warning "未能确认 package.json 类型，尝试手动添加"
            # 尝试添加type字段
            sed -i '/"name"/a \  "type": "commonjs",' "package.json"
        fi
    fi
    
    print_success "PM2 配置文件创建完成"
    
    # 返回原目录
    cd - > /dev/null 2>&1 || true
    return 0
}

# 创建增强版代码解决 WAF 问题
create_enhanced_code() {
    print_info "创建增强版代理管理代码..."
    print_info "当前目录: $(pwd)"
    
    # 确保目录存在
    if [ ! -d "$PROJECT_DIR" ]; then
        mkdir -p "$PROJECT_DIR"
        print_info "创建项目目录: $PROJECT_DIR"
    fi
    
    # 确保我们在正确的目录中
    if [ "$(pwd)" != "$PROJECT_DIR" ]; then
        print_info "切换到项目目录: $PROJECT_DIR"
        cd "$PROJECT_DIR" || { 
            print_error "无法进入项目目录: $PROJECT_DIR"
            return 1
        }
    fi
    
    print_info "创建 proxy-manager.js 在 $(pwd)"
    
    # 创建 proxy-manager.js
    cat > "proxy-manager.js" << 'EOF'
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

  getProxyForAccount(accountIndex) {
    if (this.proxies.length === 0) {
      return null;
    }
    
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
    
    if (proxy.includes('@')) {
      const [auth, hostPort] = proxy.split('@');
      const [protocol, userPass] = auth.split('://');
      const [user, pass] = userPass.split(':');
      return `${protocol}://${user}:****@${hostPort}`;
    }
    
    return proxy;
  }

  getProxyAgent(proxy) {
    if (!proxy) return null;

    try {
      if (proxy.startsWith('socks')) {
        return new SocksProxyAgent(proxy);
      } else {
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

    # 检查文件是否创建成功
    if [ ! -f "proxy-manager.js" ]; then
        print_error "proxy-manager.js 创建失败"
        return 1
    else
        print_success "proxy-manager.js 创建成功: $(pwd)/proxy-manager.js"
    fi

    print_info "创建增强版主代码文件..."
    
    cat > "enhanced-index.js" << 'EOF'
const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');
const { HttpsProxyAgent } = require('https-proxy-agent');
const { SocksProxyAgent } = require('socks-proxy-agent');

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

// 加载代理
let proxies = [];
try {
  const proxyFile = path.join(process.cwd(), 'proxies.txt');
  if (fs.existsSync(proxyFile)) {
    const content = fs.readFileSync(proxyFile, 'utf8');
    proxies = content.split('\n')
      .map(line => line.trim())
      .filter(line => line && !line.startsWith('#'));
    console.log(`[${new Date().toISOString()}] [信息] 已加载 ${proxies.length} 个代理`);
  } else {
    console.log(`[${new Date().toISOString()}] [警告] 代理文件不存在: ${proxyFile}`);
  }
} catch (error) {
  console.error(`[${new Date().toISOString()}] [错误] 加载代理失败:`, error);
}

// 用户代理列表
const userAgents = config.userAgents || [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
];
let currentUserAgentIndex = 0;

// 获取随机用户代理
function getRandomUserAgent() {
  currentUserAgentIndex = (currentUserAgentIndex + 1) % userAgents.length;
  return userAgents[currentUserAgentIndex];
}

// 获取账户对应的代理
function getProxyForAccount(accountIndex) {
  if (proxies.length === 0) {
    console.error(`[${new Date().toISOString()}] [错误] 没有可用代理！请先配置代理。`);
    return null;
  }
  
  if (accountIndex >= proxies.length) {
    console.log(`[${new Date().toISOString()}] [警告] 账户索引 ${accountIndex} 超出代理数量 ${proxies.length}，使用最后一个代理`);
    return proxies[proxies.length - 1];
  }
  
  return proxies[accountIndex];
}

// 掩码处理代理信息（打印日志用）
function maskProxy(proxy) {
  if (!proxy) return 'none';
  
  if (proxy.includes('@')) {
    const [auth, hostPort] = proxy.split('@');
    const [protocol, userPass] = auth.split('://');
    const [user, pass] = userPass.split(':');
    return `${protocol}://${user}:****@${hostPort}`;
  }
  
  return proxy;
}

// 主函数
async function main() {
  if (accounts.length === 0) {
    console.error(`[${new Date().toISOString()}] [错误] 没有可用账户`);
    process.exit(1);
  }

  for (let i = 0; i < accounts.length; i++) {
    await processAccount(accounts[i], i);
  }

  console.log(`[${new Date().toISOString()}] [信息] 任务完成，${config.taskInterval} 秒后再次运行`);
  setTimeout(main, config.taskInterval * 1000);
}

// 处理单个账户
async function processAccount(account, accountIndex) {
  console.log(`[${new Date().toISOString()}] [信息] 正在处理 ${account.username} (账户 ${accountIndex + 1}/${accounts.length})`);
  
  // 获取代理
  const proxy = getProxyForAccount(accountIndex);
  console.log(`[${new Date().toISOString()}] [信息] 使用代理: ${maskProxy(proxy)}`);
  
  // 如果没有代理，无法继续
  if (!proxy) {
    console.error(`[${new Date().toISOString()}] [错误] 账户 ${account.username} 没有可用代理，无法继续。`);
    return;
  }
  
  let retries = 0;
  let success = false;
  
  // 尝试不同的代理连接方式
  const connectionMethods = [
    { name: "使用启动参数", useProxy: true, useExplicitArgs: true },
    { name: "使用请求拦截", useProxy: true, useExplicitArgs: false, useHeadless: true }
  ];
  
  for (const method of connectionMethods) {
    if (success) break;
    
    console.log(`[${new Date().toISOString()}] [信息] 尝试使用 ${method.name} 方式连接`);
    
    retries = 0;
    while (retries < config.maxRetries && !success) {
      let browser = null;
      
      try {
        const userAgent = getRandomUserAgent();
        
        // 准备启动参数
        const launchArgs = [
          "--no-sandbox",
          "--disable-setuid-sandbox",
          "--disable-dev-shm-usage",
          "--disable-features=IsolateOrigins,site-per-process",
          "--disable-web-security",
          "--disable-features=BlockInsecurePrivateNetworkRequests",
          `--user-agent=${userAgent}`
        ];
        
        // 使用代理
        if (method.useExplicitArgs) {
          // 方法1: 使用启动参数添加代理
          if (proxy.startsWith('socks')) {
            try {
              const url = new URL(proxy);
              launchArgs.push(`--proxy-server=socks5=${url.hostname}:${url.port}`);
              
              if (url.username && url.password) {
                launchArgs.push(`--proxy-auth=${decodeURIComponent(url.username)}:${decodeURIComponent(url.password)}`);
              }
            } catch (e) {
              console.error(`[${new Date().toISOString()}] [错误] 解析SOCKS代理失败:`, e.message);
              launchArgs.push(`--proxy-server=${proxy}`);
            }
          } else if (proxy.includes('http')) {
            launchArgs.push(`--proxy-server=${proxy}`);
          } else {
            // 假设是IP:PORT格式
            launchArgs.push(`--proxy-server=http://${proxy}`);
          }
        }
        
        console.log(`[${new Date().toISOString()}] [信息] 启动浏览器，参数: ${launchArgs.join(' ')}`);
        
        // 准备启动选项
        const launchOptions = {
          headless: method.useHeadless !== false ? true : false,
          args: launchArgs,
          ignoreHTTPSErrors: true,
          timeout: 60000
        };
        
        browser = await puppeteer.launch(launchOptions);
        const page = await browser.newPage();
        
        // 如果使用请求拦截方式
        if (!method.useExplicitArgs) {
          // 方法2: 在页面级别设置代理
          if (proxy.startsWith('socks')) {
            const agent = new SocksProxyAgent(proxy);
            await page.setRequestInterception(true);
            page.on('request', request => {
              const overrides = {};
              
              if (request.isNavigationRequest()) {
                overrides.agent = agent;
                overrides.headers = {
                  ...request.headers(),
                  'user-agent': userAgent
                };
              }
              
              request.continue(overrides);
            });
          } else {
            const agent = new HttpsProxyAgent(proxy.includes('http') ? proxy : `http://${proxy}`);
            await page.setRequestInterception(true);
            page.on('request', request => {
              const overrides = {};
              
              if (request.isNavigationRequest()) {
                overrides.agent = agent;
                overrides.headers = {
                  ...request.headers(),
                  'user-agent': userAgent
                };
              }
              
              request.continue(overrides);
            });
          }
        }
        
        await page.setUserAgent(userAgent);
        await page.setExtraHTTPHeaders({
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
          'Cache-Control': 'max-age=0',
          'Connection': 'keep-alive'
        });
        
        await page.setViewport({ width: 1920, height: 1080 });
        
        // 防止指纹识别
        await page.evaluateOnNewDocument(() => {
          Object.defineProperty(navigator, 'webdriver', {
            get: () => false,
          });
          
          Object.defineProperty(navigator, 'plugins', {
            get: () => {
              return [
                { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer', description: 'Portable Document Format' },
                { name: 'Chrome PDF Viewer', filename: '', description: '' },
                { name: 'Native Client', filename: '', description: '' }
              ];
            },
          });
          
          Object.defineProperty(navigator, 'languages', {
            get: () => ['en-US', 'en'],
          });
          
          const originalQuery = window.navigator.permissions.query;
          window.navigator.permissions.query = (parameters) => (
            parameters.name === 'notifications' ?
              Promise.resolve({ state: Notification.permission }) :
              originalQuery(parameters)
          );
        });
        
        await login(page, account);
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
  }
  
  if (!success) {
    console.error(`[${new Date().toISOString()}] [错误] 处理账户 ${account.username} 失败，已达到最大重试次数`);
  }
}

// 登录函数
async function login(page, account) {
  try {
    console.log(`[${new Date().toISOString()}] [信息] 尝试登录 ${account.username}`);
    
    await page.goto('https://app.stork.network/login', {
      waitUntil: 'networkidle2',
      timeout: config.requestTimeout || 30000
    });
    
    await page.waitForSelector('input[type="email"]', { timeout: 10000 });
    
    await page.type('input[type="email"]', account.username);
    await page.type('input[type="password"]', account.password);
    
    await Promise.all([
      page.click('button[type="submit"]'),
      page.waitForNavigation({ waitUntil: 'networkidle2' })
    ]);
    
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
    await page.waitForSelector('.dashboard-container', { timeout: 10000 });
    
    console.log(`[${new Date().toISOString()}] [信息] 执行任务...`);
    
    await page.waitForTimeout(2000 + Math.random() * 3000);
    
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

    # 检查文件是否创建成功
    if [ ! -f "enhanced-index.js" ]; then
        print_error "enhanced-index.js 创建失败"
        return 1
    else
        print_success "enhanced-index.js 创建成功: $(pwd)/enhanced-index.js"
    fi

    print_success "增强版代码创建完成"
    
    # 返回原目录
    cd - > /dev/null 2>&1 || true
    return 0
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

    # 使用 CommonJS 模块格式而不是 ES 模块
    echo "// Stork 账户配置文件" > "$ACCOUNTS_FILE"
    echo "// 使用 CommonJS 格式导出账户信息" >> "$ACCOUNTS_FILE"
    echo "const accounts = [" >> "$ACCOUNTS_FILE"
    
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
    echo "" >> "$ACCOUNTS_FILE"
    echo "module.exports = { accounts };" >> "$ACCOUNTS_FILE"
    
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
    
    print_info "请输入代理地址，支持以下格式:"
    print_info "1. SOCKS5代理: socks5://用户名:密码@IP:端口"
    print_info "2. HTTP代理: http://用户名:密码@IP:端口"
    print_info "3. 简单IP:端口格式: IP:端口 (会自动转为http://IP:端口)"
    print_warning "注意：每个账户应对应一个代理，请确保代理数量与账户数量一致！"
    
    local count=0
    while true; do
        read -p "代理地址: " proxy
        [[ -z "$proxy" ]] && break
        
        # 验证并格式化代理
        if [[ "$proxy" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
            # 如果是 IP:端口 格式，添加 http:// 前缀
            print_info "检测到IP:端口格式，转换为http://$proxy"
            echo "http://$proxy" >> "$PROXIES_FILE"
        elif [[ "$proxy" =~ ^socks[45]://[^@]+@[^:]+:[0-9]+$ ]]; then
            # 如果是 socks://user:pass@ip:port 格式，保持不变
            print_info "检测到SOCKS代理格式，已验证"
            echo "$proxy" >> "$PROXIES_FILE"
        elif [[ "$proxy" =~ ^(http|https)://[^@]+@[^:]+:[0-9]+$ ]]; then
            # 如果是 http(s)://user:pass@ip:port 格式，保持不变
            print_info "检测到HTTP代理格式，已验证"
            echo "$proxy" >> "$PROXIES_FILE"
        elif [[ "$proxy" =~ ^(http|https|socks[45])://[^:]+:[0-9]+$ ]]; then
            # 如果是 http(s)://ip:port 或 socks://ip:port 格式，保持不变
            print_info "检测到不带认证的代理格式，已验证"
            echo "$proxy" >> "$PROXIES_FILE"
        else
            # 未知格式，提示用户确认
            print_warning "无法识别的代理格式: $proxy"
            read -p "是否仍然添加此代理？(y/n): " add_anyway
            if [[ "$add_anyway" == "y" || "$add_anyway" == "Y" ]]; then
                echo "$proxy" >> "$PROXIES_FILE"
            else
                print_info "跳过此代理"
                continue
            fi
        fi
        
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
    
    print_info "使用目录: $PROJECT_DIR"
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "项目目录不存在，创建中..."
        mkdir -p "$PROJECT_DIR"
    fi
    
    cd "$PROJECT_DIR" || { print_error "无法进入项目目录: $PROJECT_DIR"; return 1; }
    
    # 检查必要文件是否存在
    if [ ! -f "proxy-manager.js" ]; then
        print_warning "找不到代理管理文件: $(pwd)/proxy-manager.js"
        print_info "创建代理管理文件..."
        create_enhanced_code || { print_error "创建代理管理文件失败"; return 1; }
    else
        print_info "代理管理文件已存在: $(pwd)/proxy-manager.js"
    fi
    
    if [ ! -f "ecosystem.config.cjs" ]; then
        print_warning "找不到PM2配置文件: $(pwd)/ecosystem.config.cjs"
        print_info "创建PM2配置文件..."
        create_pm2_config || { print_error "创建PM2配置文件失败"; return 1; }
    else
        print_info "PM2配置文件已存在: $(pwd)/ecosystem.config.cjs"
    fi
    
    if [ ! -f "accounts.js" ]; then
        print_error "账户配置文件不存在: $(pwd)/accounts.js"
        print_info "请先运行选项1进行安装和配置"
        read -p "按回车键继续..." dummy
        return 1
    else
        print_info "账户配置文件已存在: $(pwd)/accounts.js"
    fi
    
    if [ ! -f "proxies.txt" ]; then
        print_error "代理配置文件不存在: $(pwd)/proxies.txt"
        print_info "请先运行选项1进行安装和配置"
        read -p "按回车键继续..." dummy
        return 1
    else
        print_info "代理配置文件已存在: $(pwd)/proxies.txt"
    fi
    
    if [ ! -f "config.json" ]; then
        print_warning "找不到配置文件: $(pwd)/config.json"
        print_info "创建配置文件..."
        create_config_file || { print_error "创建配置文件失败"; return 1; }
    else
        print_info "配置文件已存在: $(pwd)/config.json"
    fi
    
    # 安装必要的 NPM 依赖
    print_info "检查并安装必要的 NPM 依赖..."
    if [ ! -d "node_modules" ]; then
        print_warning "未找到node_modules目录，安装依赖中..."
        npm install puppeteer https-proxy-agent socks-proxy-agent || {
            print_error "依赖安装失败"
            read -p "按回车键继续..." dummy
            return 1
        }
    else
        # 检查是否有特定的模块
        for module in "puppeteer" "https-proxy-agent" "socks-proxy-agent"; do
            if [ ! -d "node_modules/$module" ]; then
                print_warning "未找到模块: $module，正在安装..."
                npm install $module || {
                    print_error "安装 $module 失败"
                    read -p "按回车键继续..." dummy
                    return 1
                }
            fi
        done
    fi
    
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
    
    # 确保所有必要的文件已经创建
    print_info "验证所有必要文件..."
    ls -la
    
    # 使用 PM2 启动
    print_info "使用 PM2 启动节点..."
    pm2 start ecosystem.config.cjs || { print_error "PM2 启动失败"; return 1; }
    
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
                print_info "开始安装流程..."
                
                # 先安装依赖
                install_dependencies || { print_error "依赖安装失败"; read -p "按回车键继续..." dummy; continue; }
                
                # 创建项目目录
                print_info "创建项目目录..."
                mkdir -p "$PROJECT_DIR" || { print_error "创建项目目录失败"; read -p "按回车键继续..." dummy; continue; }
                
                # 备份现有配置（如果存在）
                if [ -d "$PROJECT_DIR/.git" ]; then
                    print_info "备份现有配置..."
                    cp -f "$ACCOUNTS_FILE" "$ACCOUNTS_FILE.bak" 2>/dev/null
                    cp -f "$PROXIES_FILE" "$PROXIES_FILE.bak" 2>/dev/null
                    cp -f "$CONFIG_FILE" "$CONFIG_FILE.bak" 2>/dev/null
                    
                    # 清理目录
                    print_info "清理项目目录..."
                    cd "$PROJECT_DIR" || { print_error "无法进入项目目录"; return 1; }
                    git clean -fdx || true
                    cd .. || { print_error "无法返回上级目录"; return 1; }
                    rm -rf "$PROJECT_DIR"
                    mkdir -p "$PROJECT_DIR"
                fi
                
                # 克隆仓库
                cd "$PROJECT_DIR" || { print_error "无法进入项目目录"; return 1; }
                print_info "克隆 Stork 仓库..."
                git clone https://github.com/sdohuajia/stork.git . || { 
                    print_error "仓库克隆失败";
                    print_info "尝试使用备选仓库...";
                    git clone https://github.com/Stork-Project/stork-bot.git . || {
                        print_error "备选仓库克隆也失败，请检查网络连接";
                        read -p "按回车键继续..." dummy;
                        continue;
                    }
                }
                
                # 安装项目依赖
                print_info "安装 npm 依赖..."
                npm install || { print_error "依赖安装失败"; read -p "按回车键继续..." dummy; continue; }
                
                # 安装 PM2 所需依赖
                print_info "安装 PM2 所需依赖..."
                npm install https-proxy-agent socks-proxy-agent || { print_error "PM2 依赖安装失败"; read -p "按回车键继续..." dummy; continue; }
                
                # 创建修改版代码的文件
                create_enhanced_code
                
                # 创建 PM2 配置文件
                create_pm2_config
                
                print_success "项目安装完成！"
                print_info "开始配置项目..."
                print_info "请按提示输入您的账户和代理信息"
                read -p "按回车键开始配置..." dummy
                
                # 配置账户
                print_info "配置账户信息..."
                print_info "请输入账户信息（输入空邮箱完成）:"
                echo "const accounts = [" > "$ACCOUNTS_FILE"
                local count=0
                while true; do
                    read -p "邮箱: " email
                    [[ -z "$email" ]] && break
                    read -p "密码: " password
                    echo "  { username: \"$email\", password: \"$password\" }," >> "$ACCOUNTS_FILE"
                    ((count++))
                done
                echo "];" >> "$ACCOUNTS_FILE"
                echo "" >> "$ACCOUNTS_FILE"
                echo "module.exports = { accounts };" >> "$ACCOUNTS_FILE"
                print_success "已配置 $count 个账户"
                
                # 配置代理
                print_info "配置代理信息..."
                print_info "请输入代理地址，支持以下格式:"
                print_info "1. SOCKS5代理: socks5://用户名:密码@IP:端口"
                print_info "2. HTTP代理: http://用户名:密码@IP:端口"
                print_info "3. 简单IP:端口格式: IP:端口 (会自动转为http://IP:端口)"
                print_warning "注意：每个账户应对应一个代理，请确保代理数量与账户数量一致！"
                > "$PROXIES_FILE"
                local proxy_count=0
                while true; do
                    read -p "代理地址: " proxy
                    [[ -z "$proxy" ]] && break
                    echo "$proxy" >> "$PROXIES_FILE"
                    ((proxy_count++))
                done
                print_success "已配置 $proxy_count 个代理"
                
                # 创建配置文件
                create_config_file
                
                print_success "安装和配置完成！"
                print_info "您现在可以："
                print_info "1. 使用选项2启动节点"
                print_info "2. 使用选项4查看运行日志"
                print_info "3. 使用选项7打开监控面板"
                read -p "按回车键返回主菜单..." dummy
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
                # 停止节点
                if pm2 list | grep -q "$PM2_NAME"; then
                    print_warning "检测到节点正在运行，建议先停止节点再更新配置"
                    read -p "是否停止运行中的节点？(y/n): " stop_node
                    if [[ "$stop_node" == "y" || "$stop_node" == "Y" ]]; then
                        pm2 stop "$PM2_NAME" > /dev/null 2>&1
                        print_info "已停止节点"
                    fi
                fi
                
                # 更新账户和代理配置
                configure_accounts
                configure_proxies
                
                # 询问是否更新配置文件
                read -p "是否更新其他配置参数？(y/n): " update_config
                if [[ "$update_config" == "y" || "$update_config" == "Y" ]]; then
                    create_config_file
                fi
                
                # 询问是否重新生成代码文件
                read -p "是否重新生成增强代码文件？(y/n): " recreate_code
                if [[ "$recreate_code" == "y" || "$recreate_code" == "Y" ]]; then
                    create_enhanced_code
                fi
                
                print_success "配置更新完成！"
                
                # 询问是否重启节点
                if pm2 list | grep -q "$PM2_NAME"; then
                    read -p "是否重启节点应用更新后的配置？(y/n): " restart_node
                    if [[ "$restart_node" == "y" || "$restart_node" == "Y" ]]; then
                        pm2 restart "$PM2_NAME" > /dev/null 2>&1
                        print_success "节点已重启，新配置已生效"
                    else
                        print_info "节点未重启，配置将在下次启动时生效"
                    fi
                else
                    read -p "是否立即启动节点？(y/n): " start_node
                    if [[ "$start_node" == "y" || "$start_node" == "Y" ]]; then
                        start_project
                    fi
                fi
                
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