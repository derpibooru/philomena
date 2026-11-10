import { spawn } from 'child_process';

const process = globalThis.process;
const [cmd, ...args] = process.argv.slice(2);

if (!cmd) {
  console.error('No command provided to watch.js');
  process.exit(1);
}

const child = spawn(cmd, args, { stdio: 'inherit' });

// Listen for stdin closure (when Phoenix shuts down the port)
process.stdin.resume();
process.stdin.on('end', () => {
  child.kill('SIGTERM');
  process.exit(0);
});

// Handle termination signals
process.on('SIGTERM', () => {
  child.kill('SIGTERM');
  process.exit(0);
});

process.on('SIGINT', () => {
  child.kill('SIGINT');
  process.exit(0);
});
