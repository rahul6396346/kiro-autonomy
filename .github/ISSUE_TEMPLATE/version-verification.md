---
name: New Kiro version verification
about: Report findings after running the verification commands on a new Kiro version
title: '[VERIFY] kiro.kiro-agent v'
labels: verification
assignees: ''
---

## Versions
- Kiro IDE:
- `kiro.kiro-agent`:

## Matcher function
Output of `Select-String -Pattern 'function P7\(' -Context 0,8` (or `grep -n -A 8 'function P7('`):

```js
// paste output here
```

## Normalizer function
Output of `Select-String -Pattern 'function g10\(' -Context 0,2`:

```js
// paste output here
```

## Denylist
Output of `Select-String -Pattern 'getCommandDenylist' -Context 0,1`:

```
paste output here
```

## Conclusion
- [ ] Matches v0.3.433 logic — wildcard `["*"]` still works
- [ ] Logic changed — needs guide update

If logic changed, describe the new behavior:
