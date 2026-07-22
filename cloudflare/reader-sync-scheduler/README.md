# Reader Cloudflare 调度器

Cloudflare Workflow 是唯一的远端调度器：每 5 分钟运行一次本机 Reader 同步，每小时第 17 分钟触发一次 WeRSS 抓取并在完成后同步。Workflow 通过 Access Service Token 访问现有 Reader Access 应用，再经 Cloudflare Tunnel 到达仅监听 `127.0.0.1:8787` 的控制端。

## 首次配置

1. 在 Cloudflare Zero Trust 为 Reader 创建一个 Service Token。
2. 给 Reader Access Application 增加 `Service Auth` policy，只允许该 token。
3. 确保本机 `.env` 已由 `scripts/ensure-reader-refresh-secrets.sh` 生成 `READER_SCHEDULER_SECRET`。
4. 在本目录设置三个 Worker secret：

   ```sh
   npx wrangler secret put READER_ACCESS_CLIENT_ID
   npx wrangler secret put READER_ACCESS_CLIENT_SECRET
   npx wrangler secret put READER_SCHEDULER_SECRET
   ```

5. 测试并部署：

   ```sh
   npm test
   npx wrangler deploy
   ```

6. 在 Cloudflare Dashboard 确认至少一次 `sync` 和一次 `start` 实例成功，再把调度权切给 Workflow：

   ```sh
   ../../scripts/set-werss-native-schedule.sh cloudflare
   ../../scripts/install-reading-sync.sh --cloudflare-driven
   ```

`cloudflare` 模式保持 WeRSS 任务可由受保护控制端执行，但把原生 Cron 停放到闰年 2 月 29 日，避免与 Workflow 每小时重复抓取。回滚时先重新启用 WeRSS Cron 和本机 5 分钟 LaunchAgent。

不要把 Service Token 或 `READER_SCHEDULER_SECRET` 写进 `wrangler.jsonc`、README、日志或 Git。
