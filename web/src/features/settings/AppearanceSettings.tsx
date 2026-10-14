import { appearancePreferences, type AppearancePreference } from './appearance'

interface AppearanceSettingsProps {
  appearance: AppearancePreference
  onAppearanceChange: (appearance: AppearancePreference) => void
}

const appearanceLabels: Record<AppearancePreference, string> = {
  system: 'System',
  light: 'Light',
  dark: 'Dark',
}

export function AppearanceSettings({
  appearance,
  onAppearanceChange,
}: AppearanceSettingsProps) {
  return (
    <main className="app-shell">
      <div className="settings-layout">
        <header className="settings-header">
          <p className="eyebrow">Preferences</p>
          <h1>Settings</h1>
        </header>

        <section className="settings-section">
          <fieldset className="appearance-fieldset">
            <legend>Appearance</legend>
            <div className="appearance-options">
              {appearancePreferences.map((preference) => (
                <label className="appearance-option" key={preference}>
                  <input
                    checked={appearance === preference}
                    name="appearance"
                    type="radio"
                    value={preference}
                    onChange={() => onAppearanceChange(preference)}
                  />
                  <span>{appearanceLabels[preference]}</span>
                </label>
              ))}
            </div>
          </fieldset>
        </section>
      </div>
    </main>
  )
}
