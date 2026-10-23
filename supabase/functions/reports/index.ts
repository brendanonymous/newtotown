import { createReportsHandler } from "./handler.ts";

function requiredSetting(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server setting: ${name}`);
  return value;
}
Deno.serve(createReportsHandler({
  projectURL: requiredSetting("SUPABASE_URL"),
  publicKey: requiredSetting("SUPABASE_ANON_KEY"),
  adminKey: requiredSetting("SUPABASE_SERVICE_ROLE_KEY"),
}));
