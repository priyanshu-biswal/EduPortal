/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        navy: {
          950: '#030712',
          900: '#060D1E',
          850: '#0B1528',
          800: '#0F1D38',
          750: '#142547',
          700: '#1C315E',
          600: '#2A4682',
        },
        accent: {
          cyan: '#38BDF8',
          electric: '#00F0FF',
          cobalt: '#1D4ED8',
          indigo: '#4338CA',
          blue: '#2563EB',
        },
        status: {
          emerald: '#10B981',
          crimson: '#EF4444',
          amber: '#F59E0B',
          purple: '#8B5CF6'
        }
      },
      boxShadow: {
        'glow-cyan': '0 0 25px -5px rgba(56, 189, 248, 0.3)',
        'glow-cobalt': '0 0 25px -5px rgba(37, 99, 235, 0.4)',
        'glow-emerald': '0 0 25px -5px rgba(16, 185, 129, 0.3)',
        'glow-crimson': '0 0 25px -5px rgba(239, 68, 68, 0.3)',
        'glass': '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'float': 'float 4s ease-in-out infinite',
        'glow': 'glow 2s ease-in-out infinite alternate',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-6px)' },
        },
        glow: {
          '0%': { opacity: '0.6' },
          '100%': { opacity: '1' },
        }
      }
    },
  },
  plugins: [],
}
