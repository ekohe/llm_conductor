# Retries & Rate Limits Guide

Transient provider failures — a rate limit, an overloaded region, a dropped
connection — are retried automatically, with exponential backoff seeded from your
configuration.

## 🚀 Quick Reference

```ruby
LlmConductor.configure do |config|
  config.max_retries = 3   # total attempts, including the first one
  config.retry_delay = 1.0 # seconds; seeds the exponential backoff
  config.logger = Logger.new($stdout) # optional: one warn line per retry
end
```

| Setting | Default | Meaning |
|---------|---------|---------|
| `max_retries` | `3` | **Total attempts**, not extra ones. `3` = one call plus at most two retries. `1` (or `0`) disables retrying. |
| `retry_delay` | `1.0` | Seconds before the first retry. Each further retry doubles it. |

### What gets retried

| Failure | Retried | Why |
|---------|---------|-----|
| `429 Too Many Requests` | ✅ | Rate limit / saturated quota pool — the next attempt may land |
| `500`, `502`, `503`, `504` | ✅ | Server-side overload or a bad gateway hop |
| `408 Request Timeout` | ✅ | Same as a timeout, expressed as a status |
| Connection & read timeouts | ✅ | `Faraday::ConnectionFailed`, `Faraday::TimeoutError`, `Net::ReadTimeout`, `Net::OpenTimeout`, `Errno::ECONNRESET` |
| `400`, `401`, `403`, `404`, `422` | ❌ | A malformed request or a bad credential is identical on attempt two |
| TLS/SSL errors | ❌ | A certificate problem does not resolve itself |
| Anything else | ❌ | Surfaces on the first attempt, unchanged |

---

## Overview

`Configuration` has declared `max_retries` and `retry_delay` for a long time, but
until 1.8.4 nothing read them: `OpenrouterClient` and `ZaiClient` each carried
their own hardcoded loop, and `GeminiClient` had no retry at all — a single Vertex
429 became an immediate, user-visible error.

The policy now lives in one place, `LlmConductor::Clients::Concerns::Retryable`,
mixed into `BaseClient`. Every provider request — `generate` and
`generate_simple` alike — goes through it, so the two configuration knobs mean the
same thing everywhere.

## Backoff

```
delay = min(retry_delay * 2 ** (attempt - 1), 30.0)
delay += delay * 0.25 * rand   # jitter
```

With the defaults (`retry_delay = 1.0`, `max_retries = 3`):

| Attempt | Fails with | Waits |
|---------|------------|-------|
| 1 | 429 | ~1.0–1.25s |
| 2 | 429 | ~2.0–2.5s |
| 3 | 429 | — raises / returns an error `Response` |

The jitter is **additive**, so a retry never fires sooner than you configured; its
purpose is to stop a fleet of concurrent workers from retrying in lockstep against
the same shared quota pool. The computed backoff is capped at 30 seconds so a
generous `retry_delay` cannot park a worker for minutes.

## Retry-After

When a provider sends a `Retry-After` header, it replaces the computed backoff.
Both formats are understood — a delay in seconds (`Retry-After: 7`) and an
HTTP-date (`Retry-After: Wed, 26 Aug 2026 10:20:00 GMT`). The value is capped at
60 seconds: past that, failing fast and letting the caller decide beats blocking a
worker. An unparseable value is ignored and the computed backoff is used instead.

## Logging

With a logger configured, each retry emits exactly one `warn` line:

```
[LlmConductor::Clients::GeminiClient] transient HTTP 429 on attempt 1/3; retrying in 1.07s
```

The line deliberately carries only the class/status, the attempt and the delay.
The exception's message and response body carry the request URL, and for Gemini's
generative-language endpoint that URL embeds the API key as a query parameter — so
neither is ever logged.

## What retries do *not* fix

Retries ride out **short spikes**: a burst of 429s while a shared quota pool
drains, a region hiccup, a dropped connection. They do not survive a **sustained**
quota outage — if the pool stays saturated for minutes, every attempt inside the
budget fails and the error surfaces exactly as it did before, just later. For that
you need capacity changes on the provider side (a dedicated quota, a different
region or model), a queue that can defer the work, or a fallback vendor.

## Errors after the budget is exhausted

Nothing changes about how failures reach you. `generate` and `generate_simple`
still return a `Response`, and the last error is reported on it:

```ruby
response = LlmConductor.generate(model: 'gemini-2.5-flash', prompt: 'Hi', vendor: :gemini)

unless response.success?
  puts response.metadata[:error]       # e.g. "the server responded with status 429"
  puts response.metadata[:error_class] # e.g. "Faraday::TooManyRequestsError"
end
```

## Per-provider notes

- **Gemini** — gemini-ai re-raises Faraday 5xx as `Gemini::Errors::RequestError`,
  keeping the original in `#request`; 429s arrive as a bare
  `Faraday::TooManyRequestsError`. Both shapes are recognised.
- **OpenRouter** — previously retried 502 only, five times, on a hardcoded
  `2**n` backoff. It now uses your configuration, and covers rate limits and
  timeouts as well as 502.
- **Z.ai** — its Faraday stack has no `raise_error` middleware, so HTTP errors
  come back as a normal response with an error body rather than a raised
  exception. The retry policy never sees them. This predates 1.8.4 (the hardcoded
  `rescue Faraday::ServerError` there was dead code for the same reason) and is
  left for a separate change, since adding the middleware would change what Z.ai
  callers observe on failure.

## Example

See [`examples/retry_config_usage.rb`](../examples/retry_config_usage.rb) for a
runnable walkthrough of the knobs and the resulting backoff.
