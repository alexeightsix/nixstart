import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    'intro',
    'install',
    {
      type: 'category',
      label: 'Using the editor',
      collapsed: false,
      items: [
        'models',
        'modes',
        'vim-prompt',
        'sessions',
        'send-hold',
        'todo',
        'questions',
        'guardrails',
        'notifications',
        'keybindings',
      ],
    },
    {
      type: 'category',
      label: 'Seeing what is going on',
      collapsed: false,
      items: ['statusline', 'code-rendering', 'dashboard', 'stats', 'docs-command', 'shell-log', 'housekeeping'],
    },
    {
      type: 'category',
      label: 'Capabilities',
      collapsed: false,
      items: ['toolchain', 'skills', 'tldr', 'mcp', 'lsp', 'subagents'],
    },
    'testing',
    'roadmap',
    'changelog',
  ],
};

export default sidebars;
