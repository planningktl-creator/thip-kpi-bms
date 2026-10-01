import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AggregateQueryLane, aggregateQueryLane } from './aggregateQueryLane';
import { BmsRequestError } from './bmsErrors';
beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(0); });
afterEach(() => vi.useRealTimers());
const signal = () => new AbortController().signal;
describe('shared aggregate lane', () => {
  it('serializes KPI/profile work and waits 1000ms after the active response', async () => {
    const lane = new AggregateQueryLane(); let finish!: () => void;
    const first = lane.run(signal(), () => new Promise<void>((resolve) => { finish = resolve; }));
    const work = vi.fn(async () => 2); const second = lane.run(signal(), work);
    await vi.advanceTimersByTimeAsync(5000); expect(work).not.toHaveBeenCalled();
    finish(); await first; await vi.advanceTimersByTimeAsync(999); expect(work).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1); expect(await second).toBe(2);
  });
  it('does not dispatch a cancelled waiting task or a cancelled gap', async () => {
    const lane = new AggregateQueryLane(); await lane.run(signal(), async () => 1);
    const abort = new AbortController(), work = vi.fn(async () => 2);
    const next = lane.run(abort.signal, work); const check = expect(next).rejects.toMatchObject({ name: 'AbortError' });
    await vi.advanceTimersByTimeAsync(100); abort.abort(); await check; expect(work).not.toHaveBeenCalled();
  });
  it.each([401, 403, 429])('holds both consumers on %i before another queued dispatch', async (status) => {
    const lane = new AggregateQueryLane(); const error = new BmsRequestError('api', 'http', 'secret', status, { retryAfterMs: 3000 });
    const first = lane.run(signal(), async () => { throw error; }); const check = expect(first).rejects.toBe(error);
    const work = vi.fn(async () => 2); const second = lane.run(signal(), work); const check2 = expect(second).rejects.toBe(error);
    await check; await check2; expect(work).not.toHaveBeenCalled(); lane.allow();
    await expect(lane.run(signal(), work)).rejects.toBe(error);
    await vi.advanceTimersByTimeAsync(3000); lane.allow();
    if (status === 429) expect(await lane.run(signal(), work)).toBe(2); else await expect(lane.run(signal(), work)).rejects.toBe(error);
  });
  it('holds after three global failures and user resume allows work again', async () => {
    const lane = new AggregateQueryLane(); const error = new BmsRequestError('api', 'network', 'secret');
    for (let i = 0; i < 3; i++) { const request = lane.run(signal(), async () => { throw error; }); const check = expect(request).rejects.toBe(error); await vi.advanceTimersByTimeAsync(1000); await check; }
    const work = vi.fn(async () => 2); await expect(lane.run(signal(), work)).rejects.toBe(error); expect(work).not.toHaveBeenCalled();
    lane.allow(); expect(await lane.run(signal(), work)).toBe(2);
  });
  it('isolates runtime contexts', () => { const runtime = {}; expect(aggregateQueryLane(runtime)).toBe(aggregateQueryLane(runtime)); expect(aggregateQueryLane({})).not.toBe(aggregateQueryLane(runtime)); });
});
