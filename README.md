# mg-skills

Markdown General skill library. Contains only mg-specific skills. Generic browser tools and utilities are sourced from upstream [pi-skills](https://github.com/badlogic/pi-skills).

## Skills

### chat-with-chat

Multi-system web-based AI chat automation (Grok, Claude.ai, etc.) via Chrome DevTools Protocol.

- **Directory**: `chat-with-chat/`
- **Skill Name**: `chat-with-chat`
- **Status**: ✓ Verified (Grok tested end-to-end, Claude.ai pre-configured)
- **Main Entry**: `ai-chat.sh <system> "<prompt>"`
- **Config**: `browser-tools.conf` (system selectors, timeout rules)

See `chat-with-chat/SKILL.md` for full documentation, setup, and troubleshooting.

## Adding Skills

1. Create directory: `mkdir <skill-name>`
2. Write SKILL.md with frontmatter (name, description) + markdown body
3. Include verified scripts and supporting files
4. Test end-to-end
5. Commit and push (explicit user request only)

## Deprecated

- **browser-tools/** directory: mixed pi-inherited + mg-specific code. Use `chat-with-chat/` instead. Generic tools are available in [pi-skills](https://github.com/badlogic/pi-skills).
