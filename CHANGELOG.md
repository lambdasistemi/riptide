# Changelog

## 1.0.0 (2026-07-04)


### Features

* **backend:** add dry playback wiring ([2c7f02f](https://github.com/lambdasistemi/riptide/commit/2c7f02fd795b5703ec57619f133f2926a601d160))
* **backend:** add JSON session stores ([d3e2d8e](https://github.com/lambdasistemi/riptide/commit/d3e2d8ea50b2f89426942e237577dedd2272ec8b))
* **backend:** add pure session domain ([e8ca896](https://github.com/lambdasistemi/riptide/commit/e8ca89653d5d38a8fc187a4a693407c202d3f834))
* **backend:** add tidal stream backend config ([a532502](https://github.com/lambdasistemi/riptide/commit/a532502b11299de4808e0e1ec0b93c9a9cfb27a7))
* **backend:** validate tracks with definition scope ([227f47d](https://github.com/lambdasistemi/riptide/commit/227f47d8942cf65bdcaaf905c223008c8cfb8a21))
* define websocket protocol ([c7a0cc2](https://github.com/lambdasistemi/riptide/commit/c7a0cc20a2678af37e57371c89dadd560cb46abe))
* **frontend:** add backend host setting ([afaceb0](https://github.com/lambdasistemi/riptide/commit/afaceb06a402fbaa1cb0e707498075e6f441cba2))
* **frontend:** add drag reorder reducers ([1e2c3f5](https://github.com/lambdasistemi/riptide/commit/1e2c3f5d30d134f6f06bb6273676a2e0b9f9db85))
* **frontend:** add import export file actions ([530bb72](https://github.com/lambdasistemi/riptide/commit/530bb7282e1b59f7e2f060b11bac0e3b933f19cb))
* **frontend:** add pure core model helpers ([0c495be](https://github.com/lambdasistemi/riptide/commit/0c495be85a2556f373235a794a46068e88f65f6d))
* **frontend:** add pure core reducers ([4b3eac0](https://github.com/lambdasistemi/riptide/commit/4b3eac0ab4be4d1238f1973eec191ddfa612d35c))
* **frontend:** add riptide app shell ([ad71da6](https://github.com/lambdasistemi/riptide/commit/ad71da678d103346b94ea394c00c44ebf2c30e81))
* **frontend:** add score timeline ([7b95d02](https://github.com/lambdasistemi/riptide/commit/7b95d025821012bc1adcf2cb54ec35ccc6a6b38a))
* **frontend:** add websocket protocol client ([a917328](https://github.com/lambdasistemi/riptide/commit/a9173282508d6a70b6f247ab4f7abe7fdf3f73fb))
* **frontend:** build definitions page ([3cd7d0f](https://github.com/lambdasistemi/riptide/commit/3cd7d0fe491b7fc80003099a8bcfd0b4e8d10a61))
* **frontend:** build song page ([aadde73](https://github.com/lambdasistemi/riptide/commit/aadde73b0bdc2ea637b122064ab764043d027e0b))
* **frontend:** port designer skin ([9c02a23](https://github.com/lambdasistemi/riptide/commit/9c02a233d8eb7cf5ca9ff6c4578d6d91b7b280ef))
* **frontend:** replace command labels with icon buttons ([3fb6f01](https://github.com/lambdasistemi/riptide/commit/3fb6f018d4c77bc14b068cca04d012972d5b6a10))
* **frontend:** send playback commands over websocket ([83a33ec](https://github.com/lambdasistemi/riptide/commit/83a33ec744f630efd2d4283472337a90f154957e))
* **frontend:** wire backend validation state ([94ed479](https://github.com/lambdasistemi/riptide/commit/94ed479e3c03970b65925dfeb78ce130ba6ff3b9))
* **frontend:** wire drag handles in song view ([b88eb72](https://github.com/lambdasistemi/riptide/commit/b88eb72486c2886963cd3ef90494d0c92ef8fb95))
* handle server commands ([272fa60](https://github.com/lambdasistemi/riptide/commit/272fa600c347bc8d3400df814df9851fcf764f64))
* interpret track text as ControlPattern via hint ([0057939](https://github.com/lambdasistemi/riptide/commit/0057939b75196e83af1ebdba6bffc09a99246b4a))
* package frontend with nix ([624ae0b](https://github.com/lambdasistemi/riptide/commit/624ae0bf3bf5a9fc671514e1798ad0c38c47147e))
* scaffold haskell backend (flake, cabal, dev shell) ([baadcbb](https://github.com/lambdasistemi/riptide/commit/baadcbbd097e11f2900093a2a89a5e84af04c6df))
* scaffold purescript frontend ([9e81800](https://github.com/lambdasistemi/riptide/commit/9e81800f75fac43f837d5bcba6269719cfc0f19d))
* serve websocket backend ([8a98145](https://github.com/lambdasistemi/riptide/commit/8a98145df9d6c786073e6c3d8e6762e2d4ff6c36))
* **server:** add cors support ([1b92279](https://github.com/lambdasistemi/riptide/commit/1b922799f49d4c1ff3d2116c4f7547b92edb4900))


### Bug Fixes

* **backend:** reconcile client session state ([b0e300a](https://github.com/lambdasistemi/riptide/commit/b0e300aa9699e26f28f7673dc478eabcec3b367c))
* **backend:** satisfy formatting and hlint ([29c6b70](https://github.com/lambdasistemi/riptide/commit/29c6b70a4fbaf8643ffc5bd907a7d3c85e6d87ca))
* **frontend:** add delete cancel affordance ([3e4d360](https://github.com/lambdasistemi/riptide/commit/3e4d360d6a2fa7a5f64899f10de0fddf7ba73da6))
* **frontend:** clean up cell controls ([6144d4e](https://github.com/lambdasistemi/riptide/commit/6144d4ed9a4e36576dcb466344018f49deec499b))
* **frontend:** compact song controls ([e4aa87e](https://github.com/lambdasistemi/riptide/commit/e4aa87e039e06ed0b0b03c57ceb8cf848c11ec01))
* **frontend:** guard icon render smoke ([225aa3b](https://github.com/lambdasistemi/riptide/commit/225aa3bd8f53667e18503ccc2959d838fb6b75fa))
* **frontend:** push state on websocket connect ([de63bd7](https://github.com/lambdasistemi/riptide/commit/de63bd7eb4bf8db788f7c299590d6c2abf69b96a))
* **frontend:** restore icon button interactions ([6298492](https://github.com/lambdasistemi/riptide/commit/62984920857c39aad4cd3aaac4c0534fdd6cd437))
