module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      colors: {
        // Brand primary colors
        brand: {
          red: {
            50: '#f9f3f1',
            100: '#f3e6e2',
            200: '#e8ccc5',
            300: '#dbb3a9',
            400: '#c4857a',
            500: '#ad574b',
            600: '#8c1915',
            700: '#7a1612',
            800: '#68120f',
            900: '#560f0c',
          },
          yellow: {
            50: '#fffbf0',
            100: '#fff8e1',
            200: '#ffefc2',
            300: '#ffe6a3',
            400: '#ffd965',
            500: '#fbba00',
            600: '#e6a800',
            700: '#cc9600',
            800: '#b38400',
            900: '#997000',
          },
          blue: {
            50: '#f0f4f9',
            100: '#e1e9f3',
            200: '#c3d3e7',
            300: '#a5bcdb',
            400: '#698bc2',
            500: '#2d5aa9',
            600: '#0f3a77',
            700: '#0d326a',
            800: '#0a2a5d',
            900: '#082250',
          },
        },
        // Neutral palette
        neutral: {
          50: '#f9fafb',
          100: '#f3f4f6',
          200: '#e5e7eb',
          300: '#d1d5db',
          400: '#9ca3af',
          500: '#6b7280',
          600: '#4b5563',
          700: '#374151',
          800: '#1f2937',
          900: '#111827',
        },
      },
      typography: {
        DEFAULT: {
          css: {
            color: '#1f2937',
            a: {
              color: '#0f3a77',
              '&:hover': {
                color: '#2d5aa9',
              },
            },
            h1: {
              color: '#0f3a77',
              fontWeight: '800',
            },
            h2: {
              color: '#0f3a77',
              fontWeight: '700',
            },
            h3: {
              color: '#2d5aa9',
              fontWeight: '700',
            },
          },
        },
      },
      fontFamily: {
        display: ['Inter', 'sans-serif'],
        body: ['Inter', 'sans-serif'],
      },
      spacing: {
        '7.5': '1.875rem',
        '15': '3.75rem',
      },
      boxShadow: {
        'brand': '0 10px 40px rgba(15, 58, 119, 0.15)',
        'brand-lg': '0 20px 60px rgba(15, 58, 119, 0.2)',
      },
    },
  },
  plugins: [],
}
