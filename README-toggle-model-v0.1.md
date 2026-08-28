# Agent Zero — Model Toggle v0.1

One-command switch between two xAI Grok models on a remotely-hosted Agent Zero,
without opening the web UI. Built to run over SSH from a phone.

## Why a file edit and not `.env`

Agent Zero has no public REST API for changing model settings, and it cannot
change its own settings. Two external options exist:

1. **`.env` with `A0_SET_` variables** — these override the defaults returned by
   `get_default_settings()`. Once the web UI has written a `settings.json`, the
   saved values are expected to take precedence, so an `A0_SET_` toggle would
   likely appear to work while changing nothing. **Unverified** — treated as a
   risk and avoided.
2. **Editing `settings.json` directly** — deterministic, and the result is
   readable back immediately. This is what the script does.

## What it changes

Both models are served by xAI on the same endpoint, so the provider, API base
and API key are never touched. The toggle rewrites two fields:

| | `code` | `reasoning` |
|---|---|---|
| `chat_model_name` | `grok-code-fast-1` | `grok-4-1-fast-reasoning` |
| `chat_model_ctx_length` | 256000 | 2000000 |

It also strips `presence_penalty`, `frequency_penalty`, `stop` and
`reasoning_effort` from `chat_model_kwargs` on every run. The Grok 4 family
rejects these outright, so leaving them in a saved config causes a 400 on the
first request.

## Usage

    ./toggle-model-v0.1.sh code        # cheap, coding-tuned
    ./toggle-model-v0.1.sh reasoning   # heavier logic
    ./toggle-model-v0.1.sh status      # show what's live, change nothing

Run `status` first — it prints the container, settings path and current model
without modifying anything.

## How it finds things

Nothing is hardcoded to one machine:

- **Container** — first running container whose name or image matches
  `agent-zero`.
- **Settings file** — `/a0/usr/settings.json`, falling back to
  `/a0/tmp/settings.json`.
- **JSON edit** — performed by `python3` *inside* the container, which Agent
  Zero always has. No `jq` or `python3` needed on the Mac. If the path is a
  host bind-mount the write passes straight through to the host filesystem, so
  this works whether or not the volume is mounted.

Override any guess:

    A0_CONTAINER=<name> ./toggle-model-v0.1.sh status
    A0_SETTINGS=<path>  ./toggle-model-v0.1.sh code
    A0_NO_RESTART=1     ./toggle-model-v0.1.sh code   # edit, don't restart

## Safety

- A timestamped `settings.json.bak-<ts>` is written before every change.
- The new config is written to a temp file and atomically renamed, so an
  interrupted write cannot leave a half-written `settings.json`.
- Unreadable JSON aborts before anything is written or restarted.
- If `settings.json` is ever corrupted beyond repair, deleting it and
  restarting regenerates defaults.

## Status

The JSON logic is tested (toggle both directions, param stripping, API-key
preservation, idempotency, corrupt input). The Docker discovery path —
container match and settings location — has **not** been run against the live
Mac Studio yet; `status` is the one-command way to confirm it.
