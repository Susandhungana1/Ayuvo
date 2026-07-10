// Tiny IndexedDB key/value cache for offline-first reads.
// Lists fetched from the API are cached here so the app can still show the
// user's records when the network (or backend) is unavailable.

const DB_NAME = 'medistore-cache';
const STORE = 'kv';
const VERSION = 1;

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined') {
      reject(new Error('IndexedDB unavailable'));
      return;
    }
    const req = indexedDB.open(DB_NAME, VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export interface Cached<T> {
  data: T;
  savedAt: number; // epoch ms
}

export async function cacheSet<T>(key: string, data: T): Promise<void> {
  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).put({ data, savedAt: Date.now() } as Cached<T>, key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  } catch {
    /* caching is best-effort; ignore failures (e.g. private mode) */
  }
}

export async function cacheGet<T>(key: string): Promise<Cached<T> | null> {
  try {
    const db = await openDb();
    const result = await new Promise<Cached<T> | null>((resolve, reject) => {
      const tx = db.transaction(STORE, 'readonly');
      const req = tx.objectStore(STORE).get(key);
      req.onsuccess = () => resolve((req.result as Cached<T>) ?? null);
      req.onerror = () => reject(req.error);
    });
    db.close();
    return result;
  } catch {
    return null;
  }
}
