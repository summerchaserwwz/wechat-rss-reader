export const SYNC_CRON = "*/5 * * * *";
export const FULL_REFRESH_CRON = "17 * * * *";
const MAX_POLLS = 360;

export function actionForCron(cron) {
  return cron === FULL_REFRESH_CRON ? "start" : "sync";
}

export function scheduledWorkflowOptions(controller) {
  const cron = controller?.cron;
  const scheduledTime = Number(controller?.scheduledTime);
  if (![SYNC_CRON, FULL_REFRESH_CRON].includes(cron)) {
    throw new Error(`未知 Cron: ${cron || "empty"}`);
  }
  if (!Number.isFinite(scheduledTime)) {
    throw new Error("Cron 缺少 scheduledTime");
  }
  const action = actionForCron(cron);
  return {
    id: `${action}-${scheduledTime}`,
    params: { cron },
  };
}

export function accessHeaders(env) {
  const required = [
    "READER_ACCESS_CLIENT_ID",
    "READER_ACCESS_CLIENT_SECRET",
    "READER_SCHEDULER_SECRET",
  ];
  for (const name of required) {
    if (!env[name]) throw new Error(`缺少 Worker secret: ${name}`);
  }
  return {
    "Content-Type": "application/json",
    "CF-Access-Client-Id": env.READER_ACCESS_CLIENT_ID,
    "CF-Access-Client-Secret": env.READER_ACCESS_CLIENT_SECRET,
    "X-Reader-Scheduler-Secret": env.READER_SCHEDULER_SECRET,
  };
}

async function controlRequest(env, httpFetch, action) {
  if (!env.READER_REFRESH_URL?.startsWith("https://")) {
    throw new Error("READER_REFRESH_URL 必须使用 HTTPS");
  }
  const response = await httpFetch(env.READER_REFRESH_URL, {
    method: "POST",
    headers: accessHeaders(env),
    body: JSON.stringify({ action }),
  });
  let payload;
  try {
    payload = await response.json();
  } catch {
    throw new Error(`刷新控制端返回非 JSON（HTTP ${response.status}）`);
  }
  if (!response.ok || !payload || typeof payload !== "object") {
    throw new Error(`刷新控制端拒绝请求（HTTP ${response.status}）`);
  }
  return payload;
}

export async function runScheduledWorkflow(event, step, env, httpFetch = fetch) {
  const cron = event?.params?.cron || event?.schedule?.cron || event?.payload?.cron || SYNC_CRON;
  const action = actionForCron(cron);
  let status = await step.do(
    `trigger-${action}`,
    {
      retries: { limit: 5, delay: "10 seconds", backoff: "exponential" },
      timeout: "30 seconds",
    },
    () => controlRequest(env, httpFetch, action),
  );

  if (status.phase === "cooldown") {
    return { action, phase: "cooldown", skipped: true };
  }
  if (status.phase === "single_flight") {
    return { action, phase: "single_flight", skipped: true };
  }

  for (let index = 0; index < MAX_POLLS; index += 1) {
    if (status.phase === "complete") {
      return {
        action,
        phase: "complete",
        new_articles: Number(status.new_articles || 0),
        completed_at: status.completed_at || "",
      };
    }
    if (status.phase === "failed") {
      throw new Error("本机同步任务失败");
    }
    await step.sleep(`wait-${index}`, "30 seconds");
    status = await step.do(
      `status-${index}`,
      {
        retries: { limit: 5, delay: "10 seconds", backoff: "exponential" },
        timeout: "30 seconds",
      },
      () => controlRequest(env, httpFetch, "status"),
    );
  }
  throw new Error("本机同步任务超过 3 小时仍未完成");
}
