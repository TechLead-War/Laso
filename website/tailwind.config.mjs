/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,ts}'],
  theme: {
    screens: {
      'xs': '375px',
      'sm': '640px',
      'md': '768px',
      'lg': '1024px',
      'xl': '1280px',
      '2xl': '1536px',
    },
    extend: {
      colors: {
        apple: {
          blue: '#0071e3',
          gray: '#f5f5f7',
          dark: '#1d1d1f',
          secondary: '#6e6e73',
        },
      },
      fontFamily: {
        sans: [
          '-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'SF Pro Text',
          'Inter', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif',
        ],
      },
    },
  },
  plugins: [],
}
