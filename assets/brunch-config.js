module.exports = {
  files: {
    javascripts: {joinTo: 'js/app.js'},
    stylesheets: {
      joinTo: {
        'css/default.css': [
          'css/themes/default.scss'
        ],
        'css/dark.css': [
          'css/themes/dark.scss'
        ],
        'css/red.css': [
          'css/themes/red.scss'
        ]
      }
    }
  },
  plugins: {
    rollup: {
      buble: {
        transforms: { dangerousForOf: true }
      }
    },
    sass: {
      mode: 'native',
      options: {
        includePaths: ['css', 'node_modules/@fortawesome/fontawesome-free/scss']
      }
    },
    copycat: {
      fonts: ['node_modules/@fortawesome/fontawesome-free/webfonts'],
      verbose: false,
      onlyChanged: true
    },
    postcss: {
      processors: [
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
            'last 2 Opera versions'
          ],
          add: true
        })
      ]
    }
  },
  conventions: {
    // This option sets where we should place non-css and non-js assets in.
    // By default, we set this to "/assets/static". Files in this directory
    // will be copied to `paths.public`, which is "priv/static" by default.
    assets: /static\//
  },
  paths: {
    watched: ['css/themes/default.scss', 'css/themes/dark.scss', 'css/themes/red.scss', 'js/app.js', 'vendor', 'fonts', 'static'],
    public: '../priv/static'
  },
  modules: {
    definition: false,
    wrapper: false
  },
  npm: {
    enabled: false
  }
};
