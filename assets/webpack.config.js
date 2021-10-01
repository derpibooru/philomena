const fs = require('fs');
const path = require('path');
const TerserPlugin = require('terser-webpack-plugin');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');
const CopyPlugin = require('copy-webpack-plugin');
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const IgnoreEmitPlugin = require('ignore-emit-webpack-plugin');

const isDevelopment = process.env.NODE_ENV !== 'production';

const includePaths = require('rollup-plugin-includepaths')();
const multiEntry = require('rollup-plugin-multi-entry')();
const buble = require('rollup-plugin-buble')({ transforms: { dangerousForOf: true } });

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
if (!isDevelopment){
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

module.exports = {
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
                  require('autoprefixer')(),
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
