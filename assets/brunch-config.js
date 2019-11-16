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
        includePaths: ['css', 'node_modules/font-awesome/scss']
      }
    },
    copycat: {
      fonts: ['node_modules/font-awesome/fonts'],
      verbose: false,
      onlyChanged: true
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
