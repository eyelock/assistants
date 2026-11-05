import crypto from "node:crypto";
import { db } from "../db";

// Sessions live in Postgres. The cookie holds the session id.

export async function createSession(userId: string): Promise<string> {
  const id = crypto.randomBytes(32).toString("hex");
  await db.query(
    "INSERT INTO sessions (id, user_id, expires_at) VALUES ($1, $2, now() + interval '12 hours')",
    [id, userId],
  );
  return id;
}

export async function deleteSession(id: string): Promise<void> {
  await db.query("DELETE FROM sessions WHERE id = $1", [id]);
}

export async function deleteSessionsForUser(userId: string): Promise<void> {
  await db.query("DELETE FROM sessions WHERE user_id = $1", [userId]);
}
