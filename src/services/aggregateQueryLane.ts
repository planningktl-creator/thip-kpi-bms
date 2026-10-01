import { recordAppPerformance } from './appPerformance';
import { BmsRequestError } from './bmsErrors';
/** Shared lane for validation KPI/profile requests; no overlap and a post-query gap. */
export class AggregateQueryLane {
  private tail: Promise<unknown> = Promise.resolve();
  private nextAt = 0;
  private held: BmsRequestError | null = null;
  private retryAt = 0;
  private consecutiveFailures = 0;
  hold(error: BmsRequestError): void { this.held = error; this.retryAt = Date.now() + (error.retryAfterMs ?? 0); }
  allow(): void {
    const status = this.held?.messageCode ?? this.held?.status;
    if (status === 401 || status === 403 || (status === 429 && Date.now() < this.retryAt)) return;
    this.held = null;
    this.consecutiveFailures = 0;
  }
  run<T>(signal: AbortSignal, work: () => Promise<T>): Promise<T> {
    const queuedAt = performance.now();
    const result = this.tail.catch(() => undefined).then(async () => {
      if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
      if (this.held) throw this.held;
      const delay = Math.max(0, this.nextAt - Date.now());
      if (delay) await new Promise<void>((resolve, reject) => {
        const cancel = () => { clearTimeout(timer); signal.removeEventListener('abort', cancel); reject(new DOMException('Cancelled', 'AbortError')); };
        const timer = setTimeout(() => { signal.removeEventListener('abort', cancel); resolve(); }, delay);
        signal.addEventListener('abort', cancel, { once: true });
      });
      if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
      if (this.held) throw this.held;
      recordAppPerformance({ phase: 'queue-wait', key: 'aggregate', durationMs: performance.now() - queuedAt, success: true });
      try { const value = await work(); this.consecutiveFailures = 0; return value; }
      catch (error) {
        if (error instanceof BmsRequestError) {
          const status = error.messageCode ?? error.status;
          const global = error.failure === 'network' || (error.failure === 'http' && (error.status ?? 0) >= 500);
          this.consecutiveFailures = global ? this.consecutiveFailures + 1 : 0;
          if (status === 401 || status === 403 || status === 429 || this.consecutiveFailures >= 3) this.hold(error);
        } else this.consecutiveFailures = 0;
        throw error;
      } finally { this.nextAt = Date.now() + 1000; }
    });
    this.tail = result.catch(() => undefined);
    return result;
  }
}
const lanes = new WeakMap<object, AggregateQueryLane>();
export function aggregateQueryLane(runtime: object): AggregateQueryLane {
  let lane = lanes.get(runtime);
  if (!lane) { lane = new AggregateQueryLane(); lanes.set(runtime, lane); }
  return lane;
}
