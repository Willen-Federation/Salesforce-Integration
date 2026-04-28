const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    // Jestのカスタム設定をここに追加できます
    // 例: moduleNameMapper: { '^c/myComponent$': '<rootDir>/force-app/test/jest-mocks/c/myComponent' }
};