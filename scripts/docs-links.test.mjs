// Every link in docs/ works: each relative link names a file that exists, each
// #anchor names a heading in its page, each sidebar entry is a page, and every
// page is in the sidebar. Links resolve from the page that holds them, as on
// GitHub and in docsify (relativePath: true); the sidebar's start from docs/.

import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const DOCS = join(ROOT, "docs");
const LINK = /\]\(([^)\s]+)\)/g;

function pages(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...pages(path));
    else if (name.endsWith(".md") && name !== "_sidebar.md") out.push(path);
  }
  return out.sort();
}

/** Links in Markdown, skipping fenced code, where a ](...) is not a link. */
function links(markdown) {
  const prose = markdown.replace(/^```[\s\S]*?^```/gm, "").replace(/`[^`\n]*`/g, "");
  return [...prose.matchAll(LINK)].map((m) => m[1]);
}

/** A heading's anchor, as GitHub and docsify make it. */
export function slug(heading) {
  return heading
    .trim()
    .toLowerCase()
    .replace(/[`*_[\]()]/g, "")
    .replace(/[^\p{L}\p{N}\s-]/gu, "")
    .replace(/\s/g, "-");
}

function anchors(file) {
  const text = readFileSync(file, "utf8").replace(/^```[\s\S]*?^```/gm, "");
  return new Set([...text.matchAll(/^#{1,6}\s+(.+)$/gm)].map((m) => slug(m[1])));
}

function broken(from, target) {
  if (/^[a-z]+:/i.test(target)) return null;
  const [path, frag] = target.split("#");
  const file = path ? resolve(dirname(from), path) : from;
  if (!existsSync(file)) return "no such file";
  if (frag && file.endsWith(".md") && !anchors(file).has(frag)) return `no heading #${frag}`;
  return null;
}

test("every relative link in docs/ resolves", () => {
  const bad = [];
  for (const page of pages(DOCS))
    for (const target of links(readFileSync(page, "utf8")))
      if (!target.startsWith("/")) {
        const why = broken(page, target);
        if (why) bad.push(`${relative(ROOT, page)}: ${target} (${why})`);
      }
  assert.deepEqual(bad, []);
});

test("every sidebar entry is a page, and every page is in the sidebar", () => {
  const sidebar = readFileSync(join(DOCS, "_sidebar.md"), "utf8");
  const listed = links(sidebar).map((t) => join(DOCS, t.replace(/^\//, "")));
  assert.deepEqual(
    listed.filter((p) => !existsSync(p)).map((p) => relative(ROOT, p)),
    [],
  );
  assert.deepEqual(
    pages(DOCS)
      .filter((p) => !listed.includes(p))
      .map((p) => relative(ROOT, p)),
    [],
  );
});
