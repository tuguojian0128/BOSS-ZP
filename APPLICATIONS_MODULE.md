# 投递中心统计模块

投递中心现在以“每日投递（按平台）”为核心：每天分别记录 BOSS 直聘、智联招聘、猎聘、前程无忧、鱼泡直聘和国聘投递了多少份，不展示每日汇总数量。页面同时保留渠道累计投递率、招聘方查看、回复和最近记录。

## 后端接口

```text
GET  /api/v1/applications/dashboard
POST /api/v1/applications
```

生产环境应从投递事件表和平台同步快照聚合，而不是在客户端计算。建议使用 `application_records` 保存投递事件，使用 `job_snapshots` 保存平台每日上线职位快照，并按 `platform + date` 保存 `submitted_count`；每日页面只读取各平台数量，不再计算每日总量。所有聚合接口必须按当前用户隔离数据，并支持时区参数。
