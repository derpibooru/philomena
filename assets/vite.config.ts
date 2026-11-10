import fs from 'fs';
import path from 'path';
import autoprefixer from 'autoprefixer';
import postcssMixins from 'postcss-mixins';
import postcssSimpleVars from 'postcss-simple-vars';
import postcssRelativeColor from '@csstools/postcss-relative-color-syntax';
import { defineConfig } from 'vitest/config';
import type { ConfigEnv, ViteUserConfig } from 'vitest/config';

export default defineConfig(({ command, mode }: ConfigEnv): ViteUserConfig => {
  const isDev = command !== 'build' && mode !== 'test';
  const targets = new Map();

  fs.readdirSync(path.resolve(import.meta.dirname, 'css/themes/')).forEach(name => {
    const m = name.match(/([-a-z]+).css/);

    if (m) targets.set(`css/${m[1]}`, `./css/themes/${m[1]}.css`);
  });

  fs.readdirSync(path.resolve(import.meta.dirname, 'css/options/')).forEach(name => {
    const m = name.match(/([-a-z]+).css/);

    if (m) targets.set(`css/options/${m[1]}`, `./css/options/${m[1]}.css`);
  });

  return {
    publicDir: 'static',
    plugins: [],
    server: {
      host: '0.0.0.0',
      port: 5173,
      cors: true,
    },
    resolve: {
      alias: {
        common: path.resolve(import.meta.dirname, 'css/common/'),
        views: path.resolve(import.meta.dirname, 'css/views/'),
        elements: path.resolve(import.meta.dirname, 'css/elements/'),
        themes: path.resolve(import.meta.dirname, 'css/themes/'),
      },
    },
    build: {
      target: ['es2019', 'chrome80', 'firefox69', 'edge80', 'safari15', 'ios15', 'opera63'],
      outDir: path.resolve(import.meta.dirname, '../priv/static'),
      emptyOutDir: false,
      sourcemap: isDev,
      manifest: false,
      cssCodeSplit: true,
      rollupOptions: {
        input: {
          'js/app': './js/app.ts',
          'css/application': './css/application.css',
          ...Object.fromEntries(targets),
        },
        output: {
          entryFileNames: '[name].js',
          chunkFileNames: '[name].js',
          assetFileNames: '[name][extname]',
        },
      },
    },
    css: {
      postcss: {
        plugins: [postcssMixins(), postcssSimpleVars(), postcssRelativeColor(), autoprefixer],
      },
    },
    test: {
      globals: true,
      environment: 'jsdom',
      exclude: ['**/node_modules/**', '.*\\.test\\.ts$', '.*\\.d\\.ts$', '.*\\.spec\\.ts$'],
      // TODO Jest --randomize CLI flag equivalent, consider enabling in the future
      // sequence: { shuffle: true },
      setupFiles: './test/vitest-setup.ts',
      coverage: {
        reporter: ['text', 'html'],
        include: ['js/**/*.{js,ts}'],
        exclude: ['js/app.ts', '**/__tests__/**'],
        thresholds: {
          statements: 0,
          branches: 0,
          functions: 0,
          lines: 0,
          '**/query/**/*.ts': {
            statements: 100,
            branches: 100,
            functions: 100,
            lines: 100,
          },
          '**/utils/**/*.ts': {
            statements: 100,
            branches: 100,
            functions: 100,
            lines: 100,
          },
        },
      },
    },
  };
});
