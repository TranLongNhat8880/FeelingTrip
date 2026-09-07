const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

/**
 * Recursively scans and validates JavaScript syntax using `node --check`.
 * Validates all files individually so syntax errors cannot be skipped.
 */
function checkSyntax(directory) {
  let count = 0;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      count += checkSyntax(fullPath);
    } else if (fullPath.endsWith('.js')) {
      execFileSync(process.execPath, ['--check', fullPath], { stdio: 'inherit' });
      count++;
    }
  }
  return count;
}

const targetDirs = [
  path.join(__dirname, '../src'),
  __dirname,
  path.join(__dirname, '../test'),
];

let totalChecked = 0;
for (const dir of targetDirs) {
  if (fs.existsSync(dir)) {
    totalChecked += checkSyntax(dir);
  }
}

console.log(`All ${totalChecked} JavaScript files passed syntax checks.`);
