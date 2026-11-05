# Notes: lint skill loses its rules in Copilot

- It's the lint-fix skill from one of the plugins we install, I'm not sure which one any more.
- Works in Claude Code 2.3.1: asking "fix the lint errors in src/" runs eslint --fix and then
  explains each remaining error.
- In Copilot CLI 1.0.80 the same request just runs eslint with no --fix and stops. Same
  every time, tried it 4 times this morning.
- To see it: open the web repo, ask Copilot CLI "fix the lint errors in src/".
- Why it matters: people on Copilot think the skill is broken and fix lint by hand, which
  is most of the reason we installed it.
