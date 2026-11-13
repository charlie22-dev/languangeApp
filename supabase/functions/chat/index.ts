import { createChatHandler } from "./handler.ts";

// Supabase runs this entry point in Deno; the tutor key stays server-side.
const handler = createChatHandler({
  SUPABASE_URL: Deno.env.get("SUPABASE_URL"),
  SUPABASE_ANON_KEY: Deno.env.get("SUPABASE_ANON_KEY"),
  SUPABASE_PUBLISHABLE_KEY: Deno.env.get("SUPABASE_PUBLISHABLE_KEY"),
  SUPABASE_PUBLISHABLE_KEYS: Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"),
  GROQ_API_KEY: Deno.env.get("GROQ_API_KEY"),
  GROQ_MODEL: Deno.env.get("GROQ_MODEL"),
  TUTOR_LANGUAGE: Deno.env.get("TUTOR_LANGUAGE"),
  ALLOWED_ORIGINS: Deno.env.get("ALLOWED_ORIGINS"),
});

Deno.serve(handler);
