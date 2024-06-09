/// <reference types="vitest" />
import fs from 'fs';
import path from 'path';
import autoprefixer from 'autoprefixer';
import { defineConfig, UserConfig, ConfigEnv } from 'vite';

export default defineConfig(({ command, mode }: ConfigEnv): UserConfig => {
  const isDev = command !== 'build' && mode !== 'test';

  const themeNames =
    fs.readdirSync(path.resolve(__dirname, 'css/themes/')).map(name => {
      const m = name.match(/([-a-z]+).scss/);

      if (m) { return m[1]; }
      return null;
    });

  const themes = new Map();

  for (const name of themeNames) {
    themes.set(`css/${name}`, `./css/themes/${name}.scss`);
  }

  return {
    publicDir: 'static',
    plugins: [],
    resolve: {
      alias: {
        common: path.resolve(__dirname, 'css/common/'),
        views: path.resolve(__dirname, 'css/views/')
      }
    },
    build: {
      target: ['es2016', 'chrome67', 'firefox62', 'edge18', 'safari12'],
      outDir: path.resolve(__dirname, '../priv/static'),
      emptyOutDir: false,
      sourcemap: isDev,
      manifest: false,
      cssCodeSplit: true,
      rollupOptions: {
        input: {
          'js/app': './js/app.ts',
          ...Object.fromEntries(themes)
        },
        output: {
          entryFileNames: '[name].js',
          chunkFileNames: '[name].js',
          assetFileNames: '[name][extname]'
        }
      }
    },
    css: {
      postcss:  {
        plugins: [autoprefixer]
      }
    },
    test: {
      globals: true,
      environment: 'jsdom',
      // TODO Jest --randomize CLI flag equivalent, consider enabling in the future
      // sequence: { shuffle: true },
      setupFiles: './test/vitest-setup.ts',
      coverage: {
        reporter: ['text', 'html'],
        include: ['js/**/*.{js,ts}'],
        exclude: [
          'node_modules/',
          '.*\\.test\\.ts$',
          '.*\\.d\\.ts$',
        ],
        thresholds: {
          statements: 0,
          branches: 0,
          functions: 0,
          lines: 0,
          '**/utils/**/*.ts': {
            statements: 100,
            branches: 100,
            functions: 100,
            lines: 100,
          },
        }
      }
    }
  };
});
