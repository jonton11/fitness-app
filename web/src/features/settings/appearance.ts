export const appearancePreferences = ['system', 'light', 'dark'] as const

export type AppearancePreference = (typeof appearancePreferences)[number]

export const appearanceStorageKey = 'fitness.appearance'

const darkModeQuery = '(prefers-color-scheme: dark)'

export function readAppearancePreference(): AppearancePreference {
  try {
    const storedPreference = window.localStorage.getItem(appearanceStorageKey)

    return appearancePreferences.includes(
      storedPreference as AppearancePreference,
    )
      ? (storedPreference as AppearancePreference)
      : 'system'
  } catch {
    return 'system'
  }
}

export function persistAppearancePreference(preference: AppearancePreference) {
  try {
    window.localStorage.setItem(appearanceStorageKey, preference)
  } catch {
    // The active preference still applies when browser storage is unavailable.
  }
}

export function applyAppearancePreference(
  preference: AppearancePreference,
  prefersDark = systemPrefersDark(),
) {
  const resolvedPreference =
    preference === 'system' ? (prefersDark ? 'dark' : 'light') : preference

  document.documentElement.dataset.theme = resolvedPreference
  document.documentElement.style.colorScheme = resolvedPreference
}

export function observeSystemAppearance(
  listener: (prefersDark: boolean) => void,
) {
  if (typeof window.matchMedia !== 'function') {
    return () => undefined
  }

  const mediaQuery = window.matchMedia(darkModeQuery)
  const handleChange = (event: MediaQueryListEvent) => listener(event.matches)

  mediaQuery.addEventListener('change', handleChange)
  return () => mediaQuery.removeEventListener('change', handleChange)
}

function systemPrefersDark() {
  return (
    typeof window.matchMedia === 'function' &&
    window.matchMedia(darkModeQuery).matches
  )
}
