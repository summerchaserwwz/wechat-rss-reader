import { WorkflowEntrypoint } from "cloudflare:workers";
import { runScheduledWorkflow, scheduledWorkflowOptions } from "./workflow-logic.js";

export class ReaderSyncWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    return runScheduledWorkflow(event, step, this.env);
  }
}

export default {
  async fetch() {
    return new Response("Not found", { status: 404 });
  },
  async scheduled(controller, env, ctx) {
    ctx.waitUntil(
      env.READER_SYNC_WORKFLOW.create(scheduledWorkflowOptions(controller)),
    );
  },
};
