# VEX 训练数据管理

面向 VEX 赛队的移动优先训练记录工具，支持多教练、多设备和家长只读查看。

## 功能

- 分段训练：计时记录，数值越低表现越好
- 全场训练：60 秒计分，数值越高表现越好
- 多赛队、队员和教练授权管理
- 管理员、教练、家长三类权限
- 赛队与个人训练趋势、最快/最慢/平均统计
- 浏览器打印为 PDF 报告
- Supabase 登录、数据存储与行级安全策略
- Cloudflare Pages 静态部署

## 本地配置

1. 创建 Supabase 项目。
2. 在 Supabase SQL Editor 按文件编号执行 `database/` 中的迁移。
3. 创建第一个账号，将 `database/002_promote_first_admin.sql` 中的占位邮箱替换后执行。
4. 复制配置文件：

   ```bash
   cp config.example.js config.js
   ```

5. 在 `config.js` 填写 Supabase Project URL 和 Publishable Key。
6. 使用任意静态服务器打开项目，例如：

   ```bash
   python3 -m http.server 8080
   ```

7. 访问 `http://localhost:8080`。

`config.js` 已加入 `.gitignore`，不会被提交。请勿把 Supabase `service_role` 密钥放入前端或 GitHub。

## 数据库说明

- `001_foundation.sql`：基础表、触发器和 RLS
- `002_promote_first_admin.sql`：将指定账号提升为管理员
- `003`–`005`：注册角色与家长只读权限
- `006`、`008`：训练记录和赛队删除保护

生产数据库执行迁移前请先备份，并先在测试项目验证。破坏性的数据清理脚本不包含在开源仓库中。

## 部署到 Cloudflare Pages

Cloudflare Pages 直接上传时，部署文件中必须包含已填写的 `config.js`。在 Supabase Authentication 的 URL Configuration 中设置：

- Site URL：你的正式站点地址
- Redirect URLs：正式站点地址加 `/**`

## 安全

- 前端只允许使用 Supabase Publishable Key。
- 权限保护必须依赖数据库 RLS，不能只依赖页面按钮隐藏。
- 发现安全问题时请不要公开真实用户数据、访问令牌或后台密钥。

## 许可证

[MIT](LICENSE)
