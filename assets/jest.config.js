export default {
  collectCoverage: true,
  collectCoverageFrom: [
    'js/**/*.{js,ts}',
  ],
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/.*\\.test\\.ts$',
    '.*\\.d\\.ts$',
  ],
  coverageDirectory: '<rootDir>/coverage/',
  coverageThreshold: {
    global: {
      statements: 0,
      branches: 0,
      functions: 0,
      lines: 0,
    },
    './js/utils/**/*.js': {
      statements: 100,
      branches: 100,
      functions: 100,
      lines: 100,
    },
  },
  preset: 'ts-jest/presets/js-with-ts-esm',
  setupFilesAfterEnv: ['<rootDir>/test/jest-setup.ts'],
  testEnvironment: 'jsdom',
  testPathIgnorePatterns: ['/node_modules/', '/dist/'],
  moduleNameMapper: {
    './js/(.*)': '<rootDir>/js/$1',
  },
  transform: {},
  globals: {
    extensionsToTreatAsEsm: ['.ts', '.js'],
    'ts-jest': {
      tsconfig: '<rootDir>/tsconfig.json',
      useESM: true,
    },
  },
};
