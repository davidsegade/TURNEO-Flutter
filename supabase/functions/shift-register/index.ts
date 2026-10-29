import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export const registrationLocalUserIds = ['u4', 'u5'] as const;

export function isAllowedRegistrationUser(localUserId: unknown): localUserId is 'u4' | 'u5' {
  return typeof localUserId === 'string' &&
      registrationLocalUserIds.includes(localUserId as 'u4' | 'u5');
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function errorResponse() {
  // Do not disclose whether an email, invite, or roster ID exists.
  return json({ error: 'No se ha podido registrar el acceso.' }, 400);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return errorResponse();

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const inviteCode = Deno.env.get('SHIFT_REGISTER_INVITE_CODE');
  if (!supabaseUrl || !serviceRoleKey || !inviteCode) return errorResponse();

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return errorResponse();
  }

  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const submittedInvite = typeof body.inviteCode === 'string' ? body.inviteCode : '';
  const localUserId = body.localUserId;
  if (!email || password.length < 8 || submittedInvite !== inviteCode ||
      !isAllowedRegistrationUser(localUserId)) {
    return errorResponse();
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: rosterUser, error: rosterError } = await admin
      .from('app_users')
      .select('id,local_user_id,active,auth_uid')
      .eq('app_id', 'default')
      .eq('local_user_id', localUserId)
      .eq('active', true)
      .is('auth_uid', null)
      .maybeSingle();
  if (rosterError || !rosterUser) return errorResponse();

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createError || !created.user) return errorResponse();

  const { data: linked, error: linkError } = await admin
      .from('app_users')
      .update({ auth_uid: created.user.id })
      .eq('id', rosterUser.id)
      .eq('app_id', 'default')
      .eq('local_user_id', localUserId)
      .eq('active', true)
      .select('id')
      .maybeSingle();

  if (linkError || !linked) {
    // Roll back the Auth row if the roster link was not persisted.
    await admin.auth.admin.deleteUser(created.user.id);
    return errorResponse();
  }

  return json({ ok: true });
});
