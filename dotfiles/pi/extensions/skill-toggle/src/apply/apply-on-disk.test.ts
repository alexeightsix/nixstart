import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, readdir, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, it } from "node:test";

import { DefaultSkillTogglePlanner } from "./planner.ts";
import { AtomicSkillChangeWriter } from "./writer.ts";
import { DefaultSkillLocator } from "../discovery/skill-locator.ts";
import { SimpleFrontmatterCodec } from "../frontmatter/parser.ts";
import { MinimalFrontmatterPatcher } from "../frontmatter/patcher.ts";
import { DefaultSkillInventory } from "../inventory/loader.ts";
import { NodeFileSystem } from "../ports/fs.ts";
import type { SkillRecord } from "../types.ts";

// Patching a string in memory proves nothing about the bytes that land on disk:
// discovery, permissions, the atomic rename and re-classification are all real
// filesystem behaviour, and every one of them fails silently. This exercises the
// same objects the extension builds in index.ts against a temporary skill tree.

const SKILL_BODY = `---
name: demo
description: A demo skill
---

Body line one.

Body line two.
`;

const home = process.env.HOME;
const agentDir = process.env.PI_CODING_AGENT_DIR;

let projectRoot: string;
let skillFile: string;

const build = () => {
  const fs = new NodeFileSystem();
  const codec = new SimpleFrontmatterCodec();
  const locator = new DefaultSkillLocator(fs);
  return {
    inventory: new DefaultSkillInventory(locator, fs, codec),
    planner: new DefaultSkillTogglePlanner(fs, codec, new MinimalFrontmatterPatcher()),
    writer: new AtomicSkillChangeWriter(fs),
  };
};

const findDemo = (records: SkillRecord[]): SkillRecord => {
  const record = records.find((candidate) => candidate.filePath === skillFile);
  assert.ok(record, `demo skill not discovered in ${skillFile}`);
  return record;
};

before(async () => {
  projectRoot = await mkdtemp(join(tmpdir(), "skill-toggle-disk-"));
  // Keep discovery inside the sandbox: the user root follows the agent dir and
  // the global root follows HOME, so neither can reach the real skill tree.
  process.env.HOME = projectRoot;
  process.env.PI_CODING_AGENT_DIR = join(projectRoot, "agent");

  const skillDir = join(projectRoot, ".pi", "skills", "demo");
  await mkdir(skillDir, { recursive: true });
  skillFile = join(skillDir, "SKILL.md");
  await writeFile(skillFile, SKILL_BODY, "utf8");
  await chmod(skillFile, 0o640);
});

after(() => {
  if (home === undefined) delete process.env.HOME;
  else process.env.HOME = home;
  if (agentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = agentDir;
});

describe("applying a skill toggle to a real file", () => {
  it("switches a discovered project skill to manual-only and back byte for byte", async () => {
    const { inventory, planner, writer } = build();

    const discovered = findDemo(await inventory.load(projectRoot));
    assert.equal(discovered.mode, "agent-invocable");
    assert.equal(discovered.editable, true);

    const toManual = await planner.plan([discovered], [{ skill: discovered, desiredMode: "manual-only" }]);
    assert.equal(toManual.length, 1);

    const applied = await writer.apply(toManual);
    assert.deepEqual(applied.errors, []);
    assert.equal(applied.applied.length, 1);

    const patched = await readFile(skillFile, "utf8");
    assert.match(patched, /disable-model-invocation: true/);
    assert.match(patched, /name: demo/);
    assert.match(patched, /Body line one\./);
    assert.match(patched, /Body line two\./);

    // The mode is what pi reads back, so re-discover rather than trusting the patch.
    const rediscovered = findDemo(await inventory.load(projectRoot));
    assert.equal(rediscovered.mode, "manual-only");

    const toAutomatic = await planner.plan(
      [rediscovered],
      [{ skill: rediscovered, desiredMode: "agent-invocable" }],
    );
    assert.equal(toAutomatic.length, 1);
    assert.deepEqual((await writer.apply(toAutomatic)).errors, []);

    assert.equal(await readFile(skillFile, "utf8"), SKILL_BODY);
    assert.equal(findDemo(await inventory.load(projectRoot)).mode, "agent-invocable");
  });

  it("preserves file permissions and leaves no temporary files behind", async () => {
    const { inventory, planner, writer } = build();
    const record = findDemo(await inventory.load(projectRoot));

    const changes = await planner.plan([record], [{ skill: record, desiredMode: "manual-only" }]);
    await writer.apply(changes);

    assert.equal((await stat(skillFile)).mode & 0o777, 0o640);
    assert.deepEqual(await readdir(join(projectRoot, ".pi", "skills", "demo")), ["SKILL.md"]);

    const back = findDemo(await inventory.load(projectRoot));
    await writer.apply(await planner.plan([back], [{ skill: back, desiredMode: "agent-invocable" }]));
    assert.equal(await readFile(skillFile, "utf8"), SKILL_BODY);
  });

  it("refuses to clobber a file edited while the overlay was open", async () => {
    const { inventory, planner, writer } = build();
    const record = findDemo(await inventory.load(projectRoot));
    const changes = await planner.plan([record], [{ skill: record, desiredMode: "manual-only" }]);

    const edited = SKILL_BODY.replace("A demo skill", "Edited underneath");
    await writeFile(skillFile, edited, "utf8");

    const applied = await writer.apply(changes);
    assert.equal(applied.applied.length, 0);
    assert.equal(applied.errors.length, 1);
    assert.match(applied.errors[0].message, /file changed while dialog was open/);
    assert.equal(await readFile(skillFile, "utf8"), edited);

    await writeFile(skillFile, SKILL_BODY, "utf8");
  });

  it("plans nothing when the skill is already in the requested mode", async () => {
    const { inventory, planner } = build();
    const record = findDemo(await inventory.load(projectRoot));
    assert.deepEqual(await planner.plan([record], [{ skill: record, desiredMode: "agent-invocable" }]), []);
  });
});
