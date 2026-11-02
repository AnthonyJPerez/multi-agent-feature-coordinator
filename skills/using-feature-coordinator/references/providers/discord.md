# Discord (chat)

Only used through asking-the-team, after your human partner approved the
text and the channel.

**C1 - post.** A channel webhook (Channel settings > Integrations >
Webhooks); each engineer exports its URL in the variable named by
`chat.webhook_env` (for example `FC_DISCORD_WEBHOOK`). Never write the URL
into a file or print it. Messages are limited to 2000 characters.

```bash
printf '%s' '{"content": "PAY-42: approved message text here. PR: https://..."}' \
  > "<state>/discord-message.json"
curl -sS -X POST -H 'Content-Type: application/json' \
  --data @"<state>/discord-message.json" "$FC_DISCORD_WEBHOOK"
```

**C2 - read replies.** Webhooks cannot read, and reading needs a bot. Your
human partner relays the answers.
