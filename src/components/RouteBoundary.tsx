import { Component, createElement, lazy, type ComponentType, type ReactNode } from 'react';

/** Retry failed same-origin assets with a new module URL; browsers cache failed imports. */
export function lazyRoute<M, K extends keyof M>(load: () => Promise<M>, name: K) {
  type P = M[K] extends ComponentType<infer Props> ? Props & object : never;
  let failedUrl: URL | null = null;
  function page(retry = false) {
    return lazy(async () => {
      try {
        let module: M;
        if (retry && failedUrl) {
          const url = new URL(failedUrl);
          url.searchParams.set('thip-chunk-retry', String(Date.now()));
          module = await import(/* @vite-ignore */ url.href);
        } else module = await load();
        if (!module[name]) throw new Error('Route export unavailable');
        return { default: module[name] as ComponentType<P> };
      } catch (error) {
        const match = error instanceof Error ? error.message.match(/https?:\/\/[^\s]+/) : null;
        if (match) {
          try {
            const url = new URL(match[0]);
            if (url.origin === window.location.origin && /\/assets\/[^/]+\.js$/.test(url.pathname)) failedUrl = url;
          } catch { /* Only known same-origin asset URLs may be retried. */ }
        }
        throw error;
      }
    });
  }
  let current = page();
  return class RouteBoundary extends Component<P, { failed: boolean; attempt: number }> {
    state = { failed: false, attempt: 0 };
    static getDerivedStateFromError() { return { failed: true }; }
    render(): ReactNode {
      if (this.state.failed) return <div className="monitoring-error" role="alert">โหลดหน้าจอไม่สำเร็จ ข้อมูลใน session ยังอยู่<button className="secondary-button" onClick={() => {
        current = page(true);
        this.setState({ failed: false, attempt: this.state.attempt + 1 });
      }}>ลองโหลดหน้าจออีกครั้ง</button>{this.state.attempt > 0 && <><p>หากไฟล์รุ่นเดิมหมดอายุ ให้โหลดหน้าใหม่และเชื่อมต่อ session อีกครั้ง ผลที่บันทึกใน cache ยังอยู่; งานที่ยังไม่สำเร็จจะเริ่มใหม่</p><button className="secondary-button" onClick={() => window.location.reload()}>โหลดหน้าใหม่</button></>}</div>;
      return createElement<P>(current, { ...this.props, key: this.state.attempt } as P & { key: number });
    }
  };
}
