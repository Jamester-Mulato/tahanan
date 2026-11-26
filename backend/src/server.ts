import { app } from "./app";
import { env } from "./config/env";
import { pool } from "./config/db";
import { initializeDatabase } from "./utils/db-init";
import dns from "node:dns";

async function main() {
  // Some networks advertise IPv6 without a working route (SMTP then fails
  // with ENETUNREACH). Prefer IPv4 for outbound hostnames like smtp.gmail.com.
  dns.setDefaultResultOrder("ipv4first");

  await initializeDatabase();

  const server = app.listen(env.PORT, () => {
    console.log(`Tahanan API running at http://localhost:${env.PORT}`);
  });

  const shutdown = async (signal: string) => {
    console.log(`Received ${signal}. Shutting down...`);
    server.close(async () => {
      await pool.end();
      process.exit(0);
    });
  };

  process.on("SIGINT", () => void shutdown("SIGINT"));
  process.on("SIGTERM", () => void shutdown("SIGTERM"));
}

main().catch(async (error) => {
  console.error("Tahanan backend failed to start:", error);
  await pool.end();
  process.exit(1);
});
