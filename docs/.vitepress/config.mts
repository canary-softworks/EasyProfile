import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  head: [['link', { rel: 'icon', href: '/favicon.ico' }]],
  base: "/EasyProfile/",
  title: "EasyProfile",
  titleTemplate: "Canary Docs",
  description: "EasyProfile is a simple way to store player data with minimal backend required",
  lastUpdated: true,
  lang: 'en-us',
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Guides', link: '/guides/'},
      { text: 'API', link: '/api/'},
      { text: 'Changelog', link: '/changelog'},
    ],

    sidebar: {
      '/api': [
        {
          text: 'API Reference',
          items: [
            { text: 'EasyProfile', link: '/api/' },
            { text: 'EasyProfileStore', link: '/api/profilestore' },
            { text: 'Profile', link: '/api/profile' },
          ]
        },
      ],
      '/guides': [
        {
          text: 'Guides',
          items: [
            { text: 'Profile Stores', link: '/guides/' },
            { text: 'Profiles', link: '/guides/profiles' },
            { text: 'Leaderstats Setup', link: '/guides/leaderstats' },
            { text: 'Global Keys', link: '/guides/globalkeys' },
          ]
        },
      ]
    },

    outline: [2, 3],

    search: {
      provider: 'local'
    },

    editLink: {
      pattern: 'https://github.com/canary-development/EasyProfile/edit/main/docs/:path'
    },

    footer: {
      message: 'Built with VitePress',
      copyright: 'Copyright © 2021 - 2024 Canary Softworks'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/canary-development/EasyProfile' },
      { icon: 'discord', link: 'https://discord.gg/cwwcZtqJAt'},
    ]
  }
})