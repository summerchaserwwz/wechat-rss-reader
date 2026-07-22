import assert from "node:assert/strict";
import test from "node:test";
import {
  FULL_REFRESH_CRON,
  SYNC_CRON,
  accessHeaders,
  actionForCron,
  runScheduledWorkflow,
  scheduledWorkflowOptions,
} from "../src/workflow-logic.js";

const env = {
  READER_REFRESH_URL: "https://reader.example.com/reader-control/refresh",
  READER_ACCESS_CLIENT_ID: "client-id",
  READER_ACCESS_CLIENT_SECRET: "client-secret",
  READER_SCHEDULER_SECRET: "scheduler-secret",
};

function fakeStep() {
  return {
    calls: [],
    async do(name, _options, callback) {
      this.calls.push(name);
      return callback();
    },
    async sleep(name, duration) {
      this.calls.push(`${name}:${duration}`);
    },
  };
}

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

test("五分钟任务只同步，小时任务才触发微信抓取", () => {
  assert.equal(actionForCron(SYNC_CRON), "sync");
  assert.equal(actionForCron(FULL_REFRESH_CRON), "start");
});

test("免费 Cron Trigger 创建幂等 Workflow 实例", () => {
  assert.deepEqual(
    scheduledWorkflowOptions({ cron: SYNC_CRON, scheduledTime: 1784541600000 }),
    {
      id: "sync-1784541600000",
      params: { cron: SYNC_CRON },
    },
  );
  assert.deepEqual(
    scheduledWorkflowOptions({ cron: FULL_REFRESH_CRON, scheduledTime: 1784542620000 }),
    {
      id: "start-1784542620000",
      params: { cron: FULL_REFRESH_CRON },
    },
  );
});

test("Access service token 与调度密钥都随请求发送", () => {
  const headers = accessHeaders(env);
  assert.equal(headers["CF-Access-Client-Id"], "client-id");
  assert.equal(headers["CF-Access-Client-Secret"], "client-secret");
  assert.equal(headers["X-Reader-Scheduler-Secret"], "scheduler-secret");
});

test("Workflow 触发后持续轮询到完成", async () => {
  const step = fakeStep();
  const actions = [];
  const fetcher = async (_url, options) => {
    const action = JSON.parse(options.body).action;
    actions.push(action);
    if (action === "sync") return jsonResponse({ phase: "syncing_reader" }, 202);
    return jsonResponse({ phase: "complete", new_articles: 2, completed_at: "now" });
  };

  const result = await runScheduledWorkflow(
    { params: { cron: SYNC_CRON } },
    step,
    env,
    fetcher,
  );

  assert.deepEqual(actions, ["sync", "status"]);
  assert.equal(result.phase, "complete");
  assert.equal(result.new_articles, 2);
});

test("已有完整抓取运行时跳过重复 Workflow", async () => {
  const step = fakeStep();
  const fetcher = async () => jsonResponse({ phase: "single_flight" }, 202);
  const result = await runScheduledWorkflow(
    { params: { cron: SYNC_CRON } },
    step,
    env,
    fetcher,
  );

  assert.deepEqual(result, { action: "sync", phase: "single_flight", skipped: true });
  assert.deepEqual(step.calls, ["trigger-sync"]);
});

test("小时抓取超过三十分钟但持续有进展时继续等待", async () => {
  const step = fakeStep();
  let polls = 0;
  const fetcher = async (_url, options) => {
    const action = JSON.parse(options.body).action;
    if (action === "start") return jsonResponse({ phase: "checking_werss" }, 202);
    polls += 1;
    if (polls <= 60) return jsonResponse({ phase: "checking_werss" }, 202);
    return jsonResponse({ phase: "complete", new_articles: 8, completed_at: "now" });
  };

  const result = await runScheduledWorkflow(
    { schedule: { cron: FULL_REFRESH_CRON } },
    step,
    env,
    fetcher,
  );

  assert.equal(result.phase, "complete");
  assert.equal(result.new_articles, 8);
  assert.equal(polls, 61);
});

test("刷新控制端失败会让 Workflow 失败并交给平台重试", async () => {
  const step = fakeStep();
  const fetcher = async () => jsonResponse({ phase: "failed" });
  await assert.rejects(
    runScheduledWorkflow({ schedule: { cron: FULL_REFRESH_CRON } }, step, env, fetcher),
    /本机同步任务失败/,
  );
});
