import { describe, expect, it } from 'vitest';
import type { Indicator } from '@/types/thip';
import { formatDelta } from '@/utils/format';

const baseIndicator = {
  direction: 'neutral',
} as Indicator;

describe('formatDelta', () => {
  it('does not interpret a neutral KPI change as better or worse', () => {
    expect(formatDelta(7, 5, baseIndicator)).toBe('เปลี่ยนแปลง 2.0');
  });
});
