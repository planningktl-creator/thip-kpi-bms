/** Keep the wall-clock deadline active even after HTTP headers arrive. */
export function abortable<T>(promise: Promise<T>, signal: AbortSignal): Promise<T> {
  return new Promise((resolve, reject) => {
    const abort = () => { cleanup(); reject(new DOMException('Cancelled or deadline exceeded', 'AbortError')); };
    const cleanup = () => signal.removeEventListener('abort', abort);
    // Observe even an already cancelled operation; fetch/body can reject independently.
    promise.then((value) => { cleanup(); resolve(value); }, (error) => { cleanup(); reject(error); });
    if (signal.aborted) { abort(); return; }
    signal.addEventListener('abort', abort, { once: true });
  });
}
