# User Profile

## Identity

- **Location:** Ryde, Sydney, NSW, Australia
- **Website:** [andrewriley.info](https://andrewriley.info) — portfolio and digital CV built around proof-of-work themes (lead, build, play, health); Next.js 16 + MDX on Cloudflare ([repo](https://github.com/andrewkriley/www-andrewriley-info)); migrated from Hugo
- **Role:** Tech Lead / Architect

## Technical Focus Areas

- **Home Lab & Self-hosting** — Proxmox cluster, Terraform, Ansible, Docker, LXC, K3s, GitLab CI/CD
- **AI / LLMs** — AI tooling, Claude Code skills, MCP integrations, homeaiops project (Home Assistant + Claude)
- **Observability / Splunk** — Splunk in the homelab for network and system monitoring; MCP-connected to Claude Code and Claude Desktop; uses natural language querying and Dashboard Studio for visualisation
- **Cloud & Infrastructure** — GitOps practices, VLAN segmentation, UniFi networking, Meraki MX appliances, Traefik, CI/CD pipelines
- **Security & access hygiene** — Audits his own AI tooling surface (MCP servers, tokens, filesystem, permissions) with a dedicated `/security-audit` skill; runs Gitleaks + ShellCheck in CI on his personal repos
- **Home Automation** — Deep Home Assistant user; builds custom integrations and HACS-distributed components
- **Community contributor** — Submits to open source projects (HACS, HA Brands repo)

## Personal Interests

- **DIY** — hands-on building and tinkering
- **Football** — passionate fan
- **Family** — family-first mindset; values balance between work and home life; builds things that serve the family (e.g. bin day alerts, automations)

## Writing & Communication Style

### Voice & Tone
- **Enthusiastic and engaging** — energetic, story-driven, opinionated; not corporate or stiff
- **First-person and conversational** — writes like he's talking to a peer, not presenting to an audience
- **Practical over theoretical** — always grounded in what was actually built, why, and what broke

### Signature traits observed across blog posts
- **Creative storytelling**: Will use unexpected narrative formats to explain technical topics — e.g. a fantasy epic ("The Ballad of Packet the Brave") to describe network infrastructure. Not afraid to be playful or experimental with format.
- **Honest about imperfection**: Openly calls out technical debt, ugly hacks, and "things I still need to fix" rather than pretending everything is polished.
- **Production-grade mindset at home**: Treats personal infrastructure with the same rigour as professional systems — GitOps, approval gates, SAST, documented architecture, SemVer-versioned releases even for personal tooling repos.
- **Self-improving toolchain**: Blogs about iterating on his own tools and workflows (e.g. improving the Claude skill itself). Meta, reflective, iterative.
- **Problem → Solution structure**: Posts typically open with a real problem (often family-driven), walk through the build, include actual code/config, and close with the outcome.
- **Short practical posts are fine**: Not every post is a deep dive — a quick terminal tip is worth publishing if it's useful.
- **Design-before-build discipline**: Uses structured design interviews (via `/grill-me`) before touching config or code — resolves dependencies and surfaces hidden assumptions upfront rather than debugging them later.
- **Blueprint-first projects**: Every new repo starts with a visual architecture blueprint (`blueprint.svg`) describing intent, components, and data flow — drawn before any code is written and embedded in the README.

### Blog posts
- Open with context: what was the problem, why did it matter
- Sections with `##` headings; step-by-step walkthrough
- Include real commands, config snippets, and error output
- Acknowledge what's still broken or not ideal
- Conversational sign-off, not a formal conclusion
- Published as MDX in `src/content/posts/` of the www-andrewriley-info repo, served at `/p/<slug>`

### LinkedIn
- Authentic, personal anecdotes tied to professional insight
- Ties personal projects back to professional learnings
- Avoids buzzwords and corporate language
- Short paragraphs, energetic cadence
- Strong editorial instinct about story angle — knows quickly if the framing is wrong and redirects decisively; iterates on tone until the story is right, not just technically accurate

## Skills That Use This Profile

- `linkedin-post` — use name, role, tone, focus areas, and signature traits when drafting posts
- **Blog posts** — future posts on andrewriley.info will be drafted using this profile's voice and structure; the old Hugo `new-post` skill is retired and no replacement skill exists yet for the Next.js/MDX site
- `keep-current` — reads PROFILE.md to infer communication style updates from session behaviour and project direction
