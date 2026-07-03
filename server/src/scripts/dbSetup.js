// Creates the app database role + database (if missing) and applies schema.sql.
// To create the role/database we need a PostgreSQL superuser connection. The
// name of that superuser differs by install: Linux packages create a "postgres"
// role, while macOS installs (Postgres.app, Homebrew) create a superuser named
// after your macOS account instead. So we try a list of likely superuser
// connections and use the first that works, then fall back to shell psql.
import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { config } from '../config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const APP_ROLE = 'midwife_app';
const APP_PASSWORD = 'midwife_app';
const APP_DB = 'midwife_companion';

const currentUser = os.userInfo().username;

// Candidate superuser connections, tried in order. Covers the "postgres" role
// (Linux) and the macOS-username role (Postgres.app / Homebrew), and the
// differing default database names each install ships with.
const adminCandidates = [
  'postgres://postgres@localhost:5432/postgres',
  `postgres://${currentUser}@localhost:5432/postgres`,
  `postgres://${currentUser}@localhost:5432/${currentUser}`,
  `postgres://postgres@localhost:5432/${currentUser}`,
];

const adminSql = [
  `DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${APP_ROLE}') THEN CREATE ROLE ${APP_ROLE} LOGIN PASSWORD '${APP_PASSWORD}'; END IF; END $$;`,
  `SELECT 'CREATE DATABASE ${APP_DB} OWNER ${APP_ROLE}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_DB}')\\gexec`,
].join('\n');

async function runAdminViaPg() {
  let lastErr;
  for (const connectionString of adminCandidates) {
    const client = new pg.Client({ connectionString });
    try {
      await client.connect();
      const roleExists = await client.query(
        'SELECT 1 FROM pg_roles WHERE rolname = $1',
        [APP_ROLE]
      );
      if (roleExists.rowCount === 0) {
        await client.query(`CREATE ROLE ${APP_ROLE} LOGIN PASSWORD '${APP_PASSWORD}'`);
      }
      const dbExists = await client.query(
        'SELECT 1 FROM pg_database WHERE datname = $1',
        [APP_DB]
      );
      if (dbExists.rowCount === 0) {
        await client.query(`CREATE DATABASE ${APP_DB} OWNER ${APP_ROLE}`);
      }
      await client.end();
      return connectionString;
    } catch (err) {
      lastErr = err;
      await client.end().catch(() => {});
    }
  }
  throw lastErr || new Error('No superuser connection candidate succeeded');
}

function runAdminViaShell() {
  const attempts = [
    (sql) => execSync('psql -v ON_ERROR_STOP=1 postgres', { input: sql }),
    (sql) => execSync('su postgres -c "psql -v ON_ERROR_STOP=1"', { input: sql }),
    (sql) => execSync('sudo -u postgres psql -v ON_ERROR_STOP=1', { input: sql }),
  ];
  let lastErr;
  for (const attempt of attempts) {
    try {
      attempt(adminSql);
      return;
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr;
}

async function main() {
  try {
    await runAdminViaPg();
  } catch {
    runAdminViaShell();
  }
  console.log(`Role "${APP_ROLE}" and database "${APP_DB}" are ready.`);

  const schema = readFileSync(path.join(__dirname, '..', 'schema.sql'), 'utf8');
  const client = new pg.Client({ connectionString: config.databaseUrl });
  await client.connect();
  await client.query(schema);
  await client.end();
  console.log('Schema applied.');
}

main().catch((err) => {
  console.error('db:setup failed:', err.message);
  console.error(
    '\nIs PostgreSQL installed and running?\n' +
      '  - macOS: install Postgres.app (https://postgresapp.com), open it, click Start.\n' +
      '  - The connection refused error on port 5432 means nothing is running yet.\n' +
      '\nIf it IS running, you can create the database manually with:\n' +
      `  CREATE ROLE ${APP_ROLE} LOGIN PASSWORD '${APP_PASSWORD}';\n` +
      `  CREATE DATABASE ${APP_DB} OWNER ${APP_ROLE};\n` +
      'then re-run: npm run db:setup'
  );
  process.exit(1);
});
