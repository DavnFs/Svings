# Taste

## Communication

- Prefers responses written in English, and explicitly asks for English even when the surrounding material (e.g., an Indonesian-language plan) is in another language. Confidence: 0.9

## Workflow

- Explicitly asks for plan mode when requesting planning ("make sure to use plan mode") — wants a written plan laid out and approved before implementation begins. Confidence: 0.85
- When offered a choice of scope, picks the broadest option (e.g. build fix + dead-code prune + theme foundation) rather than the minimal "smallest reviewable diff" one, preferring bundled comprehensive changes over incremental steps. Confidence: 0.55
- Reports problems by pasting raw terminal/console error output with no accompanying instructions, expecting the agent to diagnose the root cause and apply the fix end-to-end (including environment/toolchain changes such as editing the user PATH or deleting and re-provisioning SDK components) before reporting back. Confidence: 0.6
