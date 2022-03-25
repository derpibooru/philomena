import fs from 'fs';
import path from 'path';
import url from 'url';
import TerserPlugin from 'terser-webpack-plugin';
import CssMinimizerPlugin from 'css-minimizer-webpack-plugin';
import CopyPlugin from 'copy-webpack-plugin';
import MiniCssExtractPlugin from "mini-css-extract-plugin";
import IgnoreEmitPlugin from 'ignore-emit-webpack-plugin';
import ESLintPlugin from 'eslint-webpack-plugin';
import autoprefixer from 'autoprefixer';
import rollupPluginIncludepaths from 'rollup-plugin-includepaths';
import rollupPluginMultiEntry from 'rollup-plugin-multi-entry';
import rollupPluginBuble from 'rollup-plugin-buble';
import rollupPluginTypescript from '@rollup/plugin-typescript';

const isDevelopment = process.env.NODE_ENV !== 'production';
const __dirname = path.dirname(url.fileURLToPath(import.meta.url));

const includePaths = rollupPluginIncludepaths();
const multiEntry = rollupPluginMultiEntry();
const buble = rollupPluginBuble({ transforms: { dangerousForOf: true } });
const typescript = rollupPluginTypescript();

let plugins = [
  new IgnoreEmitPlugin(/css\/.*(?<!css)$/),
  new MiniCssExtractPlugin({
    filename: '[name].css',
    chunkFilename: '[id].css'
  }),
  new CopyPlugin({
    patterns: [
      { from: path.resolve(__dirname, 'static') },
    ],
  }),
];
if (isDevelopment) {
  plugins = plugins.concat([
    new ESLintPlugin({
      extensions: ['js', 'ts'],
      failOnError: true,
      failOnWarning: isDevelopment
    })
  ]);
}
else {
  plugins = plugins.concat([
    new TerserPlugin({
      cache: true,
      parallel: true,
      sourceMap: isDevelopment,
    }),
    new CssMinimizerPlugin(),
  ]);
}

const themeNames =
  fs.readdirSync(path.resolve(__dirname, 'css/themes')).map(name =>
    name.match(/([-a-z]+).scss/)[1]
  );

const themes = {};
for (const name of themeNames) {
  themes[`css/${name}`] = `./css/themes/${name}.scss`;
}

export default {
  mode: isDevelopment ? 'development' : 'production',
  entry: {
    'js/app.js': './js/app.js',
    ...themes
  },
  output: {
    filename: '[name]',
    path: path.resolve(__dirname, '../priv/static'),
  },
  optimization: {
    minimize: !isDevelopment,
    providedExports: true,
    usedExports: true,
    concatenateModules: true,
  },
  devtool: isDevelopment ? 'inline-source-map' : undefined,
  performance: { hints: false },
  resolve: {
    alias: {
      common: path.resolve(__dirname, 'css/common/'),
      views: path.resolve(__dirname, 'css/views/')
    }
  },
  module: {
    rules: [
      {
        test: /\.(ttf|eot|svg|woff2?)$/,
        loader: 'file-loader',
        options: {
          name: '[name].[ext]',
          outputPath: './fonts',
          publicPath: '../fonts',
        },
      },
      {
        test: /app\.js/,
        use: [
          {
            loader: 'webpack-rollup-loader',
            options: {
              plugins: [
                buble,
                includePaths,
                multiEntry,
                typescript,
              ]
            }
          },
        ],
      },
      {
        test: /\.scss$/,
        use: [
          MiniCssExtractPlugin.loader,
          {
            loader: 'css-loader',
            options: {
              sourceMap: isDevelopment,
              url: (url) => !url.startsWith('/'),
            },
          },
          {
            loader: 'postcss-loader',
            options: {
              postcssOptions: {
                sourceMaps: isDevelopment,
                ident: 'postcss',
                syntax: 'postcss-scss',
                plugins: [
                  autoprefixer(),
                ],
              },
            },
          },
          {
            loader: 'sass-loader',
            options: {
              sourceMap: isDevelopment,
              sassOptions: {
                quietDeps: true
              }
            }
          },
        ]
      },
    ],
  },
  plugins,
};
