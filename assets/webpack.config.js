const path = require('path');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyPlugin = require('copy-webpack-plugin');

const isProduction = process.env.NODE_ENV === 'production';

let plugins = [
  new CopyPlugin({
    patterns: [
      { from: path.resolve(__dirname, 'static') },
    ],
  }),
];
if (isProduction){
  plugins = plugins.concat([
    new UglifyJsPlugin({
      cache: true,
      parallel: true,
    }),
    new OptimizeCSSAssetsPlugin({
      cssProcessorOptions: { discardComments: { removeAll: true } },
      canPrint: true,
    }),
  ]);
}

module.exports = {
  mode: isProduction ? 'production' : 'development',
  entry: {
    'js/app.js': './js/app.js',
  },
  output: {
    filename: '[name]',
    path: path.resolve(__dirname, '../priv/static'),
  },
  optimization: {
    minimize: isProduction,
    providedExports: true,
    usedExports: true,
    concatenateModules: true,
  },
  devtool: isProduction ? undefined : 'inline-source-map',
  performance: { hints: false },
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
        test: /\.js/,
        use: [
          { loader: 'babel-loader' },
        ],
      },
      {
        test: /themes\/[a-z]+\.scss$/,
        use: [
          {
            loader: 'file-loader',
            options: {
              name: '[name].css',
              outputPath: '/css',
              publicPath: '/css',
            },
          },
          { loader: 'extract-loader' },
          { loader: 'css-loader' },
          {
            loader: 'postcss-loader',
            options: {
              ident: 'postcss',
              syntax: 'postcss-scss',
              plugins: [
                require('autoprefixer')({
                  overrideBrowserslist: [
                    'last 2 Android versions',
                    'last 2 Chrome versions',
                    'last 2 ChromeAndroid versions',
                    'last 2 Edge versions',
                    'last 1 Explorer version',
                    'last 1 ExplorerMobile versions',
                    'last 2 Firefox versions',
                    'last 2 FirefoxAndroid versions',
                    'last 2 iOS versions',
                    'last 2 Opera versions',
                  ],
                  add: true,
                }),
              ],
            },
          },
          { loader: 'sass-loader' },
        ],
      },
    ],
  },
  plugins,
};
