import js from '@eslint/js'
import globals from 'globals'
import react from 'eslint-plugin-react'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'

// The `lint` script has always referenced a config that was never committed, so
// `npm run lint` failed outright. This is that config, using the plugins
// already present in devDependencies.
export default [
  { ignores: ['dist', 'dev-dist', 'node_modules'] },
  js.configs.recommended,
  {
    files: ['**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: { ...globals.browser, ...globals.es2021 },
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
    },
    settings: { react: { version: 'detect' } },
    plugins: {
      react,
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...react.configs.recommended.rules,
      ...react.configs['jsx-runtime'].rules,
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': [
        'warn',
        { allowConstantExport: true },
      ],
      // Context files intentionally export both a provider and its hook.
      'react/prop-types': 'off',
      // This codebase still writes `import React from 'react'` even though the
      // automatic JSX runtime makes it unnecessary. Harmless, and rewriting
      // every file to drop it is unrelated churn — so it is not an error.
      'no-unused-vars': [
        'error',
        { varsIgnorePattern: '^React$', argsIgnorePattern: '^_' },
      ],
    },
  },
  {
    // Context files deliberately export a provider component *and* its hook —
    // that pairing is the documented pattern in this codebase, so the
    // fast-refresh rule does not apply here.
    files: ['src/contexts/**/*.jsx'],
    rules: { 'react-refresh/only-export-components': 'off' },
  },
  {
    // Config files run in Node.
    files: ['vite.config.js', 'eslint.config.js'],
    languageOptions: { globals: { ...globals.node } },
  },
]
