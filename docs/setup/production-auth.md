# 邮箱确认与生产认证检查表

## 状态

应用已支持两种注册结果：开发环境自动确认时直接进入鱼缸；需要确认的环境会
停留在登录页，保留注册邮箱并提供“重新发送确认邮件”。真实邮件投递仍需要
部署环境提供 SMTP 凭据。

## 本地 CLI 验证

仓库的 supabase/config.toml 已启用邮箱确认。使用 Supabase CLI 启动本项目时，
Mailpit 会承接开发邮件；注册后应没有 session，且确认链接可在登录页之后使用。
不要把真实 SMTP 密码写入该配置或提交到仓库。

## 部署前配置

在自托管 Supabase 的私密环境文件或密钥管理器中设置：

~~~text
ENABLE_EMAIL_AUTOCONFIRM=false
SMTP_ADMIN_EMAIL=<verified-sender@example.com>
SMTP_HOST=<provider-host>
SMTP_PORT=<provider-port>
SMTP_USER=<provider-user>
SMTP_PASS=<secret>
SMTP_SENDER_NAME=Yopet
~~~

当前 Docker Compose 会把这些值映射为 GoTrue 的
GOTRUE_MAILER_AUTOCONFIRM 与 GOTRUE_SMTP_* 变量。SITE_URL 和允许的回调地址
必须指向实际 HTTPS 域名，而不是 localhost。

## 上线验收

1. 用一个受控邮箱注册；客户端展示确认状态，且不能进入鱼缸。
2. 收到邮件，链接回到已配置的 HTTPS 站点。
3. 确认后使用同一邮箱与密码登录，获得自己的空鱼缸。
4. 在邮件送达、重发节流、无效链接和错误密码情况下检查简短中文反馈。
5. 记录 SMTP 发件域、限流和监控负责人；凭据只存放于部署密钥系统。
