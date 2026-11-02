# Slack (chat)

Only used through asking-the-team, after your human partner approved the
text and the channel.

If your human partner has a Slack MCP server connected, use it for both
posting and reading - it acts as them and can read thread replies.

**C1 - post without MCP.** An incoming webhook for the channel; each
engineer exports its URL in the variable named by `chat.webhook_env` (for
example `FC_SLACK_WEBHOOK`). Never write the URL into a file or print it.

```bash
printf '%s' '{"text": "PAY-42: approved message text here. <https://pr-link|Open PR>"}' \
  > "<state>/slack-message.json"
curl -sS -X POST -H 'Content-Type: application/json' \
  --data @"<state>/slack-message.json" "$FC_SLACK_WEBHOOK"
```

(Use the variable your config names. Build the JSON with a JSON encoder if
the text has quotes or newlines.)

**C2 - read replies.** A webhook cannot read. With the MCP server, read the
thread under the message you posted. Without it, a bot token with
`channels:history` can call `conversations.replies` - only if your human
partner set one up and exported it; otherwise they relay the answers.
