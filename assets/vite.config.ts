import fs from 'fs';
import path from 'path';
import autoprefixer from 'autoprefixer';
import { defineConfig, UserConfig, ConfigEnv } from 'vite';

export default defineConfig(({ command }: ConfigEnv): UserConfig => {
  const isDev = command !== 'build';

  if (isDev) {
    process.stdin.on('close', () => {
      // eslint-disable-next-line no-process-exit
      process.exit(0);
    });

    process.stdin.resume();
  }

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
      target: 'es2020',
      outDir: path.resolve(__dirname, '../priv/static'),
      emptyOutDir: false,
      sourcemap: isDev,
      manifest: false,
      cssCodeSplit: true,
      rollupOptions: {
        input: {
          'js/app': './js/app.js',
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
    }
  };
});
