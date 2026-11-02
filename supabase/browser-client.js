// HabitPulse Supabase browser adapter.
// Not imported by the production app yet. This module is for the isolated migration branch.
// Configure window.HABITPULSE_SUPABASE_CONFIG before importing this module.
// Only the publishable/anon key belongs in browser configuration. Never add service_role keys.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const config = window.HABITPULSE_SUPABASE_CONFIG || {};
const supabaseUrl = config.url;
const supabaseKey = config.publishableKey;

if (!supabaseUrl || !supabaseKey) {
  throw new Error('HabitPulse Supabase configuration is missing.');
}

export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});

const PHOTO_BUCKET = 'progress-photos';
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const ALLOWED_PHOTO_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic']);

async function requireUser() {
  const { data, error } = await supabase.auth.getUser();
  if (error) throw error;
  if (!data.user) throw new Error('Debes iniciar sesión para continuar.');
  return data.user;
}

async function insertOwned(table, values) {
  const user = await requireUser();
  const { data, error } = await supabase
    .from(table)
    .insert({ ...values, user_id: user.id })
    .select()
    .single();
  if (error) throw error;
  return data;
}

async function listOwned(table, columns = '*', orderColumn = 'created_at') {
  await requireUser();
  const { data, error } = await supabase
    .from(table)
    .select(columns)
    .order(orderColumn, { ascending: false });
  if (error) throw error;
  return data;
}

export const auth = {
  async signUp({ email, password, displayName, username }) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          display_name: String(displayName || '').trim().slice(0, 40),
          username: String(username || '').trim().slice(0, 24)
        }
      }
    });
    if (error) throw error;
    return data;
  },

  async signIn({ email, password }) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  },

  async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  },

  async requestPasswordReset(email, redirectTo) {
    const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo });
    if (error) throw error;
  },

  async updatePassword(newPassword) {
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    if (error) throw error;
  },

  onChange(callback) {
    return supabase.auth.onAuthStateChange(callback);
  },

  async currentUser() {
    return requireUser();
  }
};

export const profile = {
  async getMine() {
    const user = await requireUser();
    const { data, error } = await supabase
      .from('profiles')
      .select('id, username, display_name, friend_code, avatar_path, created_at')
      .eq('id', user.id)
      .single();
    if (error) throw error;
    return data;
  },

  async updateMine({ username, displayName, avatarPath }) {
    const user = await requireUser();
    const patch = {};
    if (username !== undefined) patch.username = username;
    if (displayName !== undefined) patch.display_name = displayName;
    if (avatarPath !== undefined) patch.avatar_path = avatarPath;
    const { data, error } = await supabase
      .from('profiles')
      .update(patch)
      .eq('id', user.id)
      .select('id, username, display_name, friend_code, avatar_path')
      .single();
    if (error) throw error;
    return data;
  }
};

export const personalData = {
  listHabits: () => listOwned('habits', '*', 'created_at'),
  createHabit: values => insertOwned('habits', values),
  listWorkouts: () => listOwned('workouts', '*', 'workout_date'),
  createWorkout: values => insertOwned('workouts', values),
  listMeals: () => listOwned('meals', '*', 'consumed_at'),
  createMeal: values => insertOwned('meals', values),
  listTasks: () => listOwned('tasks', '*', 'due_at'),
  createTask: values => insertOwned('tasks', values),
  listBodyMetrics: () => listOwned('body_metrics', '*', 'measured_at'),
  createBodyMetric: values => insertOwned('body_metrics', values)
};

export const habitEntries = {
  async listForHabit(habitId) {
    await requireUser();
    const { data, error } = await supabase
      .from('habit_entries')
      .select('*')
      .eq('habit_id', habitId)
      .order('entry_date', { ascending: false });
    if (error) throw error;
    return data || [];
  },

  async setCompletion({ habitId, entryDate, completed, note = null }) {
    const user = await requireUser();
    const { data, error } = await supabase
      .from('habit_entries')
      .upsert({
        habit_id: habitId,
        user_id: user.id,
        entry_date: entryDate,
        completed: Boolean(completed),
        note
      }, { onConflict: 'habit_id,entry_date' })
      .select()
      .single();
    if (error) throw error;
    return data;
  }
};

export const challenges = {
  async create({ title, description, startsOn, endsOn, metric = 'habit_completions', targetValue = null }) {
    const user = await requireUser();
    const { data, error } = await supabase
      .from('challenges')
      .insert({
        created_by: user.id,
        title,
        description: description || null,
        starts_on: startsOn,
        ends_on: endsOn,
        metric,
        target_value: targetValue
      })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async listMineAndJoined() {
    await requireUser();
    const { data, error } = await supabase
      .from('challenges')
      .select('*, challenge_members(user_id, joined_at)')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  },

  async join(challengeId) {
    const user = await requireUser();
    const { error } = await supabase
      .from('challenge_members')
      .insert({ challenge_id: challengeId, user_id: user.id });
    if (error) throw error;
  },

  async addEntry({ challengeId, entryDate, value = 1, note = null }) {
    const user = await requireUser();
    const { data, error } = await supabase
      .from('challenge_entries')
      .insert({
        challenge_id: challengeId,
        user_id: user.id,
        entry_date: entryDate || new Date().toISOString().slice(0, 10),
        value,
        note
      })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async listEntries(challengeId) {
    await requireUser();
    const { data, error } = await supabase
      .from('challenge_entries')
      .select('*')
      .eq('challenge_id', challengeId)
      .order('entry_date', { ascending: true });
    if (error) throw error;
    return data || [];
  }
};

export const friendRequests = {
  async inbox() {
    const user = await requireUser();
    const { data, error } = await supabase
      .from('friend_requests')
      .select('id, sender_id, recipient_id, status, created_at')
      .eq('recipient_id', user.id)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  },

  async sent() {
    const user = await requireUser();
    const { data, error } = await supabase
      .from('friend_requests')
      .select('id, sender_id, recipient_id, status, created_at')
      .eq('sender_id', user.id)
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }
};

export const friends = {
  async findByCode(friendCode) {
    await requireUser();
    const { data, error } = await supabase.rpc('find_profile_by_friend_code', {
      p_friend_code: String(friendCode || '').trim().toUpperCase()
    });
    if (error) throw error;
    return data?.[0] || null;
  },

  async requestByCode(friendCode) {
    await requireUser();
    const { data, error } = await supabase.rpc('request_friend_by_code', {
      p_friend_code: String(friendCode || '').trim().toUpperCase()
    });
    if (error) throw error;
    return data;
  },

  async list() {
    await requireUser();
    const { data, error } = await supabase.rpc('list_my_friends');
    if (error) throw error;
    return data || [];
  },

  async respond(requestId, response) {
    await requireUser();
    if (!['accepted', 'rejected'].includes(response)) {
      throw new Error('Respuesta de amistad no válida.');
    }
    const { error } = await supabase.rpc('respond_to_friend_request', {
      p_request_id: requestId,
      p_response: response
    });
    if (error) throw error;
  }
};

export const progressPhotos = {
  async upload(file, { takenAt, caption } = {}) {
    const user = await requireUser();
    if (!(file instanceof File)) throw new Error('Archivo de imagen no válido.');
    if (!ALLOWED_PHOTO_TYPES.has(file.type)) throw new Error('Formato de imagen no admitido.');
    if (file.size > MAX_PHOTO_BYTES) throw new Error('La imagen supera el límite de 5 MB.');
    const extension = ({ 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic' })[file.type];
    const storagePath = user.id + '/' + crypto.randomUUID() + '.' + extension;

    const { error: uploadError } = await supabase.storage
      .from(PHOTO_BUCKET)
      .upload(storagePath, file, { contentType: file.type, upsert: false });
    if (uploadError) throw uploadError;

    const { data, error: metadataError } = await supabase
      .from('progress_photos')
      .insert({
        user_id: user.id,
        storage_path: storagePath,
        taken_at: takenAt || new Date().toISOString(),
        caption: caption || null
      })
      .select()
      .single();

    if (metadataError) {
      await supabase.storage.from(PHOTO_BUCKET).remove([storagePath]);
      throw metadataError;
    }
    return data;
  },

  async signedUrl(storagePath, expiresInSeconds = 60) {
    await requireUser();
    const { data, error } = await supabase.storage
      .from(PHOTO_BUCKET)
      .createSignedUrl(storagePath, expiresInSeconds);
    if (error) throw error;
    return data.signedUrl;
  },

  async remove(photo) {
    const user = await requireUser();
    if (!photo?.id || !photo?.storage_path || !photo.storage_path.startsWith(user.id + '/')) {
      throw new Error('No se puede eliminar esta fotografía.');
    }
    const { error: storageError } = await supabase.storage.from(PHOTO_BUCKET).remove([photo.storage_path]);
    if (storageError) throw storageError;
    const { error } = await supabase.from('progress_photos').delete().eq('id', photo.id);
    if (error) throw error;
  }
};
