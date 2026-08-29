# OpenAI-compatible CLI — MCP 配置实操速查

> 保存目的：重启 opencode 后快速对上，不用重新翻聊天记录。

## 配置位置
`~/.config/opencode/opencode.jsonc`

## 当前已配的 MCP（2 个）

```jsonc
{
  "mcp": {
    "playwright": {
      "type": "local",
      "command": ["npx", "-y", "@playwright/mcp@latest"],
      "enabled": true
    },
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": { "GITHUB_PERSONAL_ACCESS_TOKEN": "{env:GITHUB_TOKEN}" },
      "enabled": true
    }
  }
}
```

### playwright（浏览器自动化）
- 能力：打开网页、截图、点击、填表单、读取网络请求、执行 JS
- 服务端：`@playwright/mcp@latest`（官方，随 npx 即时拉取最新版）
- 使用姿势：「用 playwright 打开 <url> 并截图」「读取这个页面」「点击/输入……」

### github（GitHub API 操作）
- 能力：读写仓库文件、建分支 / PR / issue、查用户 / 仓库、搜索代码
- 服务端：`@modelcontextprotocol/server-github`（官方）
- 鉴权：通过 `GITHUB_PERSONAL_ACCESS_TOKEN` 环境变量传给子进程
- 使用姿势：「创建分支 + PR」「读 github.com/zljin/Knowledge-Hub 的信息」「查 issue #xx」

## Token 环境变量
- 位置：`~/.zshrc` 里的 `export GITHUB_TOKEN="..."`，已 source 且验证有效（API 200）
- ⚠️ 该 token 曾明文暴露在聊天里，**建议用完去 GitHub 设置页 revoke 重新生成**再替换
- 新 shell/终端必须 `source ~/.zshrc` 才有 GITHUB_TOKEN

### 生成 token 步骤
1. GitHub 右上角头像 → `Settings` → `Developer settings` → `Personal access tokens` → `Tokens (classic)`
2. `Generate new token (classic)`，填名字和过期时间
3. 勾选 scopes：
   - `repo`（或至少 `public_repo`，读写仓库、PR、issue 必需）
   - 需要组织数据时加 `read:org`
   - 不需要 `admin` 相关权限
4. 生成后立即复制，只显示一次
5. 写入 shell 配置：`echo 'export GITHUB_TOKEN="ghp_xxx"' >> ~/.zshrc && source ~/.zshrc`

### 快速验证 token
```bash
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/zljin/Knowledge-Hub
# 返回 200 且带仓库 JSON 即有效；401 = token 失效/权限不足
```

## 关键规则
- `command` 必须是**字符串数组**，不能是单个字符串
- `type` 必填：`local`（本地进程）/ `remote`（远程 URL）
- Key 用 `{env:变量名}` 插值，别明文写死
- **改配置 / 重启后才生效**；改完需退出重开 opencode
- 新增 MCP 后必须重启 opencode 才会加载工具；改了 `opencode.jsonc` 也一样

## 重启后怎么验证
1. 输入 `/exit` 或 `Ctrl+C` 退出，重新 `opencode`
2. 测试 Playwright：让我「用 playwright 打开 https://example.com 并截图」
3. 测试 GitHub：让我「用 GitHub MCP 读 github.com/zljin/Knowledge-Hub 的信息」

### 上次实测结果（验证通过）
- ✅ GitHub MCP：`github_get_file_contents` 读取 `zljin/Knowledge-Hub` 根目录成功，
  返回 `.gitignore` / `.opencode/` / `README.md` / `doc/` 列表，token 有效
- ✅ Playwright：同上可正常拉起浏览器并截图

## 诊断与排查
| 现象 | 可能原因 | 排查方法 |
| --- | --- | --- |
| 工具列表里没有某 MCP 的工具 | 未重启 / enabled 为 false | 改配置后完全退出重开；检查 `enabled: true` |
| github MCP 报 401/403 | token 失效、过期、权限不足 | 用上面 curl 验证；确认勾了 `repo` scope |
| npx 拉取失败 / 网络问题 | 网络代理、缓存损坏 | `npx -y <server>` 手动跑一次看报错 |
| JSONC 配置报语法错 | 多写逗号 / command 不是数组 | 用编辑器格式化检查，末尾不要逗号 |

## 配置 remote MCP（可选）
```jsonc
{
  "mcp": {
    "example-remote": {
      "type": "remote",
      "url": "https://example.com/mcp"
    }
  }
}
```
`type: remote` 走 HTTP/SSE，无需本地 command；url 需为 MCP 服务端点。

## 常用 MCP（备选，未装）
- 数据库：`["npx","-y","@modelcontextprotocol/server-postgres"]`，`DATABASE_URL` 环境变量
- 官方服务端索引：见 https://github.com/modelcontextprotocol/servers