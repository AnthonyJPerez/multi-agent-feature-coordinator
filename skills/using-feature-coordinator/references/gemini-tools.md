# Gemini CLI Tool Notes

Gemini CLI loads this extension's `GEMINI.md` (the bootstrap skill and this
file) and discovers the bundled skills. No hooks run here, so:

- Start one `gemini` session per feature worktree, from inside it.
- Before every push, run `fw contract-check <ID>` and the repo's gate
  command yourself.
- Edit only files inside your worktree; the session's sandbox, if your human
  partner enables one, is the only enforcement.

| Action the skills name | Gemini CLI |
|---|---|
| Invoke a skill | `activate_skill` |
| Read / write / edit a file | `read_file`, `write_file`, `replace` |
| Run a shell command | `run_shell_command` |
| Ask your human partner | `ask_user` |
| Dispatch a subagent (`Subagent (general-purpose):`) | `invoke_agent` with `agent_name: "generalist"` and the filled prompt |
| Track tasks | `write_todos` |
| Work read-only until approved | `enter_plan_mode` / `exit_plan_mode` |
| Message another session | The mailbox (`fw mail`) |

`fw launch` does not generate Gemini commands; run
`cd <worktree> && FC_SESSION_WORKTREE=<worktree> gemini` and give it the
prompt `fw launch` prints for Claude Code.
