import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  appearanceStorageKey,
  applyAppearancePreference,
  observeSystemAppearance,
  readAppearancePreference,
} from './appearance'

describe('appearance preferences', () => {
  afterEach(() => {
    window.localStorage.clear()
    document.documentElement.removeAttribute('data-theme')
    document.documentElement.style.removeProperty('color-scheme')
    vi.unstubAllGlobals()
  })

  it('defaults invalid stored values to the system preference', () => {
    window.localStorage.setItem(appearanceStorageKey, 'sepia')

    expect(readAppearancePreference()).toBe('system')
  })

  it('applies explicit and resolved system appearances', () => {
    applyAppearancePreference('dark', false)

    expect(document.documentElement.dataset.theme).toBe('dark')
    expect(document.documentElement.style.colorScheme).toBe('dark')

    applyAppearancePreference('system', false)

    expect(document.documentElement.dataset.theme).toBe('light')
    expect(document.documentElement.style.colorScheme).toBe('light')
  })

  it('observes system appearance changes', () => {
    let changeListener: ((event: MediaQueryListEvent) => void) | undefined
    const removeEventListener = vi.fn()

    vi.stubGlobal(
      'matchMedia',
      vi.fn(() => ({
        matches: false,
        addEventListener: vi.fn(
          (_event: string, listener: (event: MediaQueryListEvent) => void) => {
            changeListener = listener
          },
        ),
        removeEventListener,
      })),
    )
    const listener = vi.fn()
    const stopObserving = observeSystemAppearance(listener)

    changeListener?.({ matches: true } as MediaQueryListEvent)
    stopObserving()

    expect(listener).toHaveBeenCalledWith(true)
    expect(removeEventListener).toHaveBeenCalledWith(
      'change',
      expect.any(Function),
    )
  })
})
