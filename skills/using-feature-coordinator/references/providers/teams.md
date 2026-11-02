# Microsoft Teams (chat)

Only used through asking-the-team, after your human partner approved the
text and the channel.

**C1 - post.** A team owner creates a Workflows webhook for the channel
("Send webhook alerts to a channel" / "When a Teams webhook request is
received"); each engineer exports its URL in the environment variable named
by `chat.webhook_env` (for example `FC_TEAMS_WEBHOOK`). Never write the URL
into a file or print it.

```bash
cat > "<state>/teams-message.json" <<'EOF'
{
  "type": "message",
  "attachments": [{
    "contentType": "application/vnd.microsoft.card.adaptive",
    "content": {
      "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
      "type": "AdaptiveCard",
      "version": "1.4",
      "body": [
        { "type": "TextBlock", "weight": "Bolder", "text": "PAY-42: question on retry policy", "wrap": true },
        { "type": "TextBlock", "text": "Approved message text here.", "wrap": true }
      ],
      "actions": [{ "type": "Action.OpenUrl", "title": "Open PR", "url": "https://..." }]
    }
  }]
}
EOF
curl -sS -X POST -H 'Content-Type: application/json' \
  --data @"<state>/teams-message.json" "$FC_TEAMS_WEBHOOK"
```

(Use the variable your config names in place of `FC_TEAMS_WEBHOOK`.) The
older Office 365 connector webhooks are retired; use Workflows.

**C2 - read replies.** A webhook cannot read. If your human partner has a
Microsoft 365 or Teams MCP server connected (Microsoft Graph channel
messages), use it to read the replies to that message. Otherwise your human
partner relays the answers.
