# 招聘平台账号与筛选方案

## 产品流程

1. 用户打开左侧“平台账号”；
2. 选择 BOSS 直聘、智联招聘、猎聘、前程无忧、鱼泡直聘或国聘；
3. 点击“登录连接”，跳转到对应平台的官方登录页面；
4. 用户在官方页面完成登录或授权后回到工作台；
5. 用户点击工作台中的平台筛选，已连接的平台才会变为高亮并参与检索；
6. 未连接的平台会再次提示先完成官方登录。

## 安全边界

浏览器端和本应用都不能读取、复制或保存第三方平台 Cookie，也不能通过复制 Cookie 实现免密登录。Cookie 是平台会话凭证，直接复用会造成账号被盗风险，也可能违反平台规则。

生产实现应优先使用：

- 平台官方 OAuth / OpenID Connect；
- 平台官方开放平台 API；
- 平台提供的扫码登录或授权回调；
- 服务端短期 access token + refresh token；
- token 加密存储、轮换和撤销。

如果某个平台没有公开授权接口，产品只能引导用户访问该平台完成操作，不能通过自动抓取、注入脚本、验证码绕过或 Cookie 复用来代替授权。

## 后端接口建议

```text
GET    /api/v1/platform-accounts
POST   /api/v1/platform-accounts/{platform}/authorize
GET    /api/v1/platform-accounts/{platform}/callback
DELETE /api/v1/platform-accounts/{platform}
GET    /api/v1/jobs?platform=boss&keyword=Java&city=上海市
```

前端只拿到 `connected`、`displayName`、`lastSyncedAt` 和授权状态，不拿第三方 Cookie 或长期凭证。

