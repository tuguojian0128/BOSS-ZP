# 用户登录、JWT 与数据隔离

当前版本已提供一套可运行的账号认证基础设施，供 Flutter Web、桌面端和移动端共用。

## 接口

| 方法 | 路径 | 是否需要登录 | 说明 |
| --- | --- | --- | --- |
| POST | `/api/v1/auth/register` | 否 | 手机号或邮箱注册，并返回登录令牌 |
| POST | `/api/v1/auth/login` | 否 | 登录并返回 access token、refresh token |
| POST | `/api/v1/auth/refresh` | 否 | 轮换 refresh token，返回新的令牌对 |
| POST | `/api/v1/auth/logout` | 是 | 撤销当前用户的 refresh token |
| GET | `/api/v1/auth/me` | 是 | 获取当前登录用户 |

注册和登录成功后的返回值包含：

```json
{
  "accessToken": "短期 JWT",
  "refreshToken": "仅一次使用的刷新令牌",
  "expiresIn": 900,
  "user": { "id": "user_xxx", "displayName": "张三" }
}
```

后续业务请求需要携带：

```http
Authorization: Bearer <accessToken>
```

## 安全策略

- access token 有效期为 15 分钟；refresh token 有效期为 30 天。
- refresh token 只保存 SHA-256 摘要，刷新时旧令牌立即撤销并生成新令牌。
- JWT 密钥从 `JWT_SECRET` 环境变量读取；生产环境必须设置强随机密钥。
- 密码以带随机盐的重复 SHA-256 形式保存。当前实现用于开发和内测；正式生产应替换为 Argon2id 或 bcrypt，并接入密钥管理服务。
- `APP_ENV=production` 时不允许测试身份头；开发环境可以使用明确的 `X-User-Id` 进行本地接口联调。
- 未登录或令牌无效的业务请求统一返回 HTTP 401。

## `user_id` 隔离

当前 JWT 的 `sub` 字段就是服务端可信的用户 ID，业务处理函数不会使用客户端提交的 `user_id` 覆盖它。以下资源均按当前用户校验：

- 平台账号及授权会话；
- 简历、上传令牌、解析任务和简历资料；
- 一键投递任务；
- 投递记录和每日平台统计（写入 SQLite 时带 `user_id`）。

跨用户使用资源 ID 时返回 404，避免泄露资源是否存在。

## 开发演示账号

首次启动会创建：

```text
手机号：13800138000
密码：demo-password
```

请勿在生产环境继续使用该账号或默认 JWT 密钥。
