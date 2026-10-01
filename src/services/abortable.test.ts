import { describe, expect, it } from 'vitest';
import { abortable } from './abortable';

describe('cancelled transport operations', () => {
  it('observes a rejected operation even when cancelled before attachment', async () => {
    const controller = new AbortController();
    controller.abort();
    await expect(abortable(Promise.reject(new Error('operation cancelled')), controller.signal)).rejects.toMatchObject({ name: 'AbortError' });
    // Vitest reports unobserved operation rejections as a failing suite.
    await new Promise(resolve => setTimeout(resolve, 0));
  });
  it('does not allow a late operation completion to replace cancellation', async () => {
    let finish!: (value: string) => void;
    const controller = new AbortController();
    const pending = abortable(new Promise<string>(resolve => { finish = resolve; }), controller.signal);
    controller.abort(); finish('late');
    await expect(pending).rejects.toMatchObject({ name: 'AbortError' });
  });
});
