import 'dotenv/config';
import { defineConfig } from 'prisma/config';

declare const process: { env: Record<string, string | undefined> };

const fallbackDatabaseUrl = 'postgresql://postgres:postgres@127.0.0.1:5432/news_app?schema=public';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: process.env.DIRECT_URL || process.env.DATABASE_URL || fallbackDatabaseUrl,
  },
});
