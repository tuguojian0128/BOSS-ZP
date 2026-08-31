# 简历模块实现说明

当前版本把简历流程收敛为“导入后自动识别，用户校对后保存”，不自动改写用户的经历内容。

## 前端流程（Flutter Web）

```text
选择 PDF / Word / 图片
  ↓
创建导入任务
  ↓
上传文件到短时地址
  ↓
显示识别进度
  ↓
读取结构化简历
  ↓
校对基本信息
  ↓
保存校对结果
```

前端通过 `ResumeRepository` 访问数据，不直接依赖 HTTP，也不保存平台密钥。开发阶段使用 `MockResumeRepository`，后端完成后替换为 REST 实现即可。

## 后端接口契约

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| `POST` | `/api/v1/resumes/import` | 创建导入任务，返回 `resumeId`、`taskId` 和短时 `uploadUrl` |
| `PUT` | `uploadUrl` | 上传原始文件，文件不经过 Flutter Web 服务端 |
| `GET` | `/api/v1/resumes/{id}/parse-task` | 查询识别状态、进度和错误信息 |
| `GET` | `/api/v1/resumes/{id}/profile` | 获取结构化简历 |
| `PATCH` | `/api/v1/resumes/{id}/profile` | 保存用户校对后的内容 |
| `DELETE` | `/api/v1/resumes/{id}` | 删除简历及原始文件 |

识别状态建议统一为：`uploading`、`parsing`、`recognized`、`needsReview`、`failed`。

## 解析服务处理顺序

1. 校验扩展名、MIME、文件大小和真实文件头；
2. 病毒扫描并生成不可预测的对象存储路径；
3. PDF / Word 文本提取，扫描件进入 OCR；
4. 规范化姓名、联系方式、时间区间、公司、岗位、学校、项目和技能；
5. 为每个字段保存 `confidence`，低置信度字段标记为“请校对”；
6. 计算完整度并写入 `ResumeProfile`；
7. 用户确认后保存结构化结果，保留原始识别版本用于审计。

## 生产环境必须补齐

- 上传地址必须短时有效并绑定当前用户；
- 简历原文件和结构化数据传输、存储均加密；
- 明确用户授权、保留期限和一键删除；
- 日志中禁止记录完整手机号、邮箱和简历原文；
- 解析队列需要幂等键，失败后支持重试；
- BOSS 或其他招聘平台投递前必须取得明确授权，Flutter Web 不放平台密钥。

