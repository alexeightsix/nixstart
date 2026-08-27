import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { runToggleSkillsCommand } from "./command.ts";
import type { ToggleSkillsCommandDeps } from "./command.ts";
import type { ApplyResult, SkillChange, SkillDraft, SkillRecord, SkillToggleUiResult } from "./types.ts";

// Reloading is the half of /toggle-skills with no visible failure: a skill whose
// frontmatter changed but which pi never re-read stays active for the rest of the
// session, and the notification still says the change was applied.

const record = (name: string): SkillRecord => ({
  id: `/skills/${name}/SKILL.md`,
  name,
  description: `${name} skill`,
  filePath: `/skills/${name}/SKILL.md`,
  baseDir: `/skills/${name}`,
  source: { kind: "user", root: "/skills" },
  editable: true,
  mode: "agent-invocable",
  diagnostics: [],
});

const change = (skill: SkillRecord): SkillChange => ({
  skill,
  filePath: skill.filePath,
  from: "agent-invocable",
  to: "manual-only",
  patch: { oldText: "old", newText: "new" },
});

interface Harness {
  ctx: any;
  notifications: Array<{ message: string; level: string }>;
  reloads: number;
  planned: number;
  writes: SkillChange[][];
  deps: ToggleSkillsCommandDeps;
}

const harness = (options: {
  skills?: SkillRecord[];
  ui?: SkillToggleUiResult;
  changes?: SkillChange[];
  applyResult?: ApplyResult;
  hasUI?: boolean;
  loadError?: Error;
}): Harness => {
  const skills = options.skills ?? [record("demo")];
  const notifications: Array<{ message: string; level: string }> = [];
  const writes: SkillChange[][] = [];
  const state = { reloads: 0, planned: 0 };

  const ctx = {
    cwd: "/project",
    hasUI: options.hasUI ?? true,
    ui: {
      notify: (message: string, level: string) => {
        notifications.push({ message, level });
      },
    },
    reload: async () => {
      state.reloads += 1;
    },
  };

  const deps: ToggleSkillsCommandDeps = {
    inventory: {
      load: async () => {
        if (options.loadError) throw options.loadError;
        return skills;
      },
    },
    planner: {
      plan: async (_records: SkillRecord[], _drafts: SkillDraft[]) => {
        state.planned += 1;
        return options.changes ?? [];
      },
    },
    writer: {
      apply: async (changes: SkillChange[]) => {
        writes.push(changes);
        return options.applyResult ?? { applied: changes, skipped: [], errors: [] };
      },
    },
    showUi: async () =>
      options.ui ?? {
        action: "apply",
        drafts: skills.map((skill) => ({ skill, desiredMode: "manual-only" as const })),
      },
  };

  return {
    ctx,
    notifications,
    writes,
    deps,
    get reloads() {
      return state.reloads;
    },
    get planned() {
      return state.planned;
    },
  } as Harness;
};

describe("/toggle-skills apply and reload", () => {
  it("writes the planned changes and reloads pi once they land", async () => {
    const skill = record("demo");
    const h = harness({ skills: [skill], changes: [change(skill)] });

    await runToggleSkillsCommand(h.ctx, h.deps);

    assert.equal(h.writes.length, 1);
    assert.equal(h.writes[0].length, 1);
    assert.equal(h.reloads, 1);
    assert.equal(h.notifications[0].level, "info");
    assert.match(h.notifications[0].message, /applied 1 change\./);
    assert.match(h.notifications[0].message, /demo: agent-invocable → manual-only/);
    assert.match(h.notifications[0].message, /Reloaded skills, prompts, extensions, and themes\./);
  });

  it("does not reload when every change was skipped", async () => {
    const skill = record("demo");
    const failed = change(skill);
    const h = harness({
      skills: [skill],
      changes: [failed],
      applyResult: { applied: [], skipped: [], errors: [{ skill, message: "demo: file changed; skipped" }] },
    });

    await runToggleSkillsCommand(h.ctx, h.deps);

    assert.equal(h.reloads, 0);
    assert.equal(h.notifications[0].level, "warning");
    assert.match(h.notifications[0].message, /Errors\/skipped: 1/);
    assert.doesNotMatch(h.notifications[0].message, /Reloaded/);
  });

  it("cancelling plans nothing, writes nothing and leaves pi loaded as-is", async () => {
    const h = harness({ ui: { action: "cancel", drafts: [] } });

    await runToggleSkillsCommand(h.ctx, h.deps);

    assert.equal(h.planned, 0);
    assert.equal(h.writes.length, 0);
    assert.equal(h.reloads, 0);
    assert.deepEqual(h.notifications, []);
  });

  it("reports an empty plan instead of reloading for nothing", async () => {
    const h = harness({ changes: [] });

    await runToggleSkillsCommand(h.ctx, h.deps);

    assert.equal(h.writes.length, 0);
    assert.equal(h.reloads, 0);
    assert.match(h.notifications[0].message, /no changes to apply/);
  });

  it("refuses to run without an interactive UI", async () => {
    const h = harness({ hasUI: false });

    await runToggleSkillsCommand(h.ctx, h.deps);

    assert.equal(h.planned, 0);
    assert.equal(h.reloads, 0);
    assert.equal(h.notifications[0].level, "error");
    assert.match(h.notifications[0].message, /requires interactive mode/);
  });

  it("surfaces a scan failure without touching any file", async () => {
    const h = harness({ loadError: new Error("permission denied") });

    await runToggleSkillsCommand(h.ctx, h.deps);

    assert.equal(h.writes.length, 0);
    assert.equal(h.reloads, 0);
    assert.equal(h.notifications[0].level, "error");
    assert.match(h.notifications[0].message, /failed to scan skills: permission denied/);
  });
});
