/* ===================== SUPABASE CLIENT ===================== */
/* Loaded first on every page, right after the @supabase/supabase-js UMD
   script tag (which sets the global `supabase` to the library namespace —
   our client instance below is deliberately named `sb`, not `supabase`,
   so it doesn't collide with that namespace). */
const SUPABASE_URL = 'https://rgdgklcybymouqnpsyrh.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_cysHO1NeQbYSG-kEZ6ZmQw_zmBE8hTP';

/* Safe to be public: every table this key can touch is governed by Row
   Level Security policies (see supabase/schema.sql), not by hiding this key. */
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
