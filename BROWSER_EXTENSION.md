# 网页版 BOSS 辅助模式

主程序仍然是 Flutter Web。由于浏览器同源策略，网页不能直接读取或操作另一个网站的 DOM，因此增加一个 Chrome/Edge 辅助扩展作为浏览器侧连接器。

```text
Flutter Web 工作台
        ↓ window.postMessage
BOSS 辅助扩展 content-script
        ↓ 只读取当前页面可见 DOM
用户已登录的 BOSS 页面
```

扩展代码位于 `browser-extension/`，当前已提供：

- 登录状态的页面标记检测；
- 当前页面可见职位读取；
- 关键词和城市过滤；
- 用户明确确认后的投递按钮辅助点击；
- 验证码、短信验证和风控提示检测后暂停。

平台账号页的“检测浏览器扩展”按钮已接入 `BrowserBridge`，可以从 Flutter Web 发起 `check_login` 请求并接收扩展响应。

## 下一步接入 Flutter

1. 在 Flutter Web 增加 `BrowserBridge`，为每个请求生成一次性 `requestId`。
2. 将工作台筛选条件转换为 `read_visible_jobs` 请求。
3. 将扩展返回的职位映射到统一 `Job` 模型。
4. 用户点击一键投递后发送 `assist_apply`，每份职位都要求明确确认。
5. 将扩展结果回传后端，继续沿用 JWT、投递任务和每日平台统计。

扩展不会替代后端认证，也不会把 BOSS 会话凭证发送到后端。
