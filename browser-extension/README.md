# BOSS 浏览器辅助扩展（开发版）

这个扩展用于连接网页版求职工作台和用户当前打开的 BOSS 直聘页面。

## 安装

1. 打开 Chrome 或 Edge 的扩展管理页面。
2. 开启“开发者模式”。
3. 选择“加载已解压的扩展”，选择本目录。
4. 打开 `https://www.zhipin.com/`，由用户自行完成登录。
5. 回到求职工作台网页进行连接测试。

## 网页通信协议

网页工作台向扩展发送（扩展会查找已打开的 BOSS 标签页）：

```js
window.postMessage({
  type: 'workbench-extension-request',
  requestId: 'request_xxx',
  action: 'check_login',
  payload: {}
}, window.location.origin);
```

扩展通过工作台页面回传：

```js
window.postMessage({
  type: 'workbench-extension-response',
  requestId: 'request_xxx',
  response: { ok: true, loggedIn: true }
}, window.location.origin);
```

支持的操作：

- `check_login`：根据页面可见元素判断当前页面是否可能已登录；
- `read_visible_jobs`：读取当前页面上可见职位卡片，并按关键词、城市过滤；
- `assist_apply`：仅在网页明确传入 `confirmed: true` 时点击页面上的投递按钮。

## 安全边界

- 不读取、复制或上传 Cookie；
- 不读取密码、短信验证码或本地存储；
- 不绕过验证码、安全验证、短信验证或风控；
- 检测到验证或异常访问提示时立即返回 `paused`；
- 职位读取仅限当前页面可见内容；
- 页面结构变化可能导致选择器需要更新；
- 当前版本只用于本地开发验证，正式发布前需确认平台服务条款和扩展审核要求。
