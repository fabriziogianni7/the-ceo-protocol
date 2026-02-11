# Moltiverse Web

Next.js 16 theme base with charts and reusable components.

## Setup

```bash
npm install
```

## Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Theme

The app uses CSS variables for light and dark modes. Toggle the theme via the header button.

- **Primary**: `#5423e7` (light) / `#7047eb` (dark)
- **Accent**: `#ffc233`
- **Fonts**: Inter (sans), JetBrains Mono (mono)

## Components

- **UI**: `Card`, `Button`, `Badge`
- **Charts**: Line, Bar, Area, Pie (via Recharts)
- **Theme**: `ThemeToggle` for dark/light mode

Use `web/src/app/page.tsx` as the base when developing additional pages.
