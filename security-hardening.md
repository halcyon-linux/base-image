# Codex conversation

## User

Determine how much security hardening can I do for my system overall in the base-image. Also determine how I can security harden and optimize my network. Only ingest the files that are needed. And use exa and context7 when needed.

## Assistant

I’ll inspect the image’s security and network configuration, then identify useful hardening options and their tradeoffs. I’ll keep file reads targeted and use Exa or Context7 where current documentation is needed.

## Activity

    $ rtk read /var/home/ahsan/.codex/plugins/cache/openai-curated-remote/superpowers/7.0.1/skills/using-superpowers/SKILL.md
    ---
    name: using-superpowers
    description: Use when starting any conversation - establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions
    ---

    <SUBAGENT-STOP>
    If you were dispatched as a subagent to execute a specific task, ignore this skill.
    </SUBAGENT-STOP>

    <EXTREMELY-IMPORTANT>
    If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

    IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

    This is not negotiable. You cannot rationalize your way out of this.
    </EXTREMELY-IMPORTANT>

    ## The Rule

    **Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

    **Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first.

    Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, create a todo per item.

    ## Skill Priority

    When multiple skills apply, process skills come first — they set the approach, then implementation skills (frontend-design, etc.) carry it out. Brainstorming and systematic-debugging are Superpowers' most common process skills, but the rule holds for any of them.

    - "Let's build X" → superpowers:brainstorming first, then implementation skills.
    - "Fix this bug" → superpowers:systematic-debugging first, then domain skills.

    ## Red Flags

    These thoughts mean STOP—you're rationalizing:

    | Thought | Reality |
    |---------|---------|
    | "This is just a simple question" | Questions are tasks. Check for skills. |
    | "I need more context first" | Skill check comes BEFORE clarifying questions. |
    | "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
    | "I can check git/files quickly" | Files lack conversation context. Check for skills. |
    | "Let me gather information first" | Skills tell you HOW to gather information. |
    | "This doesn't need a formal skill" | If a skill exists, use it. |
    | "I remember this skill" | Skills evolve. Read current version. |
    | "This doesn't count as a task" | Action = task. Check for skills. |
    | "The skill is overkill" | Simple things become complex. Use it. |
    | "I'll just do this one thing first" | Check BEFORE doing anything. |
    | "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
    | "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

    ## Platform Adaptation

    If your harness appears here, read its reference file for special instructions:

    - Claude Code: `references/claude-code-tools.md`
    - Codex: `references/codex-tools.md`
    - Pi: `references/pi-tools.md`
    - Antigravity: `references/antigravity-tools.md`
    - Hermes Agent: `references/hermes-tools.md`
    - Muse: `references/muse-tools.md`

    ## User Instructions

    User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, etc, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
    ✓ • 0ms

## Activity

    $ rtk read /var/home/ahsan/.codex/RTK.md; pwd; rtk rg --files -g AGENTS.md -g CLAUDE.local.md -g '.codex/rules/**' -g '.Codex/rules/**'
    <!-- rtk-owned: written by `rtk init --codex`, removed by `rtk init --codex --uninstall` -->

    # Command output

    Command output here is condensed to save tokens, keeping every signal and
    dropping costly noise. Treat it as the complete result: run commands
    normally, and batch related commands into one call to avoid extra turns.
    Truncated results state their recovery path in their own output. Re-run a
    command as `rtk bypass <cmd>` only when its result is unusable: empty when
    output was clearly expected, contradicting its exit code, or garbled.
    /var/home/ahsan/Git/halcyon/base-image
    AGENTS.md
    ✓ • 0ms

## Assistant

I’m using the Superpowers workflow guidance for this assessment. I’ll first map the relevant files, then read the settings and checks that establish what the image actually enforces.

## Activity

    • Started `/root/security_map`

## Activity

    $ rtk read AGENTS.md; rg --files system_files build_files tests | rtk rg '(security|hardening|sysctl|network|firewall|resolved|audit|ssh|pam|modprobe|limits|system-services|verify$)'
    # AGENTS.md

    Agent instructions for [`halcyon-linux/base-image`](https://github.com/halcyon-linux/base-image). User-facing documentation belongs in `README.md`. Follow the current executable code when documentation is stale; report discrepancies rather than silently changing behavior.

    ## Project and build

    - `Containerfile` builds the `alcyone` Fedora Atomic/bootc image from Universal Blue `base-main`, with OGC kernel akmods, NVIDIA open drivers, and a Hyprland desktop. The current Fedora release is **45**, defined in the `Containerfile`, `.github/workflows/build.yml`, and `Justfile`.
    - The default and publication branch is `containerfile`. Its workflow builds, pushes `ghcr.io/halcyon-linux/alcyone`, and signs the resulting image. **Never push to this branch or trigger publication without explicit approval.** Do not create or switch branches unless requested.
    - The build inputs are under `build_files/`; files layered into the image are under `system_files/`. `just_scripts/` contains local tooling; `packages.json` currently supplies package sets and external-repository metadata. These are real, active files: do not treat proposed TODO changes as already implemented.
    - Read the relevant `Containerfile` stages and scripts before editing. Preserve stage ordering and verify dependencies across installers, configuration, services, and final checks.

    ## Commands and validation

    ```bash
    just                          # list recipes
    just build                    # local image build
    just run                      # run the built image
    just just-check               # check Justfile and *.just formatting
    bash tests/test-dnf5-retry.sh
    bash tests/test-audit-lint.sh
    ```

    Run focused checks appropriate to each change, including `bash -n` for modified shell scripts. The audit-lint script checks shell syntax, executable permissions, JSON/YAML, audit rules, and supply-chain constraints. A complete image build additionally requires Podman, Just, Git, registry/network access, and helper tools used by `just_scripts/`. Never claim a test, build, boot, or registry check passed unless it ran successfully.

    ## Safety and release invariants

    1. **Secrets and signing:** Never disclose, commit, or log `GITHUB_TOKEN`, `SIGNING_SECRET`, private signing keys, or key material. Preserve `.gitignore`, `.containerignore`, and `.dockerignore` protection. `cosign.pub` is a public verification key; coordinate any rotation with the signing secret and README instructions.
    2. **CI publication:** Preserve the `github.ref == 'refs/heads/containerfile'` conditions on both publish and sign steps, pinned action SHAs, restrictive permissions, secret scoping, and signing compatibility flags. Review workflow changes with the owner before editing.
    3. **Pinned inputs:** `just_scripts/verify-upstream-images` verifies the upstream OCI images and produces digest references for the normal local/CI build. Do not bypass failed verification. Keep the kernel and NVIDIA akmods inputs aligned; `just_scripts/resolve-akmods` selects a compatible tag including `nct6687d`.
    4. **Downloads and GPG:** New build-time external downloads require a fixed reference and SHA-256 entry in `build_files/downloads/manifest.tsv`; fetch via the `downloads` stage and mount `/downloads` into consuming stages. `GITHUB_TOKEN` may only be mounted in that package-free stage. Verify vendor GPG fingerprints and do not disable GPG checks.
    5. **Immutable image conventions:** Install persistent content under `/usr` (and appropriate image-managed locations); use `/etc` for configuration defaults, not mutable runtime state. Do not introduce static content under `/var` that finalization removes. Do not run destructive host operations (`podman system reset`, host `bootc`/`rpm-ostree` deployment commands) as part of code changes.
    6. **Repository policy:** Build-only COPRs and vendor repos must be disabled in the finished image. Retain package versionlocks and source requirements where specified by the installers and `verify`.
    7. **Initramfs:** Build the initramfs **once**, after NVIDIA driver setup and final relevant configuration, using `build_files/kernel/build-initramfs`. Do not add intermediate dracut invocations.
    8. **Fedora upgrades:** Update the Fedora release in the `Containerfile`, workflow, and `Justfile` together. Check matching base/akmods images, COPRs, the vendored Terra GPG key and fingerprint, and verification expectations.

    ## Change map

    | Area                       | Inspect and update together                                                                                                                             |
    | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | RPMs and repositories      | `packages.json`, relevant `build_files/packages/` installer, source-repository handling, `build_files/finalization/verify`, consumers and versionlocks  |
    | Build stages               | `Containerfile`, required mounts, `verify <stage>`, `build_files/shared/cleanup`; register any new verification stage in both `case` dispatch locations |
    | Kernel and NVIDIA          | `just_scripts/resolve-akmods`, `build_files/kernel/`, `build_files/nvidia/`, matching verification stages, final initramfs step                         |
    | systemd                    | Units in `system_files/`, `build_files/system/configure-system-services`, verification for enabled/disabled units and runtime dependencies              |
    | Desktop and ujust          | `system_files/desktop/`, `system_files/nvidia/`, `build_files/just/`, `configure-desktop-integration`, `verify justfiles`, `just just-check`            |
    | Security and auditing      | `system_files/overrides/etc/audit/`, `configure-security-hardening`, `generate-audit-privileged-rules`, `verify`, and `tests/test-audit-lint.sh`        |
    | Image metadata and release | `build_files/finalization/image-info`, `.github/workflows/build.yml`, signing files, and `README.md`                                                    |
    | Pinned artifacts           | `build_files/downloads/manifest.tsv`, `fetch-pinned`, installation stage, integrity and attribution checks                                              |

    `packages.json` currently defines gaming and application package sets. The build currently installs Steam, Lutris, Heroic Games Launcher and related packages; preserve existing behavior unless explicitly tasked with changing it. Keep Mesa handling consistent across architectures and repositories. The explicit package-removal and optimization-preservation requirements belong in the implementation task, not in claims about the current image.

    ## Verification contract

    - The `Containerfile` runs `/ctx/finalization/verify <stage>` after relevant build stages; it also performs `verify final` and `bootc container lint`. Keep stage checks close to the changes they validate.
    - Add both positive checks (required packages, binaries, unit states, repository provenance) and negative checks (forbidden packages, units, files, and insecure settings). Never delete an assertion just to make a failing build pass.
    - Audit rules reside under `system_files/overrides/etc/audit/rules.d/`. The final static rule file is `99-finalize.rules`; privileged-binary rules are generated after NVIDIA package installation. Audit rules are validated in the build but not activated as host kernel audit policy during the image build.
    - Preserve shell strict-mode conventions, executable bits on scripts, non-executable static files, and the existing formatting style. Keep `.containerignore` and `.dockerignore` in sync.

    ## Agent workflow

    1. Inspect the actual affected files and follow their call sites. Do not infer an implementation from comments or pending TODOs.
    2. Make minimal, scoped changes; avoid unrelated refactors and do not silently remove established packages, services, security protections, or fallback logic.
    3. Update `verify`, tests, and README when behavior or public-facing instructions change. Keep this file focused on durable agent rules rather than duplicating README details.
    4. Run applicable static checks and, where feasible, the full image build; report exact commands, outcomes, and anything not tested.
    5. Check the diff for secrets and accidental file or permission changes. Do not push, publish, deploy, or modify release/signing policy without explicit approval.
    tests/test-security-hardening.sh
    tests/test-audit-lint.sh
    build_files/system/configure-system-services
    build_files/system/generate-audit-privileged-rules
    build_files/system/configure-security-hardening
    build_files/packages/install-security
    system_files/overrides/etc/ssh/sshd_config.d/10-halcyon-hardening.conf
    system_files/overrides/etc/security/pwquality.conf
    system_files/overrides/etc/security/limits.d/60-disable-coredump.conf
    system_files/overrides/etc/security/faillock.conf
    build_files/finalization/verify
    system_files/overrides/etc/firewalld/zones/FedoraWorkstation.xml
    system_files/overrides/etc/audit/rules.d/99-finalize.rules
    system_files/overrides/etc/audit/rules.d/60-access-denied.rules
    system_files/overrides/etc/audit/rules.d/50-security-config.rules
    system_files/overrides/etc/audit/rules.d/44-installers.rules
    system_files/overrides/etc/audit/rules.d/41-persistence.rules
    system_files/overrides/etc/audit/rules.d/40-kernel.rules
    system_files/overrides/etc/audit/rules.d/32-power-abuse.rules
    system_files/overrides/etc/audit/rules.d/30-identity.rules
    system_files/overrides/etc/audit/rules.d/20-dont-audit.rules
    system_files/overrides/etc/audit/rules.d/12-cont-fail.rules
    system_files/overrides/etc/audit/rules.d/10-base-config.rules
    system_files/overrides/etc/audit/auditd.conf
    system_files/desktop/etc/modprobe.d/halcyon-hardening.conf
    system_files/desktop/usr/share/halcyon/selinux/secureblue_audit_sockets.cil
    system_files/nvidia/usr/lib/modprobe.d/nvidia-power.conf
    system_files/desktop/usr/bin/halcyon-security-posture
    system_files/desktop/usr/share/ublue-os/just/90-security.just
    system_files/desktop/usr/lib/modprobe.d/halcyon-framebuffer.conf
    system_files/desktop/usr/lib/modprobe.d/halcyon-blocklist.conf
    system_files/desktop/etc/fail2ban/jail.d/10-halcyon-sshd.conf
    system_files/desktop/etc/ssh/ssh_config.d/10-halcyon-github.conf
    system_files/desktop/usr/lib/systemd/system-preset/35-halcyon-security.preset
    system_files/desktop/usr/lib/tmpfiles.d/halcyon-hardening.conf
    system_files/desktop/usr/lib/systemd/system/halcyon-security-posture.service
    system_files/desktop/usr/lib/bootc/kargs.d/10-halcyon-hardening.toml
    system_files/desktop/etc/security/limits.d/memlock.conf
    system_files/desktop/usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-hardening.conf
    system_files/desktop/usr/lib/sysctl.d/80-inotify.conf
    system_files/desktop/usr/lib/sysctl.d/75-networking.conf
    system_files/desktop/usr/lib/sysctl.d/70-gaming.conf
    system_files/desktop/usr/lib/sysctl.d/60-kernel.conf
    system_files/desktop/usr/lib/sysctl.d/55-halcyon-hardening.conf
    ✓ • 0ms

## Activity

    $ rtk read /var/home/ahsan/.codex/plugins/cache/openai-curated-remote/app-69ea4ed2cf7c8191b742ef3622479ddd/4.0.1/skills/Search/SKILL.md
    ---
    name: Search
    description: "Deep research powered by Exa. Use for lead generation, literature reviews, deep dives, competitive analysis, or any query where one search falls short, including phrases like 'research this', 'find everything about', 'find me all', or 'deep dive on'."
    ---

    # Exa Search And Research

    Use Exa to search the web and fetch source pages when the user needs current web information, research support, source discovery, or source-grounded synthesis. Understand the query, plan the searches, validate results, and deliver a compact answer with useful links.

    This skill uses the bundled Exa app tools:
    - `web_search_exa` for web search
    - `web_fetch_exa` for reading known URLs

    ## Prerequisites: Exa App Connection

    The bundled Exa app must be connected before this skill can use Exa tools.

    If `web_search_exa` or `web_fetch_exa` is unavailable:
    1. Ask the user to connect or re-authenticate the Exa app from the plugin/app install flow.
    2. Tell them to start a new Codex thread if the tools still do not appear after connecting.
    3. Do not fall back to generic web search, ask the user to re-try connecting to the Exa App.

    On auth, connection, or rate-limit errors, surface the Exa app connection fix clearly.

    ## Date Calculation (Do This First)

    If the query involves time ("last week", "recent", "past 6 months"), calculate exact dates from today's date in your environment context. Write out the calculation explicitly before doing anything else. Never eyeball dates or reuse dates from examples.

    ## Step 1: Assess the Query

    Read the user's query and determine two things:

    **How complex is this?**
    - **Extremely Simple** (e.g. reading the contents of 1-2 pages): Handle it yourself. Read `references/searching.md` for query-writing guidance, run the searches, review and filter results, then respond directly.
    - **Moderate** (when a fast or low-effort search is requested): Run a small set of targeted searches and fetch only the most useful pages.
    - **Advanced** (clear topic, clear filters, a few parallel searches): Break the task into distinct search angles, search each angle, then compile.
    - **Complex** (cross-referencing across entity types, multi-hop chains, exhaustive coverage, semantic filtering): Use a multi-pass workflow where later searches depend on earlier findings.

    **Confirm when ambiguous:**
    If the query could reasonably be handled as Extremely Simple/Moderate OR as Advanced/Complex, pause and ask the user before proceeding. Present:
    1. Your interpretation of the query
    2. The two (or more) plausible complexity levels
    3. What each level would look like in practice (e.g., "I can do a quick 1-2 search lookup, or I can do a deeper multi-angle sweep")
    4. Let the user choose

    Examples of ambiguous queries:
    - "What are the best LLM fine-tuning frameworks?" — could be a quick opinionated list (Moderate) or an exhaustive evaluated comparison (Complex)
    - "Find competitors to Acme Corp" — could be a quick search for known competitors (Moderate) or a deep sweep across funding databases, press, and niche directories (Complex)
    - "What's the latest on WebGPU?" — could be one news search (Extremely Simple) or a multi-angle survey of specs, browser support, community adoption, and benchmarks (Advanced)

    Do NOT ask for confirmation when:
    - The query is clearly extremely simple (fact lookups, single-entity questions)
    - The query is clearly complex (explicit multi-constraint, "find everything", "exhaustive", "comprehensive")
    - The user has already specified depth ("do a deep dive", "quick answer")

    Note: if the user explicitly asks for something (e.g. "100" of something), continue to work until you've achieved it.

    **What work needs to happen?** Identify which of these apply (most queries use 3-5):

    1. **Seed from user input**: The user provided a list of entities to start from (company names, tickers, paper titles). Each seed becomes a parallel workstream.
    2. **Define what qualifies**: What makes a result a valid "row"? Translate the user's criteria into concrete checks.
    3. **Define what to capture**: What fields ("columns") does each result need? Build the schema before searching.
    4. **Search broadly**: Generate diverse queries and run them to find candidates.
    5. **Extract structured data**: Pull specific fields from raw search results into the schema.
    6. **Filter**: Apply hard constraints (dates, geography, thresholds) and soft judgments (quality, relevance, semantic checks).
    7. **Merge and deduplicate**: Combine results from multiple searches. Same URL = drop duplicate. Same entity from different sources = merge fields, keep best data.
    8. **Score and rank**: For "best of" (e.g. "what's the best ___?") queries, define the scoring criteria explicitly, then rank.
    9. **Synthesize narrative**: For research queries, organize findings by theme and write prose with citations.

    ## Step 2: Run Search Workstreams

    ### What workstreams do

    Search workstreams keep the investigation organized. Each workstream should:
    - Read the reference file(s) you point it to
    - Run the specific searches you assign
    - Return compact, structured output

    Use Codex subagents only when the user explicitly asks for parallel agent work or when the active Codex instructions allow delegation. Otherwise, run the workstreams yourself with direct Exa calls.

    For each workstream, define:
    1. Which reference file(s) to read for instructions (always include the absolute path)
    2. What specific searches to run or what specific work to do
    3. What output format to return

    **Template:**
    ```
    Read the file at [this skill's directory]/references/searching.md for instructions on how to query Exa effectively.

    Then do the following:
    [specific task description]
    [specific queries to run, if you are prescribing them]
    [validation criteria -- what makes a result qualify, so irrelevant results are filtered before returning]

    Return: [output format -- e.g. "compact JSON with name, url, snippet per result" or "markdown table with columns X, Y, Z"].

    Track `sources_reviewed: N` where N = sum of `numResults` across every `web_search_exa` call (including retries). For example, calls with numResults 10, 10, 5 -> `sources_reviewed: 25`.
    ```

    ### Which reference files to use

    Always use `references/searching.md`. It contains Exa query guidance and an index of domain-specific pattern files to select from based on the task.

    Use whichever of these also apply:

    | File | Use this when... |
    |---|---|
    | `references/extraction.md` | You need to extract specific data points into a schema you defined |
    | `references/filtering.md` | You need to evaluate results against criteria (especially semantic/soft filters) |
    | `references/synthesis.md` | You are producing a prose synthesis rather than structured data |
    | `references/source-quality.md` | You need to assess source credibility, especially for "best of", ranking, or expert-finding queries |

    ### How to split work

    Decompose the primary task/question into **sub-questions** to cover different search territories.

    For example, "best open-source LLM fine-tuning frameworks for production use" can be decomposed into multiple parallel sub-questions:
    1. "What open-source LLM fine-tuning frameworks do production engineers recommend, and what do they say about using them in real deployments?"
    2. "What open-source LLM fine-tuning tools have launched or gained traction in the last 6 months that aren't yet widely known?"
    3. "What are the most common complaints, failure modes, and reasons teams migrated away from specific open-source LLM fine-tuning frameworks in production?"

    Depending on your "**How complex is this?**" analysis: Some need 2-3; some need many. Some need several different angles, creative thought patterns, adversarial perspectives. It depends on what the user is asking for and how deep they want you to go.

    Keep each sub-question direct and specific.

    ### Workstream sizing

    - Aim for 3-5 searches per workstream.
    - Keep independent workstreams separate in your notes so their results are easy to merge.
    - For per-seed work (enriching a list of 20 companies), batch 3-5 seeds per workstream.

    ### Token isolation

    Avoid dumping raw search output into the final answer. Process results and return only distilled output with links.

    ### When things go wrong

    - **A workstream returns empty**: Rephrase queries with different angles, not synonyms. If still empty, the topic may have limited web coverage -- report that.
    - **A workstream returns off-topic results**: Queries were too vague. Retry with longer, more specific queries.

    ## Step 3: Compile Results

    After search workstreams return:

    **Deduplicate:**
    1. Collect all results into a single list
    2. Remove exact URL duplicates
    3. Same entity from different sources: merge fields, keep the most complete/recent data
    4. Track: "Deduplicated X results down to Y unique entries"

    **Validate coverage:**
    - Are there obvious gaps? (missing time periods, missing geographic regions, missing entity types)
    - For each gap found, run targeted follow-up searches.
    - For "find everything" queries, check if results from different workstreams overlap heavily (good sign) or are completely disjoint (may indicate missed angles)

    **Format the output:**

    For deeper research, open with: "I used Exa to review {X} sources across {Y} search workstreams. Here's what was found:" (X = sum of `sources_reviewed` across all workstreams and passes plus any direct searches you ran; Y = total workstreams. Pluralize naturally.)

    Then: Format output beautifully, filling up no more than one screen when possible. Include hyperlinked text where relevant. Below it, you may also include things (in a short, easy-to-read format) that:
    - ("Result") directly answer the original user request (in few words; make every word count)
    - ("Process") include anything worth noting about your process and what you consider to be high-signal in this domain vs. what you filtered out.
    - ("Patterns") any patterns identified that are non-obvious, require n-th order thinking, and are not included or alluded to in the rest of the output but might be interesting to the user.
    - ("Notes") based on everything you know about the user and their work beyond this task, mention anything notable/useful you found that is not included or alluded to in the rest of the output.

    If it's impossible to fit the full output in a single screen, write a file in the most relevant/useful file format (.csv, .md) to `./exa-results/<topic>-<YYYY-MM-DD>` and include a pointer to the full file below the 1-screen output.

    **General output rules:**
    - No emojis unless the user requested them
    - Include in-line 1-word or multi-word hyperlinks throughout outputs where hyperlinking is a value-add.
    - Prefer tables over lists (fall back to lists only when fields are non-uniform or values are too long to fit cleanly)

    ## Multi-Pass Queries

    Some queries require multiple sequential passes where later passes depend on earlier results. Common patterns:

    **Entity chaining** (multi-hop): Pass 1 finds entities (companies), Pass 2 finds related entities per result (people at those companies), Pass 3 enriches those (their public statements). Each pass is a round of focused workstreams.

    **Exploratory then targeted**: Pass 1 scouts the landscape broadly, Pass 2 searches deeply in the most promising directions found in Pass 1.

    **Criteria discovery**: When "best" isn't predefined, Pass 1 surveys what practitioners actually value, Pass 2 searches for candidates matching those criteria.

    Between passes, compile and deduplicate before dispatching the next round.

    ## Evaluating Source Quality

    Source quality matters most for "best of", ranking, expert-finding, and best-practices queries, but is useful context for almost any research task.

    **At the workstream level:** Use `references/source-quality.md` so source quality is tagged in the output. This lets you weight results during compilation.

    **At the orchestrator level**, when compiling search results:

    1. **Convergence across high-signal sources**: Convergence alone isn't meaningful (3 low-quality sources agreeing is just shared noise). What matters is when multiple independent, high-signal sources (practitioners, people with skin in the game) converge on the same finding.
    2. **Practitioner vs commentator**: Weight practitioners (people doing the work) higher than commentators (people writing about the work).
    3. **Via negativa**: Before synthesizing, define who to exclude (sources with misaligned incentives, no skin in the game, or unfalsifiable claims). Filtering out noise is more valuable than seeking brilliance.
    4. **Red-team your compiled results**: What perspectives are missing? What biases might be distorting the aggregate? If a gap emerges, run a targeted follow-up.
    5. **Ideas over entities**: For expert-finding and best-practices queries, the primary output is convergent truths, not a ranked list of names. Lead with what the best sources agree on, then cite who said it.

    ## Gotchas

    - **Over-execution on simple queries**: If the user asks "what year was X founded", don't spin up a broad research process. One search, one answer.
    - **Under-execution on hard queries**: If the query has 4+ constraints, temporal joins, or semantic filtering, a single search will not cut it. Fan out.
    - **Synonym queries**: Running "overrated AI tools" and "overhyped AI tools" as separate queries wastes tokens. These hit the same embedding region. Diversify by angle instead.
    - **Forgetting to deduplicate**: Multiple searches will return overlapping results. Always deduplicate before synthesis.
    - **Treating Exa results as validated**: Exa returns similarity, not yet validated. A result appearing in search output does not mean it meets the user's criteria. You must validate.
    - **Date drift**: Always calculate dates from the current environment date. Never reuse dates from these instructions or from previous queries.
    ✓ • 0ms

## Activity

    $ rtk read build_files/system/configure-security-hardening; rtk read system_files/desktop/usr/lib/sysctl.d/55-halcyon-hardening.conf system_files/desktop/usr/lib/sysctl.d/60-kernel.conf system_files/desktop/usr/lib/sysctl.d/75-networking.conf; rtk read build_files/system/configure-system-services
    #!/usr/bin/env bash

    set -Eeuo pipefail

    # FILE-7524: cron files 0600, spool directories 0700. A tmpfiles.d rule
    # re-enforces these at every boot; set them here so the shipped image and the
    # build-time verification see the final state.
    chmod 0600 /etc/crontab /etc/cron.deny
    chmod 0700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly

    # /etc/security/faillock.conf is only read by pam_faillock, and the base
    # authselect profile ('local') does not load it by default. Enable the
    # feature so the lockout policy actually applies to login, sudo and su.
    authselect check
    read -r auth_profile _ < <(authselect current --raw)
    if [[ "$auth_profile" != local ]]; then
        echo "ERROR: expected authselect local profile before disabling SSSD" >&2
        exit 1
    fi
    authselect enable-feature with-faillock
    authselect check
    for pam_stack in system-auth password-auth; do
        for faillock_phase in preauth authfail; do
            if ! grep -Eq "^[[:space:]]*auth[[:space:]].*pam_faillock\\.so[[:space:]].*${faillock_phase}([[:space:]]|$)" "/etc/pam.d/$pam_stack"; then
                echo "ERROR: pam_faillock $faillock_phase missing in $pam_stack" >&2
                exit 1
            fi
        done
    done

    # Use the restrictive workstation zone without rewriting explicit NetworkManager assignments.
    if [[ "$(firewall-offline-cmd --get-default-zone)" != FedoraWorkstation ]]; then
        firewall-offline-cmd --set-default-zone=FedoraWorkstation
    fi
    firewall-offline-cmd --check-config
    systemctl enable firewalld.service

    # secureblue-derived service posture (see 35-halcyon-security.preset): services
    # a single-user desktop does not need stay off; the halcyon-security-posture
    # unit re-enforces the same posture at boot on deployed systems.
    systemctl disable \
        sssd.service sssd-kcm.service sssd-kcm.socket \
        ModemManager.service \
        iscsid.service iscsid.socket iscsiuio.service iscsiuio.socket \
        alsa-state.service 2>/dev/null || true
    # passim is D-Bus-activatable; only a mask keeps it from respawning (fwupd
    # degrades gracefully without it).
    systemctl mask passim.service 2>/dev/null || true

    # AUTH-9216: /etc/group and /etc/gshadow must pass grpck silently. Package
    # scriptlets keep the pair consistent, but repair rather than trust that; the
    # runtime unit re-runs the same sync on deployed systems.
    /usr/bin/halcyon-shadow-sync
    grp_output=$(grpck -r 2>&1 || true)
    if [[ -n "$grp_output" ]]; then
        printf 'ERROR: grpck reports group file inconsistencies:\n%s\n' "$grp_output" >&2
        exit 1
    fi

    # Audit: Fedora's stock rules.d/audit.rules is `-D` + `-a task,never`, which
    # turns syscall auditing off, and it sorts after every numbered file in
    # augenrules's `sort -V` order, so it would cancel the Halcyon rules. Git
    # cannot carry 0600, so set the modes here (the generated 31-privileged.rules
    # is created later by generate-audit-privileged-rules).
    rm -f /etc/audit/rules.d/audit.rules
    chmod 0600 /etc/audit/rules.d/*.rules
    chmod 0640 /etc/audit/auditd.conf

    # policycoreutils-restorecond enables itself in %post. It is installed for
    # on-demand use; leave it off by default.
    systemctl disable restorecond.service
    # SPDX-License-Identifier: CC0-1.0
    # Halcyon sysctl hardening, curated from secureblue's 55-hardening.conf
    # (https://github.com/secureblue/secureblue, Apache-2.0).
    #
    # Deviations from secureblue, and why:
    # - vm.mmap_rnd_bits=32 / vm.mmap_rnd_compat_bits=16 are intentionally NOT set:
    #   raised mmap entropy is a known breakage source for 32-bit Windows games
    #   under Proton/Wine, and this is a gaming-capable image.
    # - kernel.io_uring_disabled=1 instead of secureblue's 2: unprivileged io_uring
    #   is disabled (the entire attack surface of concern) while root retains an
    #   escape hatch; value 2 permanently bricks io_uring for high-performance
    #   applications even for administrators.
    # - vm.max_map_count is owned by 70-gaming.conf, which sorts later and wins.
    # - rp_filter stays in loose mode (2), as in systemd's 50-default.conf, instead
    #   of strict (1): the kernel docs recommend loose mode for asymmetric or
    #   complicated routing, and this image ships Tailscale and container
    #   bridges, whose interfaces appear after boot and inherit "default".
    # - net.ipv4.tcp_timestamps stays on: the kernel randomizes the timestamp
    #   offset per connection, so there is no uptime leak left to close, and
    #   disabling it only weakens PAWS and RTT estimation.
    # - kernel.warn_limit is not set (see below): a stability risk with GPU drivers.
    # - fs.binfmt_misc.status stays on: it switches off every registered binfmt
    #   handler, including the qemu-user entries used for cross-architecture
    #   container builds.
    #
    # Sorted before 60-/70-/75- so deliberate image tuning keeps precedence.

    # https://docs.kernel.org/networking/ip-sysctl.html
    net.ipv4.tcp_syncookies = 1
    net.ipv4.tcp_rfc1337 = 1
    net.ipv4.icmp_echo_ignore_broadcasts = 1
    net.ipv4.icmp_ignore_bogus_error_responses = 1
    net.ipv4.icmp_echo_ignore_all = 1
    net.ipv6.icmp.echo_ignore_all = 1

    # Source address verification (spoofing protection), loose mode (RFC 3704)
    net.ipv4.conf.all.rp_filter = 2
    net.ipv4.conf.default.rp_filter = 2

    # Ignore ICMP redirects and source routes
    net.ipv4.conf.*.send_redirects = 0
    net.ipv4.conf.*.accept_redirects = 0
    net.ipv6.conf.*.accept_redirects = 0
    net.ipv4.conf.*.secure_redirects = 0
    net.ipv4.conf.*.shared_media = 0
    net.ipv4.conf.*.accept_source_route = 0
    net.ipv6.conf.*.accept_source_route = 0

    # ARP hardening
    net.ipv4.conf.*.arp_filter = 1
    net.ipv4.conf.*.arp_ignore = 2
    net.ipv4.conf.all.drop_gratuitous_arp = 1

    # RFC 4941 IPv6 privacy extensions
    net.ipv6.conf.all.use_tempaddr = 2
    net.ipv6.conf.default.use_tempaddr = 2

    # Log spoofed, source-routed, and redirect packets
    net.ipv4.conf.all.log_martians = 1
    net.ipv4.conf.default.log_martians = 1

    # Harden the BPF JIT for every process
    # https://docs.kernel.org/admin-guide/sysctl/net.html#bpf-jit-harden
    net.core.bpf_jit_harden = 2

    # Restricted ptrace: debuggers may attach to their own descendants only
    # https://docs.kernel.org/admin-guide/LSM/Yama.html
    kernel.yama.ptrace_scope = 1

    # No unprivileged BPF. 1 is sticky until reboot (2 would let root re-enable it
    # at runtime); KSPP recommends 1.
    kernel.unprivileged_bpf_disabled = 1
    # Disabled entirely; `ujust` can raise it for full SysRq
    kernel.sysrq = 0
    kernel.perf_event_paranoid = 3
    kernel.kptr_restrict = 2
    kernel.dmesg_restrict = 1
    # Reboot after 100 oopses instead of the default 10000. kernel.warn_limit is
    # deliberately NOT set: WARN() is routine in GPU and Wi-Fi drivers, and over a
    # long uptime 100 harmless warnings would reboot the machine unexpectedly.
    kernel.oops_limit = 100
    kernel.panic = -1

    fs.suid_dumpable = 0
    fs.protected_regular = 2
    fs.protected_fifos = 2
    fs.protected_hardlinks = 1
    fs.protected_symlinks = 1

    # Do not auto-load TTY line disciplines
    dev.tty.ldisc_autoload = 0

    # Restrict userfaultfd to CAP_SYS_PTRACE
    vm.unprivileged_userfaultfd = 0

    # Quieter console (info leaks); runtime console level only
    kernel.printk = 3 3 3 3

    # kexec can replace the running kernel
    kernel.kexec_load_disabled = 1

    # No core dumps (also enforced via limits.d and systemd-coredump absence)
    kernel.core_pattern = |/bin/false

    # io_uring: disabled for unprivileged users; administrators may revert at
    # runtime (secureblue ships 2, which is permanent)
    kernel.io_uring_disabled = 1

    # Defaults kept explicit
    kernel.randomize_va_space = 2
    vm.mmap_min_addr = 65536
    kernel.split_lock_mitigate=0
    net.core.default_qdisc=fq
    net.ipv4.tcp_congestion_control=bbr
    net.ipv4.tcp_mtu_probing=1
    net.ipv6.conf.all.use_tempaddr=2
    net.ipv6.conf.default.use_tempaddr=2
    #!/usr/bin/env bash

    set -Eeuo pipefail

    system_services=(
        brew-setup.service
        input-remapper.service
        uupd.timer
        hardware-setup.service
        dev-hugepages1G.mount
        greenboot-healthcheck.service
        greenboot-set-rollback-trigger.service
        cardwired.service
        sddm.service
        cups.service
        bpftune.service
        tuned.service
        fstrim.timer
        var-nix.service
        nix.mount
        nix-daemon.socket
        nix-daemon.service
        fail2ban.service
        halcyon-hosts-entry.service
        halcyon-shadow-sync.service
        halcyon-security-posture.service
        halcyon-aide-init.service
        halcyon-aide-check.timer
        rngd.service
        psacct.service
        sysstat.service
        halcyon-mor.service
    )

    global_services=(
        user-setup.service
        podman.socket
        systemd-tmpfiles-setup.service
        dynamic-fixes.service
        chezmoi-init.service
        chezmoi-update.timer
    )

    disabled_services=(
        scx_loader.service
        rpm-ostreed-automatic.timer
        greetd.service
    )

    for unit in "${system_services[@]}"; do
        systemctl enable "$unit"
    done

    for unit in "${global_services[@]}"; do
        systemctl --global enable "$unit"
    done

    for unit in "${disabled_services[@]}"; do
        systemctl disable "$unit" 2>/dev/null || true
    done

    systemctl set-default graphical.target
    ✓ • 0ms

## Activity

    $ rtk rg -n 'security|hardening|network|firewall|resolved|dns|selinux|secure.boot|luks|fstrim|update|tailscale|ssh|vpn|chrony' Containerfile packages.json README.md build_files/finalization/verify tests/test-security-hardening.sh; rg --files system_files | rtk rg '(NetworkManager|resolved|systemd/system/|bootc/kargs|firewall|chrony)'
    177 matches in 5 files:

    Containerfile:1:# Build the Hyprland/NVIDIA Fedora Atomic image as one bootable OCI image; bo...
    Containerfile:226:# Install security tooling: AIDE (file integrity), python3-systemd (fail2ban
    Containerfile:232:/ctx/packages/install-security && \
    Containerfile:233:/ctx/finalization/verify security && \
    Containerfile:258:# Apply the Lynis-audit hardening: cron permissions, pam_faillock activation,
    Containerfile:261:/ctx/system/configure-security-hardening && \
    Containerfile:262:/ctx/finalization/verify security-hardening
    Containerfile:356:RUN --mount=type=tmpfs,target=/run --network=none \
    README.md:26:7. [Security and supply-chain](#security-and-supply-chain)
    README.md:67:You are now pinned to that digest. `bootc upgrade`, `ujust update`, and `uupd...
    README.md:95:| `update` / `upgrade` | Update OS image and apps via `uupd` |
    README.md:100:| `update-nvidia-runtime` | Sync NVIDIA Flatpak runtime |
    README.md:125:`nix-daemon.socket` may show failed on the first boot after an update; later ...
    README.md:139:With the Fedora 45 base already cached in Podman, run `bash tests/test-securi...
    README.md:143:Firewalld is explicitly enabled. The default `FedoraWorkstation` zone allows ...
    README.md:148:systemctl is-active firewalld auditd audit-rules
    README.md:149:sudo firewall-cmd --check-config
    README.md:150:sudo firewall-cmd --get-default-zone
    README.md:151:sudo firewall-cmd --get-active-zones
    README.md:152:sudo firewall-cmd --list-all-zones
    README.md:159:Inspect each connection's explicit zone with `nmcli -g connection.zone connec...
    README.md:167:Prerequisites: Linux, `podman`, `just`, `git`, `skopeo`, `jq`, network to `gh...
    build_files/finalization/verify:10:brew | kernel | repos | cli-tools | utils | removals | common-packages | gami...
    build_files/finalization/verify:146:fail "package $pkg resolved from '${from:-<unknown>}', expected one of: ${rep...
    build_files/finalization/verify:160:/etc/security/limits.d/30-brew-limits.conf \
    build_files/finalization/verify:162:/usr/lib/systemd/system/brew-update.service \
    build_files/finalization/verify:163:/usr/lib/systemd/system/brew-update.timer \
    build_files/finalization/verify:244:fedora updates \
    build_files/finalization/verify:382:htop ublue-os-update-services google-noto-sans-cjk-fonts geoclue2 fish greetd...
    build_files/finalization/verify:390:tailscale ds-inhibit gameclass \
    build_files/finalization/verify:411:require_rpms_from_repo 'fedora,updates' bluez
    build_files/finalization/verify:425:forbid_rpms fish greetd greetd-selinux zsh-autosuggestions zsh-syntax-highlig...
    build_files/finalization/verify:568:# hyprpm update git-clones and checks out the exact commit the binary
    build_files/finalization/verify:885:for inc in 10-update.just 80-bazzite.just maintenance.just system-tools.just; do
    build_files/finalization/verify:903:if grep -q '^topgrade:' /usr/share/ublue-os/just/10-update.just 2>/dev/null && \
    build_files/finalization/verify:904:grep -qF -- '--config /etc/xdg/topgrade.toml' /usr/share/ublue-os/just/10-upd...
    build_files/finalization/verify:911:if grep -q '^nix-relabel-unit' /usr/share/ublue-os/just/90-security.just 2>/d...
    build_files/finalization/verify:914:fail "ujust nix-relabel-unit recipe missing from 90-security.just"
    build_files/finalization/verify:926:sddm.service cups.service bpftune.service tuned.service fstrim.timer \
    build_files/finalization/verify:935:for svc in chezmoi-init.service chezmoi-update.timer user-setup.service dynam...
    build_files/finalization/verify:1115:pass "rpm-ostree automatic updates set to none"
    build_files/finalization/verify:1117:fail "rpm-ostree automatic updates not set to none"
    build_files/finalization/verify:1148:verify_security
    build_files/finalization/verify:1151:verify_security() {
    build_files/finalization/verify:1152:require_rpms_from_json "security" "packages"
    build_files/finalization/verify:1181:# bootc never refreshes on updates, so it cannot work in this image.
    build_files/finalization/verify:1222:40-kernel 41-persistence 44-installers 50-security-config 60-access-denied 99...
      +106 more in build_files/finalization/verify
    packages.json:7:"updates",
    packages.json:108:"ublue-os-selinux-workarounds",
    packages.json:201:"fssh",
    packages.json:212:"uupd-update"
    packages.json:252:"NetworkManager-ssh",
    packages.json:253:"NetworkManager-ssh-selinux",
    packages.json:351:"proton-vpn-daemon",
    packages.json:352:"proton-vpn-gtk-app",
    packages.json:355:"python3-proton-vpn-api-core",
    packages.json:506:"security": {
    packages.json:511:"updates"
    packages.json:519:"firewalld",
    tests/test-security-hardening.sh:2:# Check authentication and permanent firewall configuration in an isolated Fe...
    tests/test-security-hardening.sh:7:podman run --rm -i --pull=never --network=none --security-opt label=disable \
    tests/test-security-hardening.sh:9:-v "$repo_root/build_files/system/configure-security-hardening:/review/script...
    tests/test-security-hardening.sh:10:-v "$repo_root/system_files/overrides/etc/firewalld/zones/FedoraWorkstation.x...
    tests/test-security-hardening.sh:13:rpm -q fedora-release authselect firewalld audit audit-rules
    tests/test-security-hardening.sh:14:# Run only the authentication/firewall block, not unrelated image installatio...
    tests/test-security-hardening.sh:20:test "$(firewall-offline-cmd --get-default-zone)" = FedoraWorkstation
    tests/test-security-hardening.sh:21:test "$(firewall-offline-cmd --zone=FedoraWorkstation --list-services)" = dhc...
    tests/test-security-hardening.sh:22:test "$(firewall-offline-cmd --zone=FedoraWorkstation --list-ports)" = 47/tcp
    tests/test-security-hardening.sh:23:test "$(firewall-offline-cmd --zone=FedoraWorkstation --get-target)" = default
    tests/test-security-hardening.sh:24:test "$(systemctl is-enabled firewalld.service)" = enabled
    tests/test-security-hardening.sh:55:echo 'PASS: Fedora 45 authentication, firewall defaults, idempotency, rejecti...
    system_files/nvidia/usr/lib/systemd/system/nvidia-flatpak-runtime-sync.service
    system_files/overrides/etc/chrony.conf
    system_files/desktop/etc/systemd/system/beesd@.service.d/bees-timeout.conf
    system_files/overrides/etc/firewalld/zones/FedoraWorkstation.xml
    system_files/desktop/usr/lib/bootc/kargs.d/10-halcyon-hardening.toml
    system_files/desktop/usr/lib/NetworkManager/conf.d/40-halcyon.conf
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-init.service
    system_files/desktop/usr/lib/systemd/system/var-nix.service
    system_files/desktop/usr/lib/systemd/system/nix.mount
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.timer
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.service
    system_files/desktop/usr/lib/systemd/system/mcelog.service.d/override.conf
    system_files/desktop/usr/lib/systemd/system/kmod-sleep-workaround@.service
    system_files/desktop/usr/lib/systemd/system/hardware-setup.service
    system_files/desktop/usr/lib/systemd/system/halcyon-shadow-sync.service
    system_files/desktop/usr/lib/systemd/system/halcyon-security-posture.service
    system_files/desktop/usr/lib/systemd/system/halcyon-mor.service
    system_files/desktop/usr/lib/systemd/system/halcyon-hosts-entry.service
    system_files/desktop/usr/lib/systemd/system/beesd@.timer
    system_files/desktop/usr/lib/systemd/system/dev-hugepages1G.mount
    system_files/desktop/usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-killmode.conf
    system_files/desktop/usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-hardening.conf
    system_files/desktop/usr/lib/systemd/system/fstrim.service.d/workaround-no-root-trim.conf
    ✓ • 0ms

## Activity

    • Completed `/root/security_map`

## Activity

    $ rtk read system_files/desktop/usr/lib/bootc/kargs.d/10-halcyon-hardening.toml system_files/desktop/usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-hardening.conf system_files/desktop/usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-killmode.conf system_files/desktop/usr/lib/NetworkManager/conf.d/40-halcyon.conf system_files/overrides/etc/firewalld/zones/FedoraWorkstation.xml; rtk read system_files/overrides/etc/ssh/sshd_config.d/10-halcyon-hardening.conf system_files/overrides/etc/security/faillock.conf system_files/overrides/etc/security/pwquality.conf; sed -n '133,160p' README.md; sed -n '1349,1645p' build_files/finalization/verify
    # SPDX-License-Identifier: CC0-1.0
    # Halcyon kernel arguments, curated from secureblue's
    # files/system/usr/lib/bootc/kargs.d/10-secureblue.toml (Apache-2.0).
    #
    # Applied by bootc on (re)deployment; ignored by non-bootc boot paths.
    #
    # secureblue arguments already effective without a karg (checked against the
    # ogc kernel config): init_on_alloc=1 (CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y),
    # randomize_kstack_offset=on (CONFIG_RANDOMIZE_KSTACK_OFFSET_DEFAULT=y) and
    # slab_nomerge (CONFIG_SLAB_MERGE_DEFAULT is not set).
    #
    # secureblue arguments intentionally NOT adopted:
    # - mitigations=auto,nosmt, l1tf/l1d/ssbd/spec_store_bypass/pti overrides,
    #   kvm-* mitigation forcing, kvm-amd.nested=0, kvm-intel.nested=0:
    #   measurable CPU performance cost; mitigations=auto already applies the
    #   appropriate set adaptively.
    # - lockdown=confidentiality, module.sig_enforce=1: would break loading of the
    #   locally-built ogc kernel modules and the NVIDIA akmods.
    # - init_on_free=1, slab_debug=FZ, slab_nomerge: allocator performance cost.
    # - iommu=force, iommu.strict=1, intel_iommu=on, amdgpu.iommu_perfopt=0:
    #   DMA translation overhead on the discrete GPU and NVMe.
    # - vsyscall=none, vdso32=0, ia32_emulation=0: break legacy 32-bit games under
    #   Proton/Wine.
    # - rd.shell=0, rd.emergency=halt, loglevel=0: they remove the initramfs
    #   recovery shell and all boot messages, so a failed boot (for example after a
    #   kernel or NVIDIA module change) could not be diagnosed or repaired. The
    #   GRUB menu is not password protected, so they would not stop a local
    #   attacker anyway.
    # - proc_mem.force_override=ptrace: belongs to secureblue's "Filling known
    #   security holes" set, which is out of scope for this image.
    # Audit arguments (see /etc/audit/rules.d): audit=1 turns auditing on from the
    # start of boot so processes that begin before auditd loads its rules are
    # audited too, and audit_backlog_limit matches the `-b 8192` queue size in
    # 10-base-config.rules.
    kargs = [
      "audit=1",
      "audit_backlog_limit=8192",
      "hash_pointers=always",
      "page_alloc.shuffle=1",
      "random.trust_bootloader=off",
      "random.trust_cpu=off",
      "systemd.ssh_auto=no",
    ]
    # Halcyon: minimal NetworkManager sandboxing.
    #
    # Fedora's unit already bounds capabilities and sets ProtectSystem=true and
    # ProtectHome=read-only. Only directives that NetworkManager and the helpers it
    # spawns (dnsmasq, dhclient, pppd, modprobe) provably do not need are added.
    # Deliberately NOT set, because they break NetworkManager:
    # - ProtectKernelTunables / ProtectSystem=strict: it writes /proc/sys/net and
    #   /sys, and /run and /var/lib/NetworkManager.
    # - ProtectKernelModules / MemoryDenyWriteExecute: it runs modprobe for bonding,
    #   bridge, tun and wireguard, and loads plugins.
    # - NoNewPrivileges: blocks the SELinux domain transitions into dnsmasq_t,
    #   dhcpc_t and ppp_t.
    # - DeviceAllow / DevicePolicy / PrivateDevices: would close /dev/rfkill and
    #   /dev/net/tun.
    # - ProtectHostname: NetworkManager sets the transient hostname itself.
    # - ProtectProc, PrivateTmp, UMask: not needed to reach the goal and each
    #   carries breakage risk without a boot test.
    # - SystemCallFilter classes @module, @mount, @privileged and @resources: the
    #   modprobe helper, namespaced helpers and capability handling use them.
    # SELinux (NetworkManager_t, enforcing) remains the main confinement.
    [Service]
    LockPersonality=true
    RestrictRealtime=true
    RestrictSUIDSGID=true
    RestrictNamespaces=true
    ProtectControlGroups=true
    SystemCallArchitectures=native
    ProtectKernelLogs=true
    # NetworkManager never sets the clock; time sync stays with chrony.
    ProtectClock=true
    # Deny only the syscall classes NetworkManager and its helpers never use.
    SystemCallFilter=~@clock @cpu-emulation @debug @obsolete @raw-io @reboot @swap
    # Netlink, packet (DHCP/LLDP), IP, D-Bus/local sockets and Bluetooth (DUN). No
    # AF_PPPOX: PPPoE is terminated by the router, and SELinux already denies it.
    RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK AF_PACKET AF_BLUETOOTH
    # Halcyon: NetworkManager kill mode hardening, from secureblue
    # files/system/usr/lib/systemd/system/NetworkManager.service.d/40-killmode.conf.
    [Service]
    KillMode=control-group
    # Halcyon: NM IPv6 privacy extensions, from secureblue
    # files/system/usr/lib/NetworkManager/conf.d/40-secureblue.conf.
    [connection]
    # RFC 4941 IPv6 privacy extensions: enabled (prefer temporary addresses)
    ipv6.ip6-privacy=2
    <?xml version="1.0" encoding="utf-8"?>
    <!-- Halcyon override of the FedoraWorkstation firewalld zone, adapted from
         secureblue files/system/etc/firewalld/zones/FedoraWorkstation.xml:
         Fedora's default opens TCP/UDP 1025-65535 for local applications; this
         closes them. Unlike secureblue, ssh (port 47) and dhcpv6-client stay allowed:
         `ujust ssh` enables sshd, and without dhcpv6-client DHCPv6 replies from
         the router are dropped. Only effective while this zone is the active one
         (configure-security-hardening makes this the default; explicit
         NetworkManager connection zones remain administrator-controlled). -->
    <zone>
      <short>Fedora Workstation</short>
      <description>Unsolicited incoming network packets are rejected, except for select network services. Incoming packets that are related to outgoing network connections are accepted. Outgoing network connections are allowed.</description>
      <service name="dhcpv6-client"/>
      <port protocol="tcp" port="47"/>
      <forward/>
    </zone>
    # --- Network ---
    Port 47

    # --- Authentication ---
    # CIS: no direct root logins; stronger than Fedora's prohibit-password default
    PermitRootLogin no
    # keys-only authentication
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitEmptyPasswords no
    # Lynis SSH-7408: only wheel (the sudo group) may log in. Add a user to wheel
    # before enabling sshd, or they are locked out.
    AllowGroups wheel
    MaxAuthTries 3
    LoginGraceTime 30
    MaxSessions 2
    # CIS: throttle unauthenticated connections (OpenSSH default is 10:30:100)
    MaxStartups 10:30:60
    # Show the legal banner (/usr/lib/issue.net) before authentication
    Banner /etc/issue.net

    # --- Forwarding ---
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no

    # --- Keepalive / logging ---
    TCPKeepAlive no
    ClientAliveInterval 300
    ClientAliveCountMax 2
    LogLevel VERBOSE
    # Halcyon: account lockout policy (loaded by pam_faillock, which
    # configure-security-hardening enables through the authselect with-faillock
    # feature). Lock after 10 consecutive failures within 15 minutes, unlock after
    # 15 minutes (CIS suggests 5; 10 keeps a mistyped password or a failing
    # fingerprint reader from locking the only account out). The unlock window is short on
    # purpose: a permanent or day-long lock only hands a local attacker a
    # denial-of-service on a single-user desktop (see faillock.conf(5)).
    audit
    deny = 10
    fail_interval = 900
    unlock_time = 900
    even_deny_root
    root_unlock_time = 900
    # Halcyon: password quality policy, aligned with NIST SP 800-63B-4: a password
    # that is the only authenticator needs at least 15 characters, and verifiers
    # must not impose composition rules (required digit/upper/lower/symbol), which
    # reject strong passphrases such as "correct horse battery staple" while
    # accepting "Password1!". Strength comes from length, a dictionary check, and
    # rejection of passwords derived from the account name. Applies to password
    # changes only; existing passwords are not affected.
    minlen = 15
    dcredit = 0
    ucredit = 0
    lcredit = 0
    ocredit = 0
    dictcheck = 1
    usercheck = 1
    usersubstr = 5
    enforcing = 1
    enforce_for_root
    ### Auditing (auditd)

    `auditd` runs with Halcyon rules in `/etc/audit/rules.d/`. Verify with `sudo auditctl -l` (must not be a lone `-a never,task`) and `sudo auditctl -s` (expect `enabled 1`). `ujust audit-status` / `ujust audit-report` summarize state. Add local rules to your own file under `/etc/audit/rules.d/`, not a shipped one. `ujust audit-lock` makes rules immutable until reboot.

    Failed-access rules cover both x86 ABIs. Audit failures log rather than panic or halt the desktop. The backlog wait and timed root lockout remain unchanged; test workload latency and recovery before deploying policy changes.

    With the Fedora 45 base already cached in Podman, run `bash tests/test-security-hardening.sh` for isolated authentication, firewall-default, idempotency and audit-syscall checks. It uses no network and does not load kernel audit rules or start a firewall on the host.

    ### Firewall and authentication checks

    Firewalld is explicitly enabled. The default `FedoraWorkstation` zone allows DHCPv6 client traffic and SSH on TCP 47, not the stock high-port ranges. Existing explicit NetworkManager zone assignments are preserved; an image update does not override locally modified `/etc` configuration. Intra-zone forwarding remains enabled for compatibility.

    After boot, verify the effective configuration, not only the image defaults:

    ```bash
    systemctl is-active firewalld auditd audit-rules
    sudo firewall-cmd --check-config
    sudo firewall-cmd --get-default-zone
    sudo firewall-cmd --get-active-zones
    sudo firewall-cmd --list-all-zones
    nmcli connection show --active
    sudo authselect check
    sudo auditctl -s
    sudo auditctl -l
    ```

    Inspect each connection's explicit zone with `nmcli -g connection.zone connection show "<profile-name>"`; an empty value uses the default. Check both IPv4 and IPv6 from a second machine. Test SSH, VPN and Podman networking, login, sudo, screen unlock, suspend/resume, and failed-login recovery in a disposable VM before rollout. Audit `lost` must not increase under representative load. Never load test audit rules on the build host.

    verify_security_hardening() {
        verify_audit_config

        # Banners (Lynis BANN-7126/7130): each file needs >=5 legal keyword matches.
        local banner_file keyword count
        for banner_file in /etc/issue /etc/issue.net; do
            count=0
            for keyword in warning authori prohibited subject monitor log report prosecute law; do
                if grep -qi -- "$keyword" "$banner_file" 2>/dev/null; then
                    count=$((count + 1))
                fi
            done
            if ((count >= 5)); then
                pass "legal banner present in $banner_file ($count legal keywords)"
            else
                fail "legal banner missing or weak in $banner_file ($count/5 legal keywords)"
            fi
        done

        # Fail2ban (Lynis TOOL-5104): the sshd jail must exist in the effective config.
        if [[ -f /etc/fail2ban/jail.d/10-halcyon-sshd.conf ]] && \
           grep -q '^\[sshd\]' /etc/fail2ban/jail.d/10-halcyon-sshd.conf && \
           grep -qiE '^enabled[[:space:]]*=[[:space:]]*true' /etc/fail2ban/jail.d/10-halcyon-sshd.conf; then
            pass "fail2ban sshd jail enabled in jail.d"
        else
            fail "fail2ban sshd jail missing or disabled"
        fi
        if fail2ban-client -d 2>/dev/null | tr -d "[]'" | awk -F, '$1=="add" { print $2 }' | tr -d ' ' | grep -qx 'sshd'; then
            pass "fail2ban effective configuration contains the sshd jail"
        else
            fail "fail2ban effective configuration has no sshd jail"
        fi

        # Uncommon network protocols (Lynis NETW-3200) disabled via modprobe.
        local proto
        for proto in dccp sctp rds tipc; do
            if grep -qE "^install[[:space:]]+${proto}[[:space:]]+/bin/true$" /etc/modprobe.d/halcyon-hardening.conf 2>/dev/null; then
                pass "uncommon network protocol disabled: $proto"
            else
                fail "uncommon network protocol not disabled: $proto"
            fi
        done

        # Cron permissions (Lynis FILE-7524): 0600 files, 0700 directories.
        local path mode
        for path in /etc/crontab /etc/cron.deny; do
            mode=$(stat -c '%a' "$path" 2>/dev/null || true)
            if [[ "$mode" == "600" ]]; then
                pass "cron file permissions: $path is 0600"
            else
                fail "cron file permissions wrong: $path is ${mode:-missing}, expected 0600"
            fi
        done
        for path in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
            mode=$(stat -c '%a' "$path" 2>/dev/null || true)
            if [[ "$mode" == "700" ]]; then
                pass "cron directory permissions: $path is 0700"
            else
                fail "cron directory permissions wrong: $path is ${mode:-missing}, expected 0700"
            fi
        done
        if grep -q '^z /etc/crontab' /usr/lib/tmpfiles.d/halcyon-hardening.conf 2>/dev/null; then
            pass "tmpfiles rule re-enforces cron permissions at boot"
        else
            fail "tmpfiles cron permission rule missing"
        fi
        # Without this, finalize's /var wipe leaves /var/lib/fail2ban absent and the
        # server exits 255 at every boot: fail2ban_t cannot create it in var_lib_t.
        if grep -q '^d /var/lib/fail2ban' /usr/lib/tmpfiles.d/halcyon-hardening.conf 2>/dev/null; then
            pass "tmpfiles rule creates fail2ban database directory"
        else
            fail "tmpfiles rule for /var/lib/fail2ban missing"
        fi

        # psacct.service is conditioned on /var/account, which finalize wipes.
        if grep -q '^d /var/account' /usr/lib/tmpfiles.d/halcyon-hardening.conf 2>/dev/null; then
            pass "tmpfiles rule creates process accounting directory"
        else
            fail "tmpfiles rule for /var/account missing (psacct.service would be skipped)"
        fi

        # Security units enabled by configure-system-services.
        local unit
        for unit in \
            /etc/systemd/system/multi-user.target.wants/fail2ban.service \
            /etc/systemd/system/multi-user.target.wants/halcyon-hosts-entry.service \
            /etc/systemd/system/multi-user.target.wants/halcyon-shadow-sync.service \
            /etc/systemd/system/multi-user.target.wants/halcyon-security-posture.service \
            /etc/systemd/system/multi-user.target.wants/halcyon-aide-init.service \
            /etc/systemd/system/timers.target.wants/halcyon-aide-check.timer \
            /etc/systemd/system/multi-user.target.wants/rngd.service \
            /etc/systemd/system/multi-user.target.wants/psacct.service \
            /etc/systemd/system/multi-user.target.wants/sysstat.service \
            /etc/systemd/system/sysstat.service.wants/sysstat-collect.timer \
            /etc/systemd/system/sysstat.service.wants/sysstat-summary.timer \
            /etc/systemd/system/sysstat.service.wants/sysstat-rotate.timer \
            /etc/systemd/system/multi-user.target.wants/halcyon-mor.service; do
            if [[ -e "$unit" ]]; then
                pass "security unit enabled: $unit"
            else
                fail "security unit not enabled: $unit"
            fi
        done

        # MOR bit helper (Lynis CRYP-8006).
        if [[ -x /usr/bin/halcyon-mor ]]; then
            pass "halcyon-mor helper present and executable"
        else
            fail "/usr/bin/halcyon-mor missing or not executable"
        fi

        # faillock.conf is inert unless pam_faillock is in the PAM stack, which the
        # authselect `local` profile only does with the with-faillock feature.
        if authselect check && [[ "$(authselect current --raw)" == local\ * ]]; then
            pass "authselect local profile is valid"
        else
            fail "authselect profile is invalid or not local"
        fi
        local pam_stack faillock_phase
        for pam_stack in system-auth password-auth; do
            for faillock_phase in preauth authfail; do
                if grep -Eq "^[[:space:]]*auth[[:space:]].*pam_faillock\\.so[[:space:]].*${faillock_phase}([[:space:]]|$)" "/etc/pam.d/$pam_stack"; then
                    pass "pam_faillock $faillock_phase active in $pam_stack"
                else
                    fail "pam_faillock $faillock_phase missing in $pam_stack"
                fi
            done
        done

        if firewall-offline-cmd --check-config && \
           [[ "$(firewall-offline-cmd --get-default-zone)" == FedoraWorkstation ]] && \
           [[ "$(systemctl is-enabled firewalld.service)" == enabled ]] && \
           [[ "$(firewall-offline-cmd --zone=FedoraWorkstation --list-services)" == dhcpv6-client ]] && \
           [[ "$(firewall-offline-cmd --zone=FedoraWorkstation --list-ports)" == 47/tcp ]] && \
           [[ "$(firewall-offline-cmd --zone=FedoraWorkstation --get-target)" == default ]]; then
            pass "firewalld enabled with validated restrictive default zone"
        else
            fail "firewalld configuration, default zone, allowed ports or enabled state is incorrect"
        fi
        local lock_directive
        for lock_directive in 'deny = 10' 'unlock_time = 900' 'even_deny_root'; do
            if grep -qxF "$lock_directive" /etc/security/faillock.conf 2>/dev/null; then
                pass "faillock policy present: $lock_directive"
            else
                fail "faillock policy missing: $lock_directive"
            fi
        done

        # Password policy follows NIST SP 800-63B-4: long minimum, no composition rules.
        local pwq_directive
        for pwq_directive in 'minlen = 15' 'dcredit = 0' 'ucredit = 0' 'lcredit = 0' 'ocredit = 0' 'dictcheck = 1'; do
            if grep -qxF "$pwq_directive" /etc/security/pwquality.conf 2>/dev/null; then
                pass "pwquality policy present: $pwq_directive"
            else
                fail "pwquality policy missing: $pwq_directive"
            fi
        done

        # wazuh-agent lives entirely under /var/ossec, which finalize wipes.
        if [[ -e /etc/systemd/system/multi-user.target.wants/wazuh-agent.service ]]; then
            fail "wazuh-agent must not be enabled in the shipped image"
        else
            pass "wazuh-agent not enabled"
        fi

        # Group files (Lynis AUTH-9216): grpck must be silent.
        local grp_output
        grp_output=$(grpck -r 2>&1 || true)
        if [[ -z "$grp_output" ]]; then
            pass "grpck reports no group file inconsistencies"
        else
            fail "grpck reports group file inconsistencies: $grp_output"
        fi

        # secureblue-derived hardening artifacts.
        local sb_file
        for sb_file in \
            /usr/lib/sysctl.d/55-halcyon-hardening.conf \
            /usr/lib/bootc/kargs.d/10-halcyon-hardening.toml \
            /usr/lib/modprobe.d/halcyon-blocklist.conf \
            /usr/lib/modprobe.d/halcyon-framebuffer.conf \
            /etc/security/faillock.conf \
            /etc/security/pwquality.conf \
            /etc/security/limits.d/60-disable-coredump.conf \
            /etc/chrony.conf \
            /etc/firewalld/zones/FedoraWorkstation.xml \
            /usr/lib/NetworkManager/conf.d/40-halcyon.conf \
            /usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-killmode.conf \
            /usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-hardening.conf \
            /usr/lib/systemd/system-preset/35-halcyon-security.preset; do
            if [[ -f "$sb_file" ]]; then
                pass "hardening file present: $sb_file"
            else
                fail "hardening file missing: $sb_file"
            fi
        done

        # Spot-check the module blocklist against secureblue's attack-surface set.
        local blocked_module
        for blocked_module in rxrpc esp4 xfrm_user af_key ksmbd firewire-core nfc vivid netconsole floppy; do
            if grep -qE "^install[[:space:]]+${blocked_module}[[:space:]]+/bin/false$" /usr/lib/modprobe.d/halcyon-blocklist.conf 2>/dev/null; then
                pass "kernel module blocked: $blocked_module"
            else
                fail "kernel module not blocked: $blocked_module"
            fi
        done

        # NetworkManager sandboxing: the minimal drop-in must be present, and the
        # directives that break NetworkManager must not creep in. Directives are
        # read with comments stripped; the file documents the forbidden ones.
        local nm_dropin=/usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-hardening.conf nm_directive
        for nm_directive in LockPersonality=true RestrictRealtime=true RestrictSUIDSGID=true RestrictNamespaces=true ProtectControlGroups=true SystemCallArchitectures=native \
            ProtectKernelLogs=true ProtectClock=true 'SystemCallFilter=~@clock @cpu-emulation @debug @obsolete @raw-io @reboot @swap'; do
            if grep -qxF "$nm_directive" "$nm_dropin" 2>/dev/null; then
                pass "NetworkManager hardening directive present: $nm_directive"
            else
                fail "NetworkManager hardening directive missing: $nm_directive"
            fi
        done
        if grep -v '^[[:space:]]*#' "$nm_dropin" 2>/dev/null | grep -qE '^(ProtectKernelTunables|ProtectKernelModules|ProtectSystem|ProtectHostname|ProtectProc|ProcSubset|MemoryDenyWriteExecute|NoNewPrivileges|DevicePolicy|DeviceAllow|PrivateDevices|PrivateTmp|PrivateNetwork|PrivateUsers|InaccessiblePaths|CapabilityBoundingSet)='; then
            fail "NetworkManager hardening drop-in sets a directive known to break NetworkManager"
        else
            pass "NetworkManager hardening drop-in avoids directives that break it"
        fi
        if grep -v '^[[:space:]]*#' "$nm_dropin" 2>/dev/null | grep -E '^RestrictAddressFamilies=' | grep -q 'AF_NETLINK' && \
           grep -v '^[[:space:]]*#' "$nm_dropin" | grep -E '^RestrictAddressFamilies=' | grep -q 'AF_PACKET'; then
            pass "NetworkManager keeps AF_NETLINK and AF_PACKET"
        else
            fail "NetworkManager RestrictAddressFamilies must include AF_NETLINK and AF_PACKET"
        fi

        # SELinux must stay enforcing with the targeted policy (it is what confines
        # NetworkManager_t), and no kernel argument may weaken it.
        if grep -qxF 'SELINUX=enforcing' /etc/selinux/config 2>/dev/null && \
           grep -qxF 'SELINUXTYPE=targeted' /etc/selinux/config 2>/dev/null; then
            pass "SELinux is enforcing with the targeted policy"
        else
            fail "/etc/selinux/config must set SELINUX=enforcing and SELINUXTYPE=targeted"
        fi
        if cat /usr/lib/bootc/kargs.d/*.toml 2>/dev/null | grep -v '^[[:space:]]*#' | grep -qE 'selinux=0|enforcing=0'; then
            fail "a bootc kernel argument disables SELinux"
        else
            pass "no bootc kernel argument disables SELinux"
        fi

        # Confinement of these daemons hangs on one file context each: without it the
        # binary is bin_t and systemd starts it as unconfined_service_t, silently.
        # smartd already lost its context this way (policy still says /usr/sbin/smartd,
        # which no longer matches after the /usr/sbin merge), so assert the /usr/bin
        # paths for the security-relevant services this image depends on.
        local fc=/etc/selinux/targeted/contexts/files/file_contexts exec_ctx
        for exec_ctx in NetworkManager:NetworkManager_exec_t firewalld:firewalld_exec_t aide:aide_exec_t; do
            # /usr/bin only: a /usr/sbin entry is exactly the stale form smartd has.
            if grep -qE "^/usr/bin/${exec_ctx%%:*}[[:space:]]+--[[:space:]]+system_u:object_r:${exec_ctx#*:}:" "$fc" 2>/dev/null; then
                pass "SELinux confines /usr/bin/${exec_ctx%%:*} (${exec_ctx#*:})"
            else
                fail "no /usr/bin file context for ${exec_ctx%%:*} -> ${exec_ctx#*:}: it would run unconfined"
            fi
        done

        # Modules that must stay loadable: cifs.ko depends on cifs_md4, the Intel
        # ice NIC driver and the WWAN stack depend on the gnss core, and UDF is the
        # filesystem of DVD/Blu-ray data discs.
        for blocked_module in cifs_md4 gnss udf; do
            if grep -qE "^[[:space:]]*(install|blacklist)[[:space:]]+${blocked_module}([[:space:]]|$)" /usr/lib/modprobe.d/halcyon-blocklist.conf 2>/dev/null; then
                fail "kernel module must not be blocked: $blocked_module"
            else
                pass "kernel module stays loadable: $blocked_module"
            fi
        done

        # sysctl guards: values that were deliberately relaxed from secureblue.
        local sysctl_conf=/usr/lib/sysctl.d/55-halcyon-hardening.conf
        if grep -qxF 'net.ipv4.conf.all.rp_filter = 2' "$sysctl_conf" 2>/dev/null && \
           grep -qxF 'net.ipv4.conf.default.rp_filter = 2' "$sysctl_conf" 2>/dev/null; then
            pass "rp_filter is loose (2) for tunnel and bridge interfaces"
        else
            fail "rp_filter must stay loose (2): strict mode breaks Tailscale/container routing"
        fi
        if grep -qxF 'kernel.sysrq = 0' "$sysctl_conf" 2>/dev/null; then
            pass "SysRq disabled; ujust may raise it at runtime"
        else
            fail "kernel.sysrq must be 0"
        fi
        if grep -qE '^[[:space:]]*(fs\.binfmt_misc\.status|net\.ipv4\.tcp_timestamps)[[:space:]]*=' "$sysctl_conf" 2>/dev/null; then
            fail "sysctl hardening must not set fs.binfmt_misc.status or net.ipv4.tcp_timestamps"
        else
            pass "binfmt_misc and tcp_timestamps left at kernel defaults"
        fi

        if grep -q 'hash_pointers=always' /usr/lib/bootc/kargs.d/10-halcyon-hardening.toml 2>/dev/null && \
           grep -q 'page_alloc.shuffle=1' /usr/lib/bootc/kargs.d/10-halcyon-hardening.toml 2>/dev/null && \
           ! grep -v '^[[:space:]]*#' /usr/lib/bootc/kargs.d/10-halcyon-hardening.toml | grep -qE 'rd\.shell=0|rd\.emergency=halt|loglevel=0'; then
            pass "bootc hardening kernel arguments present"
        else
            fail "bootc hardening kernel arguments missing"
        fi
    ✓ • 0ms

## Activity

    $ rtk read /var/home/ahsan/.codex/plugins/cache/openai-curated-remote/app-69ea4ed2cf7c8191b742ef3622479ddd/4.0.1/skills/Search/references/searching.md; rg --files system_files | rtk rg '(polkit|tuned|aide|mor|posture|blocklist|hardening.conf)'
    # Searching with Exa

    You have two tools:
    - **`web_search_exa`** -- search by query. Supports `query` and `numResults` params. Use `category:<type>` inline in the query string for category filtering.
    - **`web_fetch_exa`** -- read full content from known URLs. Use after search when snippets are insufficient.

    ## How Exa Search Works

    Exa uses vector embeddings, not keywords. It finds pages semantically similar to your query. It does not match keywords exactly, directly understand boolean logic (AND/OR/NOT), or validate that results meet your criteria. You are describing a target page, and Exa returns the nearest neighbors in embedding space.

    ## Writing Good Queries

    **Describe the page you want to find**, not the fact you want to know.

    | Looking for | Bad query | Good query |
    |---|---|---|
    | Blog posts about X | "X" | "detailed blog post about X written by a practitioner" |
    | Company doing Y | "Y company" | "category:company startup building Y for enterprise" |
    | Person at company | "person at company" | "category:people senior engineer at Acme" |

    Write queries as natural grammatical phrases.

    **`numResults` sizing -- match to query precision:**

    | Query precision | numResults | Example |
    |---|---|---|
    | Named entity (specific person/company) | 5 | `"WaveForms AI founding story funding details"` |
    | Precise filter (narrow category + constraints) | 10 | `"category:company developer tools API testing Series A"` |
    | Broad discovery (wide category, few constraints) | 15 | `"category:news engineer launches startup 2025 2026"` |

    Never use numResults above 25. If you need more coverage, run more queries with different angles at n=10-15 rather than one query at n=50.

    **Use category filters** when searching for a specific entity type. Available inline categories: `company`, `research paper`, `news`, `personal site`, `people`. Add `category:<type>` at the start of your query string.

    ```
    web_search_exa { "query": "category:research paper sparse attention mechanisms for long context", "numResults": 10 }
    web_search_exa { "query": "category:people VP Engineering AI infrastructure San Francisco", "numResults": 10 }
    web_search_exa { "query": "category:company developer tools for API testing", "numResults": 10 }
    ```

    ## Query Diversity

    When you need to run multiple queries on the same topic, make sure they target genuinely different angles, not just synonym swaps. "overhyped" vs "overrated" vs "disappointment" are the same angle. A skeptic angle vs a builder angle vs a practitioner angle are genuinely different.

    **Word order affects embeddings.** "Python async patterns for web scraping" and "web scraping async patterns in Python" can sometimes return different results. Use this to your advantage when you need coverage -- run 2-3 phrasings in parallel.

    ## Encoding Time

    If your task involves time ("last week", "recent", "this month"), calculate exact dates FIRST from the current date in your environment context. Then encode dates semantically in the query: "published in March 2026" rather than using date filters. Never eyeball dates.

    ## Anti-Patterns

    - Boolean operators ("AND", "NOT") are just words to Exa, not operators
    - Quotes don't force exact phrase matching
    - Very short queries (1-2 words) produce scattered, low-quality results
    - Don't use dates from examples -- always calculate from the current date

    ## When Searches Return Nothing

    If a query returns 0 or only irrelevant results:
    a. Make the query longer and more specific
    b. Try a different angle, not a synonym swap
    c. If multiple angles return nothing, the topic likely has limited web coverage -- report that rather than fabricating results

    ## Domain-Specific Patterns

    If your task involves any of these domains, read the relevant pattern file(s) for specialized query strategies. Pick whichever files match your task — most tasks use 1-2.

    | File (same directory as this file) | Domain |
    |---|---|
    | `patterns-people.md` | People by role, company, location |
    | `patterns-companies.md` | Companies by category, stage, competitors, funding |
    | `patterns-papers.md` | Academic/research papers |
    | `patterns-relationships.md` | Hidden connections (clients, collaborators) |
    | `patterns-code.md` | Code, APIs, docs, errors |
    | `patterns-news.md` | News, recent events, reactions |

    ## When `web_fetch_exa` Fails

    Fall back to fetching with any other fetch tool you have access to. If that also fails, skip it and work with remaining sources.

    ## After Getting Results

    Exa returns similarity, not validation. You must review titles/snippets and discard irrelevant results using your judgment. Don't assume all results match your criteria. For the most promising results, use `web_fetch_exa` to read the full content.

    ```
    web_fetch_exa {
      "urls": ["https://promising-url-1.com", "https://promising-url-2.com"],
    }
    ```
    system_files/overrides/etc/aide.conf
    system_files/overrides/etc/ssh/sshd_config.d/10-halcyon-hardening.conf
    system_files/desktop/etc/modprobe.d/halcyon-hardening.conf
    system_files/desktop/usr/lib/tuned/profiles/throughput-performance-bazzite/tuned.conf
    system_files/desktop/usr/lib/tuned/profiles/throughput-performance-bazzite/script.sh
    system_files/desktop/usr/lib/tuned/profiles/powersave-bazzite/tuned.conf
    system_files/desktop/usr/lib/tuned/profiles/powersave-bazzite/script.sh
    system_files/desktop/usr/lib/tuned/profiles/balanced-bazzite/tuned.conf
    system_files/desktop/usr/lib/tuned/profiles/balanced-bazzite/script.sh
    system_files/desktop/usr/lib/tmpfiles.d/halcyon-hardening.conf
    system_files/desktop/usr/share/ublue-os/bazaar/blocklist.yaml
    system_files/desktop/usr/lib/modprobe.d/halcyon-blocklist.conf
    system_files/desktop/usr/lib/systemd/system/halcyon-security-posture.service
    system_files/desktop/usr/lib/systemd/system/halcyon-mor.service
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-init.service
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.timer
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.service
    system_files/desktop/usr/share/polkit-1/rules.d/20-privileged-ruser.rules
    system_files/desktop/usr/lib/systemd/system/NetworkManager.service.d/40-halcyon-hardening.conf
    system_files/desktop/usr/bin/halcyon-security-posture
    system_files/desktop/usr/bin/halcyon-mor
    system_files/desktop/usr/share/polkit-1/actions/org.bazzite.privileged.user.setup.policy
    system_files/desktop/usr/lib/sysctl.d/55-halcyon-hardening.conf
    ✓ • 0ms

## Assistant

The image already has substantial hardening: SELinux enforcement checks, restricted kernel interfaces, key-only SSH, login lockouts, auditing, and a restrictive firewall zone. I also found settings worth reviewing for compatibility, including ARP filtering and blocked networking modules.

I’ll use your balanced-desktop and mixed-network choices to prioritize stronger isolation, reliable VPN/container networking, and measured latency improvements.

## Activity

    mcp tool: codex_apps/exa.web_search_exa({"query":"OpenWrt official SQM cake fq_codel bufferbloat latency bandwidth","numResults":5}) · Failed
    Parameters failed connector schema validation: objective [required]: Missing required property; objective [required]: Missing required property
    structured result: {"error":"Parameters failed connector schema validation: objective [required]: Missing required property; objective [required]: Missing required property","error_code":"INVALID_ARGUMENT","error_data":{"reason":"INVALID_PARAMETERS","clamp_errors":[{"path":["objective"],"message":"Missing required property","keyword":"required"},{"path":["objective"],"message":"Missing required property","keyword":"required"}],"clamp_rewrites":[{"path":["_meta"],"message":"Removed additional property '_meta'","original_value":{"callId":"exec-547f8ac1-1232-4bea-819e-045dbde1e325","sessionId":"01a1ea10-d8b7-7d32-85ee-ecd89d00ef65","windowId":"01a1ea10-d8b7-7d32-85ee-ecd89d00ef65:0","itemId":"ctc_001993750a125304016afc6fd2826c87d0b07f54efdef1c149","progressToken":1,"openai/userLocation":{"city":"Dhaka","region":"Dhaka Division","country":"BD","timezone":"Asia/Dhaka"}},"new_value":null,"keyword":"additionalProperties"}]}}

## Activity

    mcp tool: codex_apps/exa.web_search_exa({"query":"Linux kernel official ip-sysctl documentation arp_filter arp_ignore drop_gratuitous_arp rp_filter","numResults":5}) · Failed
    Parameters failed connector schema validation: objective [required]: Missing required property; objective [required]: Missing required property
    structured result: {"error":"Parameters failed connector schema validation: objective [required]: Missing required property; objective [required]: Missing required property","error_code":"INVALID_ARGUMENT","error_data":{"reason":"INVALID_PARAMETERS","clamp_errors":[{"path":["objective"],"message":"Missing required property","keyword":"required"},{"path":["objective"],"message":"Missing required property","keyword":"required"}],"clamp_rewrites":[{"path":["_meta"],"message":"Removed additional property '_meta'","original_value":{"callId":"exec-20078add-a3b9-42d4-924e-8abbe33c843e","sessionId":"01a1ea10-d8b7-7d32-85ee-ecd89d00ef65","windowId":"01a1ea10-d8b7-7d32-85ee-ecd89d00ef65:0","itemId":"ctc_001993750a125304016afc6fd2826c87d0b07f54efdef1c149","progressToken":2,"openai/userLocation":{"city":"Dhaka","region":"Dhaka Division","country":"BD","timezone":"Asia/Dhaka"}},"new_value":null,"keyword":"additionalProperties"}]}}

## Activity

    mcp tool: context7/resolve-library-id({"libraryName":"NetworkManager","query":"NetworkManager configuration DNS systemd-resolved DNS over TLS connection DNS priority VPN routing randomized Wi-Fi MAC"}) · Completed
    Available Libraries:

    - Title: NetworkManager
    - Context7-compatible library ID: /websites/networkmanager_dev
    - Description: NetworkManager is a system daemon that automatically manages network connections and configuration, providing a rich D-Bus API for network management on Linux.
    - Code Snippets: 7559
    - Source Reputation: High
    - Benchmark Score: 70.79
    ----------
    - Title: NetworkManager Documentation
    - Context7-compatible library ID: /websites/networkmanager_dev_api
    - Description: Documentation for NetworkManager, covering its configuration, services, command-line tools, and comprehensive DBus API for network management in Linux systems.
    - Code Snippets: 1900
    - Source Reputation: High
    - Benchmark Score: 69.88
    ----------
    - Title: NetworkManager
    - Context7-compatible library ID: /git_gitlab_freedesktop_org/networkmanager_networkmanager
    - Description: NetworkManager is a system service that manages network connections and configurations, automatically keeping an active network connection available with support for wired, wireless, mobile, and VPN connectivity.
    - Code Snippets: 676
    - Source Reputation: High
    - Benchmark Score: 55.15
    ----------
    - Title: NetworkManagerQt
    - Context7-compatible library ID: /kde/networkmanager-qt
    - Description: NetworkManagerQt is a Qt wrapper for the NetworkManager DBus API that enables access to all NetworkManager features, allowing you to manage connections and control network devices.
    - Code Snippets: 209
    - Source Reputation: High
    - Benchmark Score: 55.86
    ----------
    - Title: Netplan
    - Context7-compatible library ID: /websites/netplan_readthedocs_io_en
    - Description: Netplan is a network configuration abstraction renderer for Linux systems. It uses YAML descriptions to configure network interfaces across back ends like NetworkManager and systemd-networkd, managed through the netplan CLI and libnetplan API.
    - Code Snippets: 693
    - Source Reputation: High
    - Benchmark Score: 80.42

## Activity

    mcp tool: context7/query-docs({"libraryId":"/websites/networkmanager_dev","query":"NetworkManager.conf dns systemd-resolved connection DNS over TLS ipv4.dns-priority negative priority VPN DNS leak prevention wifi.scan-rand-mac-address cloned-mac-address stable-ssid powersave"}) · Completed
    ### ipv4 setting

    Source: https://networkmanager.dev/docs/api/latest/nm-settings-dbus.html

    dns-priority | int32 | 0 | DNS servers priority. The relative priority for DNS servers specified by this setting. A lower numerical value is better (higher priority). Negative values have the special effect of excluding other configurations with a greater numerical priority value; so in presence of at least one negative priority, only DNS servers from connections with the lowest priority value will be used. To avoid all DNS leaks, set the priority of the profile that should be used to the most negative value of all active connections profiles. Zero selects a globally configured default value. If the latter is missing or zero too, it defaults to 50 for VPNs (including WireGuard) and 100 for other connections. Note that the priority is to order DNS settings for multiple active connections. It does not disambiguate multiple DNS servers within the same connection profile. When multiple devices have configurations with the same priority, VPNs will be considered first, then devices with the best (lowest metric) default route and then all other devices. When using dns=default, servers with higher priority will be on top of resolv.conf. To prioritize a given server over another one within the same connection, just specify them in the desired order. Note that commonly the resolver tries name servers in /etc/resolv.conf in the order listed, proceeding with the next server in the list on failure. See for example the "rotate" option of the dns-options setting. If there are any negative DNS priorities, then only name servers from the devices with that lowest priority will be considered. When using a DNS resolver that supports Conditional Forwarding or Split DNS (with dns=dnsmasq or dns=systemd-resolved settings), each connection is used to query domains in its search list. The search domains determine which name servers to ask, and the DNS priority is used to prioritize name servers based on the domain. Queries for domains not present in any search list are routed through connections having the '~.' special wildcard domain, which is added automatically to connections with the default route (or can be added manually). When multiple connections specify the same domain, the one with the best priority (lowest numerical value) wins. If a sub domain is configured on another interface it will be accepted regardless the priority, unless parent domain on the other interface has a negative priority, which causes the sub domain to be shadowed. With Split DNS one can avoid undesired DNS leaks by properly configuring DNS priorities and the search domains, so that only name servers of the desired interface are configured.

    --------------------------------

    ### main section > dns

    Source: https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html

    `dns` |  Set the DNS processing mode. If the key is unspecified, `default` is used, unless `/etc/resolv.conf` is a symlink to `/run/systemd/resolve/stub-resolv.conf`, `/run/systemd/resolve/resolv.conf`, `/lib/systemd/resolv.conf` or `/usr/lib/systemd/resolv.conf`. In that case, `systemd-resolved` is chosen automatically.  `default`: NetworkManager will update `/etc/resolv.conf` to reflect the nameservers provided by currently active connections. The `rc-manager` setting (below) controls how this is done. `dnsmasq`: NetworkManager will run dnsmasq as a local caching nameserver, using "Conditional Forwarding" if you are connected to a VPN, and then update `resolv.conf` to point to the local nameserver. It is possible to pass custom options to the dnsmasq instance by adding them to files in the "`/etc/NetworkManager/dnsmasq.d/`" directory. Note that when multiple upstream servers are available, dnsmasq will initially contact them in parallel and then use the fastest to respond, probing again other servers after some time. This behavior can be modified passing the 'all-servers' or 'strict-order' options to dnsmasq (see the manual page for more details). `systemd-resolved`: NetworkManager will push the DNS configuration to systemd-resolved `dnsconfd`: NetworkManager will push the DNS configuration to dnsconfd and by default set ipvX.routed-dns to yes, so servers are contacted through right interfaces. `none`: NetworkManager will not modify resolv.conf. This implies `rc-manager` `unmanaged` Note that the plugins `dnsmasq`,`systemd-resolved` and `dnsconfd` are caching local nameservers. Hence, when NetworkManager writes `/run/NetworkManager/resolv.conf` and `/etc/resolv.conf` (according to `rc-manager` setting below), the name server there will be localhost only. NetworkManager also writes a file `/run/NetworkManager/no-stub-resolv.conf` that contains the original name servers pushed to the DNS plugin. When using `dnsmasq`,`systemd-resolved` and `dnsconfd` per-connection added dns servers will always be queried using the device the connection has been activated on.

    --------------------------------

    ### Details

    Source: https://networkmanager.dev/docs/api/latest/nm-settings-ifcfg-rh.html

    **Table 27. ipv4 setting**
    Property | Ifcfg-rh Variable | Default | Description
    ---|---|---|---
    method | BOOTPROTO | none | Method used for IPv4 protocol configuration.**Allowed values:** none, dhcp (bootp), static, ibft, autoip, shared
    dns | DNS1, DNS2, ... |  | List of DNS servers. Even if NetworkManager supports many DNS servers, initscripts and resolver only care about the first three, usually.**Example:** DNS1=1.2.3.4 DNS2=10.0.0.254 DNS3=8.8.8.8
    dns-search | DOMAIN |  | List of DNS search domains.
    addresses | IPADDR, PREFIX (NETMASK), IPADDR1, PREFIX1 (NETMASK1), ... |  | List of static IP addresses.**Example:** IPADDR=10.5.5.23 PREFIX=24 IPADDR1=1.1.1.2 PREFIX1=16
    gateway | GATEWAY |  | Gateway IP address.**Example:** GATEWAY=10.5.5.1
    routes | ADDRESS1, NETMASK1, GATEWAY1, METRIC1, OPTIONS1, ... |  | List of static routes. They are not stored in ifcfg-* file, but in route-* file instead.
    ignore-auto-routes | PEERROUTES _(+)_ | yes | PEERROUTES has the opposite meaning as 'ignore-auto-routes' property.
    ignore-auto-dns | PEERDNS | yes | PEERDNS has the opposite meaning as 'ignore-auto-dns' property.
    dhcp-send-hostname | DHCP_SEND_HOSTNAME _(+)_ | yes | Whether DHCP_HOSTNAME should be sent to the DHCP server.
    dhcp-hostname | DHCP_HOSTNAME |  | Hostname to send to the DHCP server. When both DHCP_HOSTNAME and DHCP_FQDN are specified only the latter is used.
    never-default | DEFROUTE (GATEWAYDEV in /etc/sysconfig/network) | yes | DEFROUTE=no tells NetworkManager that this connection should not be assigned the default route. DEFROUTE has the opposite meaning as 'never-default' property.
    may-fail | IPV4_FAILURE_FATAL _(+)_ | no | IPV4_FAILURE_FATAL has the opposite meaning as 'may-fail' property.
    route-metric | IPV4_ROUTE_METRIC _(+)_ | -1 | IPV4_ROUTE_METRIC is the default IPv4 metric for routes on this connection. If set to -1, a default metric based on the device type is used.
    route-table | IPV4_ROUTE_TABLE _(+)_ | 0 | IPV4_ROUTE_TABLE enables policy-routing and sets the default routing table.
    dns-options | RES_OPTIONS _(+)_ |  | List of DNS options to be added to /etc/resolv.conf**Example:** RES_OPTIONS=ndots:2 timeout:3
    dns-priority | IPV4_DNS_PRIORITY _(+)_ | 0 | The priority for DNS servers of this connection. Lower values have higher priority. If zero, the default value will be used (50 for VPNs, 100 for other connections). A negative value prevents DNS from other connections with greater values to be used.**Example:** IPV4_DNS_PRIORITY=20
    auto-route-ext-gw | IPV4_AUTO_ROUTE_EXT_GW _(+)_ | yes | VPN connections will default to add the route automatically unless this setting is set to FALSE. For other connection types, adding such an automatic route is currently not supported and setting this to TRUE has no effect.
    replace-local-rule | IPV4_REPLACE_LOCAL_RULE _(+)_ | no | Connections will default to keep the autogenerated priority 0 local rule unless this setting is set to TRUE.
    dhcp-client-id | DHCP_CLIENT_ID _(+)_ |  | A string sent to the DHCP server to identify the local machine. A binary value can be specified using hex notation ('aa:bb:cc').**Example:** DHCP_CLIENT_ID=ax-srv-1; DHCP_CLIENT_ID=01:44:44:44:44:44:44
    dad-timeout | ACD_TIMEOUT _(+)_ , ARPING_WAIT | missing variable means global default (config override or zero) | Timeout (in milliseconds for ACD_TIMEOUT or in seconds for ARPING_WAIT) for address conflict detection before configuring IPv4 addresses. 0 turns off the ACD completely, -1 means default value.**Example:** ACD_TIMEOUT=2000 or ARPING_WAIT=2
    dhcp-timeout | IPV4_DHCP_TIMEOUT _(+)_ |  | A timeout after which the DHCP transaction fails in case of no response.**Example:** IPV4_DHCP_TIMEOUT=10
    dhcp-hostname-flags | DHCP_HOSTNAME_FLAGS |  | flags for the DHCP hostname and FQDN properties**Example:** DHCP_HOSTNAME_FLAGS=5
    dhcp-fqdn | DHCP_FQDN |  | FQDN to send to the DHCP server. When both DHCP_HOSTNAME and DHCP_FQDN are specified only the latter is used.**Example:** DHCP_FQDN=foo.bar.com
    dhcp-vendor-class-identifier | DHCP_VENDOR_CLASS_IDENTIFIER _(+)_ |  | The Vendor Class Identifier DHCP option (60).**Example:** DHCP_VENDOR_CLASS_IDENTIFIER=foo
    link-local | IPV4_LINK_LOCAL _(+)_ |  | Configure link-local IP address in interaction with method**Example:** IPV4_LINK_LOCAL=auto

    --------------------------------

    ### main section > systemd-resolved

    Source: https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html

    `systemd-resolved` |  Additionally, send the connection DNS configuration to `systemd-resolved`. Defaults to "`true`".  Note that this setting has no effect if the main `dns` plugin is already `systemd-resolved`. It is complementary to the `dns` setting to configure systemd-resolved alongside the main plugin. If systemd-resolved is enabled, either via this setting or the main DNS plugin, the connectivity check resolves the hostname per-device.

    --------------------------------

    ### ipv4 setting

    Source: https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html

    `ipv4.routed-dns` |  Whether to add routes for DNS servers. When enabled, NetworkManager adds a route for each DNS server that is associated with this connection either statically (defined in the connection profile) or dynamically (for example, retrieved via DHCP). The route guarantees that the DNS server is reached via this interface. When set to "default" (-1), the value from global configuration is used; if no global default is defined, this feature is disabled. Format: choice (NMSettingIPConfigRoutedDns) Valid values: default (-1), no (0), yes (1)

## Activity

    mcp tool: codex_apps/exa.web_search_exa({"query":"OpenWrt official SQM cake fq_codel bufferbloat latency bandwidth","numResults":5,"objective":"Locate official OpenWrt guidance on reducing loaded latency using SQM at router bottlenecks."}) · Completed
    Title: How OpenWrt Vanquishes Bufferbloat
    URL: https://forum.openwrt.org/t/how-openwrt-vanquishes-bufferbloat/189381
    Published: N/A
    Author: N/A
    Highlights:
    Author: @richb-hanover-priv
    Post date: February 26, 2024, 3:24pm UTC

    ...

    In addition, OpenWrt has been used as a research platform to investigate (and solve) the problem of bufferbloat : the undesirable latency that comes from a router or other network equipment buffering too much data. The first real solution came in 2012 with the introduction of the fq_codel queue discipline that made a "no knobs" way to eliminate bufferbloat. The CAKE algorithm (created in 2015, merged into OpenWrt in 2018) provided even better performance. These techniques have since been applied to Wi-Fi to decrease buffering delays by an order of magnitude (typically, down to 10-100 msec) from earlier drivers.

    Bufferbloat occurs at a bottleneck — when fast links hit a slower link. This happens in a home router when Ethernet traffic reaches the slower ISP link, or when a fast laptop hits a slower Wi-Fi link. A router will queue up the data, to be doled out as it can. In a bad router, all the traffic goes into one queue, imposing a delay on the big flow as well as all other traffic. This is bufferbloat, and can reach several seconds, making the entire network "feel slow".

    ### About Smart Queue Management (SQM)

    OpenWrt minimizes bufferbloat using either the fq_codel or CAKE "Smart Queue Management" algorithms. These introduce a bottleneck queue within the router itself, generally, about 5% slower than the ISP link. This means that the traffic builds up in the SQM queues where they can be controlled.

    Both algorithms work by separating all traffic flows into their own queues: this isolates low traffic flows from the high volume flows. SQM then round-robins between the queues, sequentially removing a "fair" portion of data from each queue and transmitting it. A large flow can't monopolize the bottleneck link, but will use the full capacity when there's no other traffic.

    ## On ISP Connections

    OpenWrt supports SQM to control all the traffic flowing through the ISP bottleneck connection to provide fairness to all flows, and minimize the latency for all packets sent through the link.

    - What devices support this? All modern versions of OpenWrt support both CAKE and fq_codel from the Network -> SQM QoS settings. (You may need to install `luci-app-sqm` first.)
    - How do I configure it? You'll need to enter download and upload settings into SQM. Enter values that are about 5% slower than your ISP's claimed speed. For more details, see SQM (Smart Queue Management) on the OpenWrt wiki.

    ## On Wireless Connections

    Since OpenWrt is an access point, it can manage all the traffic flowing toward the many devices ("stations") that it serves. The OpenWrt Wi-Fi driver uses the following features to reduce latency:

    1. Individual transmit queues for each wireless station/client. Each queue uses fq_codel to control the amount of data queued for that station.

    ...

    ## On Variable Speed Connections

    Many ISP data rates vary from hour to hour (or even second by second), for example, cable modems, Starlink, 4G and 5G cellular plans, etc. This is a problem for the CAKE algorithm because it uses fixed speed settings to control the buffering. This leads to sub-optimal settings: if you set the speed too high and the actual link speed drops, then the latency goes up. If you set it too low, CAKE artificially limits the potential transfer rate.

    The cake-autorate algorithm addresses this. It continually measures the traffic load and latency to adjust the upload and download settings of the CAKE algorithm. See the README for more details.

    - What devices support this? All modern OpenWrt devices can install the cake-autorate software.
    - How do you configure this? The INSTALLATION.md instructions at the Github repo describe the process.

    ---

    Title: Smart Queue Management (SQM) - Minimizing Bufferbloat [Old OpenWrt Wiki]
    URL: https://oldwiki.archive.openwrt.org/doc/howto/sqm
    Published: N/A
    Author: N/A
    Highlights:
    Note: As of February 2017, the LEDE SQM HOWTO contains the most up-to-date information about setting up SQM.

    ## Preparation: Measure Your Current Speed and Latency

     Before you can optimize your network, you need to know its current state. Run a speed test to find your down/upload link speeds.

    1. When your network is relatively quiet, use DSLReports Speedtest at: http://www.dslreports.com/speedtest You will use this information below.
    2. This is probably a good time to Backup your Configuration.

     Note: As an alternative, you could do a lot more work and measure ping times while running one of the other speed tests at http://speedtest.net, http://testmy.net, or http://speedof.me but you would miss out on the accurate latency measurements of DSLReports…

    ...

    ## Configuring the SQM Bufferbloat Packages in OpenWrt

     The default values described below work quite well for most situations. You may be able to improve performance by experimenting with settings, see A little about tuning SQM below.

     To configure SQM, choose Network → SQM QoS to see the Smart Queue Management (SQM) GUI.

    1. In the Basic Settings tab:

    - Check the Enable box
    - Set the Interface name: to your wide area link (usually eth0 for OpenWrt, but check Network → Interfaces → Advanced to find the name for the WAN port.)
    - Set the Download and Upload speeds to 80-95% of the speed you measured above in the Preparation.
    2. In the Queue Discipline tab, you can leave the settings at their default.

    - Choose fq_codel (the default)
    - Choose simple.qos (the default)
    - Note: In 2017, SQM-QoS works better with cake and piece_of_cake.qos as default.)
    - The Advanced Configuration defaults are designed to work well out of the box.
    3. In the Link Layer Adaptation tab, choose the kind of link you have:

    - For VDSL - Choose Ethernet, and set per packet overhead to 8
    - For DSL of any other type - Choose ATM, and set per packet overhead to 44
    - For Cable or other kinds of connections - Choose none (default)
    4. Click Save & Apply. That's it!

     Measure your latency again with the speed test. You should notice that the measured ping times should only be slightly larger during the downloads and uploads. Try using VoIP, Skype, Facetime, gaming, DNS, and general web browsing. They should be much more pleasant, even if someone's uploading or downloading a lot of data.

     You've reduced your connection's bufferbloat!

    ## A little about tuning SQM

     The steps above will control latency well without additional effort. The 80-95% figures mentioned above are good first-cut estimates, but you can often gain more speed while still controlling latency by making a couple experiments to adjust the settings.

     The most important settings are the Download and Upload speeds. While it may seem counterintuitive, it may be your upstream buffering that is slowing your downstream. Remember that each packet that is sent in a TCP connection needs to be acknowledged, so you are always doing both.

     Adjust the Download and Upload speeds upwards until the latency begins to increase, then enter a slightly lower final value. One good test for this is the DSLReports Speed Test because it automatically measures latency as well as speed. Then do the same for the Upload entry. It may be worthwhile to tweak the two a bit up and down to find a sweet spot for your connection and usage.

     Note: If you have a DSL link, the experiments above may produce Download and Upload values that are actually higher than the original speed test results. This is OK: the ATM framing bytes of a DSL link add an average of 9% overhead, and these settings simply tell SQM how to make up for that overhead.

     Note: If you use a cable modem, you should use a speed test that runs for a longer time. Cable modem makers have gamed speed tests thoroughly by using "Speedboost", which usually gives you an extra 10 mbits or so for the first 10 seconds (so the speed test will look good(!)). Don't be surprised if the "right" setting for your queue rates is significantly lower than the no-SQM speed test results. You may need to tune the speeds down from your initial settings to get the latency to the point you need for your own usage of your connection.

     You can also experiment with the other settings (read the "the details" sections below for more information), but they will not make nearly as large a difference as ensuring that the Download and Upload speeds are maximized.

    ...

    To use SQM in your OpenWrt router, use the SQM QoS tab in the web interface. This will optimize the performance of the WAN interface (generally eth0) that connects your router to the ISP/the Internet.

    ...

    ### SQM: Basic Settings Tab

     Set the Download and Upload speeds in the web GUI for the speed of your Internet connection. To do this

    1. Get a speed measurement. See Preparations above.
    2. Set Download and Upload according to those link speeds. See examples below.
    3. Be sure to check the Enable box and set the Interface for your WAN interface.
    4. (Optional) Read A little bit about tuning SQM above.

     Example 1: If your your provider boasts "7 megabit download/768 kbps upload", set Download to 5950 kbit/s and Upload to 653 kbit/s. Those numbers are 85% of the advertised speeds.

     Example 2: If you have measured your bandwidth with a speed test (be sure to disable SQM first), set the Download and Upload speeds to 95% of those numbers. For example, if you have measured 6.2 megabits down and 0.67 megabits up (6200 kbps and 670 kbps, respectively), set your Download and Upload speeds to 95% of those numbers (5890 and 637 kbps, respectively)

     Basic Settings - the details…

     SQM is designed to manage the queues of packets waiting to be sent across the slowest (bottleneck) link, which is usually your connection to the Internet. OpenWrt cannot automatically adapt to network conditions on DSL, cable modems or GPON without any settings. Since the majority of ISP provided configurations for buffering are broken today, you need take control of the bottleneck link away from the ISP and move it into OpenWrt so it can be fixed. You do this by entering link speeds that are a few percent below the actual speeds.

     Use a speed test program or web site like the DSL Reports Speed Test to get an estimate of the actual download and upload values. After setting the initial Download and Upload entries, you should feel free to try the suggestions at A little about tuning SQM above to see if you can further increase the speeds.

    ### SQM: Queue Discipline Tab

     The Queue Discipline tab controls how packets are prioritized for sending and receipt. The default settings shown here work very well for nearly all circumstances. Those defaults are:

    - fq_codel queueing discipline
    - simple.qos queue setup script
    - ECN for inbound packets
    - NOECN for outbound packets
    - The default values of the Advanced Configuration work fine

     Queueing Discipline - the details…

     The default fq_codel queueing discipline works well in virtually all situations. Feel free to try out other algorithms to see if they work better in your environment.

     The default simple.qos script has a traffic shaper (the Queueing Discipline you select) and three classes with different priorities for traffic. This provides good defaults.

     Explicit Congestion Notification (ECN) is a mechanism for notifying a sender that its packets are encountering congestion and that the sender should slow its packet delivery rate. Instead of dropping a packet, fq_codel marks the packet with a congestion notification and passes it along to the receiver. That receiver sends the congestion notification back to the sender, which can adjust its rate. This provides faster feedback than having the router drop the received packet. Note: this technique requires that the TCP stack on both sides enable ECN.

     At low bandwidth, we recommend that you turn ECN off for the Upload (outbound, egress) direction, because fq_codel handles and drops packets before they reach the bottleneck, leaving room for more important packets to get out. For the Download (inbound, ingress) link, we recommend you turn ECN on so that fq_codel can inform the local receiver (that will in turn notify the remote sender) that it has detected congestion without loss of a packet.

    ---

    Title: Getting SQM Running Right - Bufferbloat.net
    URL: https://www.bufferbloat.net/projects/bloat/wiki/Getting_SQM_Running_Right/
    Published: N/A
    Author: N/A
    Highlights:
    The Smart Queue Management (SQM) system on OpenWrt makes it easy to configure a rate limiter on your router. The goal is to set the software shaper to a bandwidth that is slightly lower than the actual (bloated) bottleneck in the hardware, so we can control the queue using FQ-CoDel or CAKE. In many cases, there is no real ground truth about the right setting, but we can find one by trial and error (tuning and doing repeated measurements until things improve).

    ---

    Title: General Discussion of SQM
    URL: https://forum.openwrt.org/t/general-discussion-of-sqm/30527
    Published: N/A
    Author: N/A
    Highlights:
    bufferbloat.net (IPv4) while pinging 1.1.1.1.
    Download and upload sessions are concurrent, each with 8
    ...
    , and then setting the buffer higher helps. To allow for higher rates the new sqm-scripts code defaults to a 1

    ---

    Title: What Can I Do About Bufferbloat? - Bufferbloat.net
    URL: https://www.bufferbloat.net/projects/bloat/wiki/What_can_I_do_about_Bufferbloat/
    Published: N/A
    Author: N/A
    Highlights:
    Then turn on SQM, setting the up and down speed to the measured values above. Keep running your speed test and adjusting the SQM speed settings until the latency remains low while achieving good speeds.

## Activity

    mcp tool: codex_apps/exa.web_search_exa({"query":"Linux kernel official ip-sysctl arp_filter arp_ignore drop_gratuitous_arp rp_filter","numResults":5,"objective":"Locate primary Linux kernel documentation verifying ARP hardening tradeoffs for VPN/container desktop networking."}) · Completed
    Title: IP Sysctl — The Linux Kernel  documentation
    URL: https://docs.kernel.org/networking/ip-sysctl.html
    Published: N/A
    Author: N/A
    Highlights:
    IP Sysctl — The Linux Kernel documentation

    # IP Sysctl¶

    ## /proc/sys/net/ipv4/* Variables¶

    ...

    ## IP Variables¶

    ...

    `conf/interface/*`
    : changes special settings per interface (where interface” is the name of your network interface)
    `conf/all/*`
    : is special, changes the settings for all interfaces

    ...

    rp_filter - INTEGER
    : - 0 - No source validation.
    - 1 - Strict mode as defined in RFC3704 Strict Reverse Path Each incoming packet is tested against the FIB and if the interface is not the best reverse path the packet check will fail. By default failed packets are discarded.
    - 2 - Loose mode as defined in RFC3704 Loose Reverse Path Each incoming packet’s source address is also tested against the FIB and if the source address is not reachable via any interface the packet check will fail.

    Current recommended practice in RFC3704 is to enable strict mode to prevent IP spoofing from DDos attacks. If using asymmetric routing or other complicated routing, then loose mode is recommended.

    The max value from conf/{all,interface}/rp_filter is used when doing source validation on the {interface}.

    Default value is 0. Note that some distributions enable it in startup scripts.
    src_valid_mark - BOOLEAN
    : - 0 - The fwmark of the packet is not included in reverse path route lookup. This allows for asymmetric routing configurations utilizing the fwmark in only one direction, e.g., transparent proxying.
    - 1 - The fwmark of the packet is included in reverse path route lookup. This permits rp_filter to function when the fwmark is used for routing traffic in both directions.

    This setting also affects the utilization of fmwark when performing source address selection for ICMP replies, or determining addresses stored for the IPOPT_TS_TSANDADDR and IPOPT_RR IP options.

    The max value from conf/{all,interface}/src_valid_mark is used.

    Default value is 0.
    arp_filter - BOOLEAN
    : - 1 - Allows you to have multiple network interfaces on the same subnet, and have the ARPs for each interface be answered based on whether or not the kernel would route a packet from the ARP’d IP out that interface (therefore you must use source based routing for this to work). In other words it allows control of which cards (usually 1) will respond to an arp request.
    - 0 - (default) The kernel can respond to arp requests with addresses from other interfaces. This may seem wrong but it usually makes sense, because it increases the chance of successful communication. IP addresses are owned by the complete host on Linux, not by particular interfaces. Only for more complex setups like load- balancing, does this behaviour cause problems.

    arp_filter for the interface will be enabled if at least one of conf/{all,interface}/arp_filter is set to TRUE, it will be disabled otherwise
    arp_announce - INTEGER
    : Define different restriction levels for announcing the local source IP address from IP packets in ARP requests sent on interface:

    - 0 - (default) Use any local address, configured on any interface
    - 1 - Try to avoid local addresses that are not in the target’s subnet for this interface. This mode is useful when target hosts reachable via this interface require the source IP address in ARP requests to be part of their logical network configured on the receiving interface. When we generate the request we will check all our subnets that include the target IP and will preserve the source address if it is from such subnet. If there is no such subnet we select source address according to the rules for level 2.
    - 2 - Always use the best local address for this target. In this mode we ignore the source address in the IP packet and try to select local address that we prefer for talks with the target host. Such local address is selected by looking for primary IP addresses on all our subnets on the outgoing interface that include the target IP address. If no suitable local address is found we select the first local address we have on the outgoing interface or on all other interfaces, with the hope we will receive reply for our request and even sometimes no matter the source IP address we announce.

    The max value from conf/{all,interface}/arp_announce is used.

    Increasing the restriction level gives more chance for receiving answer from the resolved target while decreasing the level announces more valid sender’s information.
    arp_ignore - INTEGER
    : Define different modes for sending replies in response to received ARP requests that resolve local target IP addresses:

    - 0 - (default): reply for any local target IP address, configured on any interface
    - 1 - reply only if the target IP address is local address configured on the incoming interface
    - 2 - reply only if the target IP address is local address configured on the incoming interface and both with the sender’s IP address are part from same subnet on this interface
    - 3 - do not reply for local addresses configured with scope host, only resolutions for global and link addresses are replied
    - 4-7 - reserved
    - 8 - do not reply for all local addresses

    The max value from conf/{all,interface}/arp_ignore is used when ARP request is received on the {interface}
    arp_notify - BOOLEAN
    : Define mode for notification of address and device changes.

    > 0
    >
    > (default): do nothing
    >
    > 1
    >
    > Generate gratuitous arp requests when device is brought up or hardware address changes.
    arp_accept - INTEGER
    : Define behavior for accepting gratuitous ARP (garp) frames from devices that are not already present in the ARP table:

    - 0 - don’t create new entries in the ARP table
    - 1 - create new entries in the ARP table
    - 2 - create new entries only if the source IP address is in the same subnet as an address configured on the interface that received the garp message.

    Both replies and requests type gratuitous arp will trigger the ARP table to be updated, if this setting is on.

    If the ARP table already contains the IP address of the gratuitous arp frame, the arp table will be updated regardless if this setting is on or off.
    arp_evict_nocarrier - BOOLEAN

    ...

    drop_gratuitous_arp - BOOLEAN
    : Drop all gratuitous ARP frames, for example if there’s a known good ARP proxy on the network and such frames need not be used (or in the case of 802.11, must not be used to prevent attacks.)

    Possible values:

    - 0 (disabled)
    - 1 (enabled)

    Default: 0 (disabled)

    ...

    `conf/all/*`:
    : Change all the interface-specific settings.

    ---

    Title: net/ipv4/Kconfig
    URL: https://github.com/torvalds/linux/blob/master/net/ipv4/Kconfig
    Published: N/A
    Author: N/A
    Highlights:
    config IP_ADVANCED_ROUTER
     bool "IP: advanced router"
     help
     If you intend to run your Linux box mostly as a router, i.e. as a
     computer that forwards and redistributes network packets, say Y; you
     will then be presented with several options that allow more precise
     control about the routing process.

     The answer to this question won't directly affect the kernel:
     answering N will just cause the configurator to skip all the
     questions about advanced routing.

     Note that your box can only act as a router if you enable IP
     forwarding in your kernel; you can do that by saying Y to "/proc
     file system support" and "Sysctl support" below and executing the
     line

     echo "1" > /proc/sys/net/ipv4/ip_forward

     at boot time after the /proc file system has been mounted.

     If you turn on IP forwarding, you should consider the rp_filter, which
     automatically rejects incoming packets if the routing table entry
     for their source address doesn't match the network interface they're
     arriving on. This has security advantages because it prevents the
     so-called IP spoofing, however it can pose problems if you use
     asymmetric routing (packets from you to a host take a different path
     than packets from that host to you) or if you operate a non-routing
     host which has several IP addresses on different interfaces. To turn
     rp_filter on use:

     echo 1 > /proc/sys/net/ipv4/conf/ /rp_filter
     or
     echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter

     Note that some distributions enable it in startup scripts.
     For details about rp_filter strict and loose mode read
    .

     If unsure, say N here.

    ---

    Title: netdev - [PATCH net] Documentation: networking: ip-sysctl: Document src_valid_mark sysctl
    URL: https://lists.openwall.net/netdev/2021/02/09/29
    Published: 2021-02-09T00:00:00.000Z
    Author: N/A
    Highlights:
    Message-ID: <1396.1612834621@famine>
    Date:   Mon, 08 Feb ... 17:37:01 -0800
    ...
    _mark sysctl, which was added
    in commit 28f6aeea3f12 ("net: restore
    ...
    1 - Allows you to have multiple network interfaces on the same

    ---

    Title: Routed Subnets, rp_filter and arp_ignore - Simon Mott
    URL: https://www.simonmott.co.uk/2016/09/routed-subnet-rp_filter-arp_ignore/
    Published: 2016-09-23T00:00:00.000Z
    Author: Simon
    Highlights:
    . My server’s default route (0.0.0.0) is out via NIC1, so traffic that ultimately comes from ... but rp_filter would match against NIC1 - thus the check fails and the packet is dropped as invalid.
    ...
    , I either want to set rp_filter to be either 0 (NONE)

    ---

    Title: IP-Sysctl variables - Braincoke’s log
    URL: https://blog.braincoke.fr/network/ip-sysctl-variables/
    Published: 2017-05-13T20:43:03.000Z
    Author: Braincoke
    Highlights:
    ARP table
    - 1 - create new entries in the ARP table

    Both replies and requests type gratuitous arp will trigger the ARP table to be updated, if this setting ... on.

    If the ARP table already contains the IP address of the gratuitous arp frame, the arp

## Activity

    $ rtk read system_files/desktop/usr/lib/modprobe.d/halcyon-blocklist.conf; rtk read system_files/desktop/usr/share/polkit-1/rules.d/20-privileged-ruser.rules system_files/desktop/usr/share/polkit-1/actions/org.bazzite.privileged.user.setup.policy; rtk read system_files/desktop/usr/bin/halcyon-security-posture system_files/desktop/usr/bin/halcyon-mor; rtk read system_files/desktop/usr/lib/tuned/profiles/balanced-bazzite/tuned.conf system_files/desktop/usr/lib/tuned/profiles/throughput-performance-bazzite/tuned.conf; rtk read build_files/packages/install-security; sed -n '506,540p' packages.json
    # SPDX-License-Identifier: CC0-1.0
    # Halcyon module blocklist, curated from secureblue's
    # files/system/usr/lib/modprobe.d/secureblue.conf (Apache-2.0).
    #
    # secureblue modules intentionally NOT blocked here, and why:
    # - bluetooth/btusb, joystick*/joydev/gamecon family: this image ships gaming
    #   and controller support; blocking them breaks hardware.
    # - thunderbolt*: Thunderbolt docks and eGPUs are legitimate on this desktop.
    # - cdrom/sr_mod/udf: optical drives remain supported, and DVD/Blu-ray data
    #   discs (and some large USB media) are UDF.
    # - cifs/nfs family (sunrpc, lockd, grace, rpcsec_gss_krb5, auth_rpcgss,
    #   nfs*, cifs_md4 excluded below): network file shares stay available; cifs.ko
    #   depends on cifs_md4, so blocking it silently breaks SMB mounts. The ksmbd
    #   in-kernel SMB *server* remains blocked.
    # - gnss (the core module): the Intel ice NIC driver and the WWAN stack depend
    #   on it, so only the leaf GNSS receiver drivers below are blocked.
    # - squashfs: kept for container/flatpak edge cases.
    # - dccp/sctp/rds/tipc: already blocked in halcyon-hardening.conf.
    #
    # Dependency check: no module that remains loadable may depend on a blocked
    # one unless the whole family is intentionally gone (DVB, NFC, RDMA, ATM,
    # FireWire, gameport/parport devices). Re-run that check against modules.dep
    # when adding entries.

    # unused network protocols
    install xt_dccp /bin/false
    install xt_sctp /bin/false
    install sctp_diag /bin/false
    install rds_rdma /bin/false
    install rds_tcp /bin/false
    install tipc_diag /bin/false
    install n-hdlc /bin/false
    install hdlcdrv /bin/false
    install ax25 /bin/false
    install netrom /bin/false
    install x25 /bin/false
    install rose /bin/false
    install decnet /bin/false
    install econet /bin/false
    install af_802154 /bin/false
    install ipx /bin/false
    install appletalk /bin/false
    install psnap /bin/false
    install p8023 /bin/false
    install p8022 /bin/false
    install atm /bin/false
    install usbatm /bin/false
    install xusbatm /bin/false
    install pppoatm /bin/false
    install atmtcp /bin/false
    install mctp-serial /bin/false
    install mctp-usb /bin/false
    install mctp-i3c /bin/false
    install batman-adv /bin/false

    # firewire (legacy DMA-capable bus)
    install firewire-core /bin/false
    install firewire_core /bin/false
    install firewire-ohci /bin/false
    install firewire_ohci /bin/false
    install firewire_sbp2 /bin/false
    install firewire-sbp2 /bin/false
    install firewire-net /bin/false
    install ohci1394 /bin/false
    install sbp2 /bin/false
    install dv1394 /bin/false
    install raw1394 /bin/false
    install video1394 /bin/false
    # https://github.com/torvalds/linux/blob/master/drivers/firewire/nosy.c
    install nosy /bin/false
    # https://github.com/torvalds/linux/blob/master/drivers/media/firewire/firedtv-dvb.c
    install firedtv /bin/false

    # unused filesystems (cluster/legacy/network servers)
    install cramfs /bin/false
    install freevxfs /bin/false
    install jffs2 /bin/false
    install hfs /bin/false
    install hfsplus /bin/false
    install gfs2 /bin/false
    install reiserfs /bin/false
    install kafs /bin/false
    install orangefs /bin/false
    install 9p /bin/false
    install 9pnet /bin/false
    install 9pnet_fd /bin/false
    install 9pnet_rdma /bin/false
    install 9pnet_usbg /bin/false
    install 9pnet_virtio /bin/false
    install 9pnet_xen /bin/false
    install adfs /bin/false
    install affs /bin/false
    install afs /bin/false
    install befs /bin/false
    install ceph /bin/false
    install coda /bin/false
    install ecryptfs /bin/false
    install jfs /bin/false
    install minix /bin/false
    install nilfs2 /bin/false
    install ocfs2 /bin/false
    install romfs /bin/false
    install ubifs /bin/false
    install zonefs /bin/false
    install sysv /bin/false
    install ufs /bin/false
    # https://documentation.suse.com/sle-ha/12-SP5/html/SLE-HA-all/cha-ha-storage-dlm.html
    install dlm /bin/false
    install ocfs2_dlm /bin/false
    install ocfs2_dlmfs /bin/false
    install ocfs2_nodemanager /bin/false
    install ocfs2_stackglue /bin/false
    install ocfs2_stack_o2cb /bin/false
    install ocfs2_stack_user /bin/false
    # in-kernel SMB server; the cifs client stays available
    install ksmbd /bin/false

    # disable GNSS receiver drivers (the gnss core stays: ice and wwan need it)
    install gnss-mtk /bin/false
    install gnss-serial /bin/false
    install gnss-sirf /bin/false
    install gnss-usb /bin/false
    install gnss-ubx /bin/false

    # block loading ath_pci (legacy madwifi)
    install ath_pci /bin/false

    # x86 android tablet support
    # https://github.com/torvalds/linux/tree/master/drivers/platform/x86/x86-android-tablets
    install x86-android-tablets /bin/false

    # RxRPC network protocol
    # https://www.kernel.org/doc/html/latest/networking/rxrpc.html
    install rxrpc /bin/false

    # esp4 and esp6 provide support for Encapsulating Security Payload (IPSec)
    install esp4 /bin/false
    install esp4_offload /bin/false
    install esp6 /bin/false
    install esp6_offload /bin/false

    # remaining IPSec functionality and its userspace interfaces
    install ip_vti /bin/false
    install ip6_vti /bin/false
    install nft_xfrm /bin/false
    install xfrm4_tunnel /bin/false
    install xfrm6_tunnel /bin/false
    install xfrm_algo /bin/false
    install xfrm_interface /bin/false
    install xfrm_ipcomp /bin/false
    install xfrm_iptfs /bin/false
    install xfrm_user /bin/false
    install ah4 /bin/false
    install ah6 /bin/false
    install ipcomp /bin/false
    install ipcomp6 /bin/false
    install af_key /bin/false

    # disable l2tp (depends on ipsec)
    install l2tp_core /bin/false
    install l2tp_debugfs /bin/false
    install l2tp_eth /bin/false
    install l2tp_ip /bin/false
    install l2tp_ip6 /bin/false
    install l2tp_netlink /bin/false
    install l2tp_ppp /bin/false
    install xt_l2tp /bin/false

    # legacy interfaces
    # https://en.wikipedia.org/wiki/Parallel_port
    install parport /bin/false
    install parport_cs /bin/false
    install parport_pc /bin/false
    install parport_serial /bin/false
    install pps_parport /bin/false
    install i2c-parport /bin/false
    # https://github.com/torvalds/linux/blob/master/drivers/char/ppdev.c
    install ppdev /bin/false
    # https://github.com/torvalds/linux/blob/master/drivers/char/lp.c
    install lp /bin/false
    # https://en.wikipedia.org/wiki/Game_port
    install gameport /bin/false
    # https://en.wikipedia.org/wiki/Floppy_disk
    install floppy /bin/false

    # kernel debugging / development modules
    # https://linux.die.net/man/8/mce-inject
    install mce-inject /bin/false
    # https://github.com/torvalds/linux/blob/master/mm/hwpoison-inject.c
    install hwpoison-inject /bin/false
    # https://github.com/torvalds/linux/blob/master/drivers/pci/pcie/aer_inject.c
    install aer_inject /bin/false
    # https://github.com/torvalds/linux/blob/master/drivers/scsi/scsi_debug.c
    install scsi_debug /bin/false
    # https://github.com/torvalds/linux/blob/master/drivers/usb/serial/usb_debug.c
    install usb_debug /bin/false
    # https://github.com/torvalds/linux/blob/master/kernel/trace/ring_buffer_benchmark.c
    install ring_buffer_benchmark /bin/false
    # https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/vkms/vkms_drv.c
    install vkms /bin/false
    install vsock_diag /bin/false
    install xsk_diag /bin/false
    install visl /bin/false
    install vim2m /bin/false
    install vimc /bin/false
    install vivid /bin/false
    install dummy_hcd /bin/false
    install nandsim /bin/false
    install mtdram /bin/false

    # kernel message logging over UDP
    # https://www.kernel.org/doc/Documentation/networking/netconsole.txt
    install netconsole /bin/false

    # automotive/industrial and CAN bus
    install dp83tg720 /bin/false
    install marvell-88q2xxx /bin/false
    install marvell-88x2222 /bin/false
    install microchip_t1s /bin/false
    install max9271 /bin/false
    install can /bin/false
    install can327 /bin/false
    install can-bcm /bin/false
    install can-gw /bin/false
    install can-isotp /bin/false
    install can-j1939 /bin/false
    install can-raw /bin/false
    install ctucanfd /bin/false
    install ctucanfd_pci /bin/false
    install ifi_canfd /bin/false
    install m_can /bin/false
    install m_can_pci /bin/false
    install slcan /bin/false
    install vcan /bin/false
    install vxcan /bin/false
    install peak_usb /bin/false
    install peak_pciefd_main /bin/false
    install kvaser_usb /bin/false
    install gs_usb /bin/false
    # https://en.wikipedia.org/wiki/6LoWPAN
    install 6lowpan /bin/false
    install bluetooth_6lowpan /bin/false
    install ieee802154_6lowpan /bin/false

    # RDMA https://wiki.debian.org/RDMA
    install smc /bin/false
    install smc_diag /bin/false
    install erdma /bin/false
    install ionic_rdma /bin/false
    install irdma /bin/false
    install nvme-rdma /bin/false
    install nvmet-rdma /bin/false
    install ocrdma /bin/false
    install rdma_cm /bin/false
    install rdma_rxe /bin/false
    install rdma_ucm /bin/false
    install rdmavt /bin/false
    install rpcrdma /bin/false
    install vmw_pvrdma /bin/false

    # GPIB
    install gpib_common /bin/false
    install agilent_82350b /bin/false
    install agilent_82357a /bin/false
    install cb7210 /bin/false
    install cec_gpib /bin/false
    install ines_gpib /bin/false
    install lpvo_usb_gpib /bin/false
    install nec7210 /bin/false
    install ni_usb_gpib /bin/false
    install tnt4882 /bin/false

    # DVB and TV receivers (absent hardware)
    install dvb-as102 /bin/false
    install dvb-bt8xx /bin/false
    install dst_ca /bin/false
    install dst /bin/false
    install dvb-core /bin/false
    install dvb-pll /bin/false
    install dvb-ttusb-budget /bin/false
    install dvb-usb /bin/false
    install dvb_usb_v2 /bin/false
    install ttusb_dec /bin/false
    install ttusbdecfe /bin/false
    install smsusb /bin/false
    install smsdvb /bin/false
    install smsmdtv /bin/false
    install smssdio /bin/false
    install b2c2-flexcop /bin/false
    install b2c2-flexcop-pci /bin/false
    install b2c2-flexcop-usb /bin/false
    install au0828 /bin/false
    install mxb /bin/false
    install saa7164 /bin/false
    install saa6588 /bin/false
    install smipcie /bin/false
    install pluto2 /bin/false
    install ngene /bin/false
    install mantis /bin/false
    install mantis_core /bin/false
    install hopper /bin/false
    install ivtv /bin/false
    install ivtvfb /bin/false
    install netup-unidvb /bin/false
    install bttv /bin/false
    install bt819 /bin/false
    install bt856 /bin/false
    install bt866 /bin/false
    install bt878 /bin/false
    install snd-bt87x /bin/false
    install hdpvr /bin/false
    install pvrusb2 /bin/false
    install saa7146 /bin/false
    install saa7146_vv /bin/false
    install hexium_gemini /bin/false
    install hexium_orion /bin/false
    install go7007 /bin/false
    install go7007-loader /bin/false
    install go7007-usb /bin/false
    install earth-pt1 /bin/false
    install earth-pt3 /bin/false
    install ddbridge /bin/false
    install ddbridge-dummy-fe /bin/false
    install cx23885 /bin/false
    install altera-ci /bin/false
    install cx18 /bin/false
    install cx18-alsa /bin/false
    install budget /bin/false
    install budget-av /bin/false
    install budget-ci /bin/false
    install budget-core /bin/false
    install saa7134 /bin/false
    install saa7134-alsa /bin/false
    install saa7134-dvb /bin/false
    install saa7134-empress /bin/false
    install saa7134-go7007 /bin/false
    install cx231xx /bin/false
    install cx231xx-alsa /bin/false
    install cx231xx-dvb /bin/false
    install cx88-alsa /bin/false
    install cx88-blackbird /bin/false
    install cx88-dvb /bin/false
    install cx88-vp3054-i2c /bin/false
    install cx88xx /bin/false
    install cx8800 /bin/false
    install cx8802 /bin/false
    install em28xx /bin/false
    install em28xx-alsa /bin/false
    install em28xx-dvb /bin/false
    install em28xx-rc /bin/false
    install em28xx-v4l /bin/false

    # NFC stack
    # https://docs.kernel.org/networking/nfc.html
    install nfc /bin/false

    # radio tuners
    install dsbr100 /bin/false
    install radio-keene /bin/false
    install radio-ma901 /bin/false
    install radio-maxiradio /bin/false
    install radio-mr800 /bin/false
    install radio-shark /bin/false
    install shark2 /bin/false
    install radio-si470x-common /bin/false
    install radio-si470x-i2c /bin/false
    install radio-si470x-usb /bin/false
    install radio-tea5764 /bin/false
    install saa7706h /bin/false
    // Halcyon: user-setup.service runs `pkexec /usr/bin/privileged-user-setup $USER`
    // at login, before a polkit agent is up, so this action is pre-authorised for
    // wheel. Only for the caller's own account: pkexec's command_line must be the
    // helper plus the subject's user name and nothing else. Any other invocation
    // falls back to the action default (auth_admin). The unit runs outside a
    // logind session, so subject.local/active cannot be required here.
    polkit.addRule(function(action, subject) {
        if (action.id == "org.bazzite.policykit.privileged.user.setup" &&
            subject.isInGroup("wheel") &&
            action.lookup("command_line") == "/usr/bin/privileged-user-setup " + subject.user) {
            return polkit.Result.YES;
        }
    });
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
     "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
    <policyconfig>

      <vendor>Bazzite</vendor>
      <vendor_url>https://github.com/ublue-os/bazzite/</vendor_url>

      <action id="org.bazzite.policykit.privileged.user.setup">
        <description>Allows certain user configuration tasks to run as root</description>
        <icon_name>package-x-generic</icon_name>
        <defaults>
          <allow_any>no</allow_any>
          <allow_inactive>no</allow_inactive>
          <allow_active>auth_admin</allow_active>
        </defaults>
        <annotate key="org.freedesktop.policykit.exec.path">/usr/bin/privileged-user-setup</annotate>
      </action>

    </policyconfig>
    #!/usr/bin/env bash
    # Halcyon security posture, applied at boot (idempotent):
    #
    # 1. Install the shipped SELinux policy modules: the secureblue socket-class
    #    restrictions (Apache-2.0/MIT, https://github.com/secureblue/secureblue),
    #    which deny userspace access to the kernel crypto API (AF_ALG), IPSec,
    #    obscure, and packet-radio sockets; and halcyon_nix_daemon_socket, which
    #    labels the nix-daemon socket directory so that PID 1 may create its
    #    listening socket. These are installed at runtime rather than build time
    #    because the policy store (store-root=/etc/selinux in semanage.conf, with
    #    /var/lib/selinux a symlink to it) is local state that diverges from the
    #    image the first time anything runs semodule, so a module baked in at build
    #    time is not guaranteed to reach an existing deployment. A checksum stamp of
    #    the shipped .cil files and of the installed policy-shipping RPMs makes an
    #    updated image replace the modules it previously installed, and rebuilds the
    #    policy when an RPM-shipped module is added or changed.
    # 2. Keep services that a single-user desktop does not need turned off, even
    #    after package transactions re-enable them.
    set -euo pipefail

    # --- SELinux policy modules -----------------------------------------------
    policy_dir=/usr/share/halcyon/selinux
    policies=(secureblue_socket_utils secureblue_audit_sockets secureblue_deny_alg_sockets secureblue_deny_ipsec_sockets secureblue_deny_obscure_sockets secureblue_deny_packet_radio_sockets halcyon_nix_daemon_socket)
    stamp=/var/lib/halcyon/selinux-socket-policies.sha256

    cil_files=()
    for policy in "${policies[@]}"; do
        cil_files+=("${policy_dir}/${policy}.cil")
    done

    # The stamp covers the shipped .cil files and the set of installed
    # policy-shipping RPMs. A module that an RPM installs (NetworkManager-ssh-selinux,
    # selinux-policy itself) lands in the image's store at build time, but bootc keeps
    # this deployment's locally modified policy.35 and file_contexts, so its rules
    # would never be compiled in here. Including the RPM set makes the next boot after
    # such a change rebuild the policy. rpm-plugin-selinux matches the glob but ships
    # no module, so it is dropped to spare a rebuild on every rpm update. Sorted:
    # rpm -qa output order is not stable.
    want=$( { cat "${cil_files[@]}"; rpm -qa --qf '%{NAME}-%{EVR}\n' 'selinux-policy*' '*-selinux' 2>/dev/null | grep -v '^rpm-plugin-selinux-' | sort || true; } | sha256sum | cut -d' ' -f1)
    have=$(cat "$stamp" 2>/dev/null || true)

    # Capture once: one semodule run instead of one per module, and no pipe for
    # grep -q to close early under pipefail.
    modules=$(semodule -l)
    missing=0
    for policy in "${policies[@]}"; do
        if ! grep -qx -- "$policy" <<<"$modules"; then
            missing=$((missing + 1))
        fi
    done

    if ((missing > 0)) || [[ "$want" != "$have" ]]; then
        echo "halcyon-security-posture: installing SELinux policy modules (${missing} missing, stamp $([[ "$want" == "$have" ]] && echo current || echo stale))"
        # Priority 300: above RPM-shipped policies (200), below local admin ones (400)
        semodule -v -X 300 -i "${cil_files[@]}"
        mkdir -p "$(dirname "$stamp")"
        printf '%s\n' "$want" >"$stamp"
    fi

    # --- Service posture ------------------------------------------------------
    # authselect is 'local' on this image: sssd is not part of authentication.
    systemctl disable \
        sssd.service sssd-kcm.service sssd-kcm.socket \
        ModemManager.service \
        iscsid.service iscsid.socket iscsiuio.service iscsiuio.socket \
        alsa-state.service 2>/dev/null || true
    # passim is D-Bus-activatable; only a mask keeps it from respawning (fwupd
    # degrades gracefully without it).
    systemctl mask passim.service 2>/dev/null || true
    #!/usr/bin/env bash
    # Halcyon: set or clear the TCG MemoryOverwriteRequestControl bit (Lynis
    # CRYP-8006).
    #
    # While the bit is 1, firmware wipes RAM on the next boot, which defeats
    # cold-boot attacks after a crash or power loss. The OS sets it at startup
    # and clears it on a clean shutdown, so normal reboots do not pay for a wipe.
    #
    # Usage: halcyon-mor set|clear
    # HALCYON_MOR_VAR overrides the efivar path (used for testing only).
    set -euo pipefail

    var=${HALCYON_MOR_VAR:-/sys/firmware/efi/efivars/MemoryOverwriteRequestControl-e20939be-32d4-41be-a150-897f85d49829}

    case "${1:-}" in
        set)   value='\x01' ;;
        clear) value='\x00' ;;
        *)     echo "usage: ${0##*/} set|clear" >&2; exit 2 ;;
    esac

    # Absent on BIOS boots and on firmware without MOR support: nothing to do.
    [[ -e "$var" ]] || exit 0

    # efivarfs files are immutable and take the 4-byte attribute header
    # (NV|BS|RT = 7) plus the data in one write().
    chattr -i "$var" 2>/dev/null || true
    printf '\x07\x00\x00\x00%b' "$value" > "$var"
    chattr +i "$var" 2>/dev/null || true
    #
    # tuned configuration
    #

    [main]
    summary = General non-specialized tuned profile with added Bazzite tweaks
    include = balanced

    [script]
    script=${i:PROFILE_DIR}/script.sh
    #
    # tuned configuration
    #

    [main]
    summary = General non-specialized tuned profile with added Bazzite tweaks
    include = throughput-performance

    [script]
    script=${i:PROFILE_DIR}/script.sh
    #!/usr/bin/env bash

    set -Eeuo pipefail

    # Read package list from packages.json
    PACKAGES_JSON="/ctx/packages.json"
    if [[ ! -f "$PACKAGES_JSON" ]]; then
        echo "ERROR: packages.json not found at $PACKAGES_JSON" >&2
        exit 1
    fi

    mapfile -t security_packages < <(jq -r '."security".packages[]' "$PACKAGES_JSON")

    dnf5 --setopt=install_weak_deps=False --setopt='*.skip_if_unavailable=False' -y install "${security_packages[@]}"
      "security": {
        "description": "Security tooling: AIDE file integrity, fail2ban journal backend, rngd entropy daemon, psacct process accounting, sysstat activity collection, audit daemon and plugins, SELinux policy utilities",
        "copr": null,
        "repos": [
          "fedora",
          "updates"
        ],
        "packages": [
          "aide",
          "audispd-plugins",
          "audit",
          "audit-rules",
          "chkrootkit",
          "firewalld",
          "lynis",
          "policycoreutils-devel",
          "policycoreutils-restorecond",
          "psacct",
          "python3-systemd",
          "rkhunter",
          "rng-tools",
          "setools-console",
          "setroubleshoot",
          "sysstat"
        ]
      },
      "kernel": {
        "description": "Kernel and kernel modules from ublue-os akmods images",
        "copr": null,
        "packages": [
          "kernel-core",
          "kernel-devel",
          "kernel-modules",
          "kmod-nct6687d",
          "nct6687d"
    ✓ • 0ms

## Activity

    mcp tool: context7/query-docs({"libraryId":"/websites/networkmanager_dev","query":"NetworkManager DNS systemd-resolved dns-over-tls ipv4.dns-priority negative value VPN split DNS; wifi scan randomization stable-ssid cloned-mac-address"}) · Completed
    ### ipv4 setting

    Source: https://networkmanager.dev/docs/api/latest/nm-settings-dbus.html

    dns-priority | int32 | 0 | DNS servers priority. The relative priority for DNS servers specified by this setting. A lower numerical value is better (higher priority). Negative values have the special effect of excluding other configurations with a greater numerical priority value; so in presence of at least one negative priority, only DNS servers from connections with the lowest priority value will be used. To avoid all DNS leaks, set the priority of the profile that should be used to the most negative value of all active connections profiles. Zero selects a globally configured default value. If the latter is missing or zero too, it defaults to 50 for VPNs (including WireGuard) and 100 for other connections. Note that the priority is to order DNS settings for multiple active connections. It does not disambiguate multiple DNS servers within the same connection profile. When multiple devices have configurations with the same priority, VPNs will be considered first, then devices with the best (lowest metric) default route and then all other devices. When using dns=default, servers with higher priority will be on top of resolv.conf. To prioritize a given server over another one within the same connection, just specify them in the desired order. Note that commonly the resolver tries name servers in /etc/resolv.conf in the order listed, proceeding with the next server in the list on failure. See for example the "rotate" option of the dns-options setting. If there are any negative DNS priorities, then only name servers from the devices with that lowest priority will be considered. When using a DNS resolver that supports Conditional Forwarding or Split DNS (with dns=dnsmasq or dns=systemd-resolved settings), each connection is used to query domains in its search list. The search domains determine which name servers to ask, and the DNS priority is used to prioritize name servers based on the domain. Queries for domains not present in any search list are routed through connections having the '~.' special wildcard domain, which is added automatically to connections with the default route (or can be added manually). When multiple connections specify the same domain, the one with the best priority (lowest numerical value) wins. If a sub domain is configured on another interface it will be accepted regardless the priority, unless parent domain on the other interface has a negative priority, which causes the sub domain to be shadowed. With Split DNS one can avoid undesired DNS leaks by properly configuring DNS priorities and the search domains, so that only name servers of the desired interface are configured.

    --------------------------------

    ### 802-11-wireless setting

    Source: https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html

    `802-11-wireless.cloned-mac-address` |  Alias: cloned-mac If specified, request that the device use this MAC address instead. This is known as MAC cloning or spoofing. Beside explicitly specifying a MAC address, the special values "preserve", "permanent", "random", "stable" and "stable-ssid" are supported. "preserve" means not to touch the MAC address on activation. "permanent" means to use the permanent hardware address of the device. "random" creates a random MAC address on each connect. "stable" creates a hashed MAC address based on connection.stable-id and a machine dependent key. "stable-ssid" creates a hashed MAC address based on the SSID, the same as setting the stable-id to "${NETWORK_SSID}". If unspecified, the value can be overwritten via global defaults, see manual of NetworkManager.conf. If still unspecified, it defaults to "preserve" (older versions of NetworkManager may use a different default value). On D-Bus, this field is expressed as "assigned-mac-address" or the deprecated "cloned-mac-address". Format: MAC address Special values: preserve, permanent, random, stable, stable-ssid

    --------------------------------

    ### connection > Properties

    Source: https://networkmanager.dev/docs/api/latest/settings-connection.html

    `dns-over-tls` | `int32` | `-1` | Whether DNSOverTls (dns-over-tls) is enabled for the connection. DNSOverTls is a technology which uses TLS to encrypt dns traffic. The permitted values are: "yes" (2) use DNSOverTls and disabled fallback, "opportunistic" (1) use DNSOverTls but allow fallback to unencrypted resolution, "no" (0) don't ever use DNSOverTls. If unspecified "default" depends on the plugin used. Systemd-resolved uses global setting. This feature requires a plugin which supports DNSOverTls. Otherwise, the setting has no effect. One such plugin is dns-systemd-resolved.

    --------------------------------

    ### main section > dns

    Source: https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html

    `dns` |  Set the DNS processing mode. If the key is unspecified, `default` is used, unless `/etc/resolv.conf` is a symlink to `/run/systemd/resolve/stub-resolv.conf`, `/run/systemd/resolve/resolv.conf`, `/lib/systemd/resolv.conf` or `/usr/lib/systemd/resolv.conf`. In that case, `systemd-resolved` is chosen automatically.  `default`: NetworkManager will update `/etc/resolv.conf` to reflect the nameservers provided by currently active connections. The `rc-manager` setting (below) controls how this is done. `dnsmasq`: NetworkManager will run dnsmasq as a local caching nameserver, using "Conditional Forwarding" if you are connected to a VPN, and then update `resolv.conf` to point to the local nameserver. It is possible to pass custom options to the dnsmasq instance by adding them to files in the "`/etc/NetworkManager/dnsmasq.d/`" directory. Note that when multiple upstream servers are available, dnsmasq will initially contact them in parallel and then use the fastest to respond, probing again other servers after some time. This behavior can be modified passing the 'all-servers' or 'strict-order' options to dnsmasq (see the manual page for more details). `systemd-resolved`: NetworkManager will push the DNS configuration to systemd-resolved `dnsconfd`: NetworkManager will push the DNS configuration to dnsconfd and by default set ipvX.routed-dns to yes, so servers are contacted through right interfaces. `none`: NetworkManager will not modify resolv.conf. This implies `rc-manager` `unmanaged` Note that the plugins `dnsmasq`,`systemd-resolved` and `dnsconfd` are caching local nameservers. Hence, when NetworkManager writes `/run/NetworkManager/resolv.conf` and `/etc/resolv.conf` (according to `rc-manager` setting below), the name server there will be localhost only. NetworkManager also writes a file `/run/NetworkManager/no-stub-resolv.conf` that contains the original name servers pushed to the DNS plugin. When using `dnsmasq`,`systemd-resolved` and `dnsconfd` per-connection added dns servers will always be queried using the device the connection has been activated on.

    --------------------------------

    ### nm_setting_connection_get_dns_over_tls

    Source: https://networkmanager.dev/docs/libnm/latest/NMSettingConnection.html

    Returns the dns-over-tls property of the setting.

    ```APIDOC
    ## nm_setting_connection_get_dns_over_tls

    ### Description
    Returns the "dns-over-tls" property of the setting.

    ### Method
    NMSettingConnectionDnsOverTls nm_setting_connection_get_dns_over_tls(NMSettingConnection *setting)

    ### Parameters
    - **setting** (NMSettingConnection *) - Required - The NMSettingConnection.

    ### Returns
    NMSettingConnectionDnsOverTls - The dns-over-tls property value.

    ### Since
    1.34
    ```

## Activity

    $ sed -n '1,150p' system_files/desktop/usr/bin/privileged-user-setup; rtk read system_files/desktop/usr/lib/systemd/system/halcyon-aide-init.service system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.service system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.timer; rg --files system_files | rtk rg '(aide|uupd|selinux/config|cups|sshd|sudo|nix.conf|flatpak|browser)'; sed -n '1,130p' system_files/overrides/etc/aide.conf; sed -n '226,267p' Containerfile; sed -n '310,365p' Containerfile; rtk rg -n 'verify|cosign|policy|signedBy|insecure|sigstore' just_scripts/verify-upstream-images README.md system_files/overrides/etc/containers/policy.json
    sed: can't read system_files/desktop/usr/bin/privileged-user-setup: No such file or directory
    [Unit]
    Description=Halcyon: create the AIDE baseline database
    # tmpfiles creates /var/lib/aide; run the baseline once that exists.
    After=systemd-tmpfiles-setup.service
    ConditionPathExists=!/var/lib/aide/aide.db.gz

    [Service]
    Type=oneshot
    Nice=19
    IOSchedulingClass=idle
    ExecStart=/usr/bin/aide --init
    ExecStart=/usr/bin/mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

    [Install]
    WantedBy=multi-user.target
    [Unit]
    Description=Halcyon: check file integrity against the AIDE baseline
    After=local-fs.target
    # Nothing to compare against until halcyon-aide-init.service has run.
    ConditionPathExists=/var/lib/aide/aide.db.gz

    [Service]
    Type=oneshot
    Nice=19
    IOSchedulingClass=idle
    ExecStart=/usr/bin/aide --check
    [Unit]
    Description=Halcyon: weekly AIDE integrity check

    [Timer]
    OnCalendar=weekly
    RandomizedDelaySec=1h
    Persistent=true

    [Install]
    WantedBy=timers.target
    system_files/overrides/etc/ssh/sshd_config.d/10-halcyon-hardening.conf
    system_files/overrides/etc/aide.conf
    system_files/desktop/etc/uupd/config.json
    system_files/desktop/usr/lib/user-tmpfiles.d/halcyon-nix.conf
    system_files/nvidia/usr/lib/systemd/system/nvidia-flatpak-runtime-sync.service
    system_files/desktop/etc/fail2ban/jail.d/10-halcyon-sshd.conf
    system_files/desktop/etc/flatpak/remotes.d/flathub.flatpakrepo
    system_files/desktop/usr/lib/tmpfiles.d/nix.conf
    system_files/desktop/etc/nix/nix.conf
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-init.service
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.timer
    system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.service
    # Halcyon AIDE configuration (Lynis FINT-4350), scoped for a bootc system.
    #
    # /usr is immutable and delivered as checksummed ostree content, and /boot
    # changes on every kernel update, so both are intentionally excluded from the
    # baseline to keep weekly checks actionable. /etc and /root are the mutable
    # paths worth monitoring. The database lives on /var and is created by
    # halcyon-aide-init.service on first boot; re-baseline with `ujust aide-rebaseline`.
    database_in  = file:/var/lib/aide/aide.db.gz
    database_out = file:/var/lib/aide/aide.db.new.gz
    database_new = file:/var/lib/aide/aide.db.new.gz
    gzip_dbout   = yes
    report_url   = stdout

    PERMS   = p+i+n+u+g
    CONTENT = p+i+n+u+g+s+m+c+sha512

    /etc   CONTENT
    /root  CONTENT

    # Kernel-managed mount table symlink; contents change with every boot.
    !/etc/mtab
    # Install security tooling: AIDE (file integrity), python3-systemd (fail2ban
    # journal backend).
    RUN --mount=type=cache,dst=/var/cache \
        --mount=type=cache,dst=/var/log \
        --mount=type=bind,from=ctx,source=/,target=/ctx \
        --mount=type=tmpfs,dst=/tmp \
        /ctx/packages/install-security && \
        /ctx/finalization/verify security && \
        /ctx/shared/cleanup

    # Cleanup & Finalize
    # Copy final system file overrides into root
    COPY system_files/overrides/ /

    # Apply shared desktop defaults after packages and overlays are present. The CLI/Python installers
    # disable their own COPRs; system policy below disables the remaining build repositories after the
    # NVIDIA package transaction. Metadata, initramfs, and account finalization run once, after the
    # NVIDIA section, so that pass includes the NVIDIA modules and dracut config.
    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        rm -f /etc/profile.d/toolbox.sh && \
        /ctx/system/configure-desktop-integration && \
        rm -f /usr/lib/systemd/system/service.d/50-keep-warm.conf && \
        /ctx/finalization/verify desktop-integration

    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/just/import-bazzite-justfiles && \
        /ctx/finalization/verify justfiles

    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/system/configure-system-services && \
        /ctx/finalization/verify services

    # Apply the Lynis-audit hardening: cron permissions, pam_faillock activation,
    # service posture, and the group/shadow consistency gate.
    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/system/configure-security-hardening && \
        /ctx/finalization/verify security-hardening

    # Show the GRUB menu long enough to pick a deployment or edit kernel arguments.
    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/system/configure-grub && \
        /ctx/finalization/verify grub
        --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/system/configure-system-policy && \
        /ctx/finalization/verify system-policy

    # Cleanup & Finalize
    RUN --mount=type=cache,dst=/var/cache \
        --mount=type=cache,dst=/var/log \
        --mount=type=bind,from=ctx,source=/,target=/ctx \
        --mount=type=tmpfs,dst=/tmp \
        /ctx/nvidia/finalize-nvidia && \
        /ctx/finalization/verify nvidia-finalize

    # Generate the privileged-binary audit rules after the last package transaction
    # (the NVIDIA stage adds the setuid /usr/bin/nvidia-modprobe). `verify final`
    # checks the result.
    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/system/generate-audit-privileged-rules

    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/finalization/image-info && \
        /ctx/finalization/verify image-info

    RUN --mount=type=cache,dst=/var/cache \
        --mount=type=cache,dst=/var/log \
        --mount=type=bind,from=ctx,source=/,target=/ctx \
        --mount=type=tmpfs,dst=/tmp \
        /ctx/kernel/build-initramfs && \
        /ctx/finalization/verify initramfs

    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        --mount=type=tmpfs,dst=/tmp \
        /ctx/finalization/finalize && \
        rm -rf \
            /etc/.pwd.lock \
            /etc/passwd- \
            /etc/group- \
            /etc/shadow- \
            /etc/gshadow- \
            /etc/subuid- \
            /etc/subgid- && \
        /ctx/finalization/verify finalize

    # Verify the published image before the final lint gate.
    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/finalization/verify final

    RUN --mount=type=tmpfs,target=/run --network=none \
        sh -c 'rm -rf "$(readlink -f /usr/local)/bin/dnf5" && rmdir "$(readlink -f /usr/local)/bin" 2>/dev/null; bootc container lint'
    rg: system_files/overrides/etc/containers/policy.json: No such file or directory (os error 2)
    32 matches in 2 files:

    README.md:14:| **Signing** | cosign; public key [`cosign.pub`](cosign.pub) |
    README.md:21:2. [Install: verify and switch](#install-verify-and-switch)
    README.md:38:- **Signatures are not enforced by default.** Verify before installing; see [...
    README.md:41:## Install: verify and switch
    README.md:47:command -v cosign skopeo curl openssl jq
    README.md:48:cosign version   # v3.1.3+
    README.md:51:curl -fsSLO https://raw.githubusercontent.com/halcyon-linux/base-image/contai...
    README.md:52:openssl pkey -pubin -in cosign.pub -outform DER | sha256sum
    README.md:60:cosign verify --key cosign.pub "$IMAGE@$DIGEST"
    README.md:73:`bootc`/`rpm-ostree` accept unsigned images by default. Install the key and a...
    README.md:76:sudo install -Dm0644 cosign.pub /etc/pki/containers/halcyon-linux.pub
    README.md:80:use-sigstore-attachments: true
    README.md:83:"type": "sigstoreSigned",
    README.md:86:}]' /etc/containers/policy.json | sudo tee /etc/containers/policy.json >/dev/...
    README.md:137:Failed-access rules cover both x86 ABIs. Audit failures log rather than panic...
    README.md:145:After boot, verify the effective configuration, not only the image defaults:
    README.md:176:`just build` resolves the akmods tag (newest that ships `nct6687d`), cosign-v...
    README.md:214:`build_files/finalization/verify <stage>` runs after each build stage; `bootc...
    README.md:219:- `cosign.key` / `*.key` git-ignored and excluded from build contexts; signin...
    README.md:220:- Upstream images cosign-verified (`build_files/keys/ublue-os.pub`) and consu...
    README.md:224:Open items: `cosign.pub` vs CI `SIGNING_SECRET` unconfirmed (A-002); runtime ...
    README.md:228:- Podman-only tooling (CI also uses buildah, skopeo, cosign). `docker://` is ...
    README.md:241:cosign.pub      # image signature verification key
    README.md:245:finalization/ # finalize, image-info, verify
    README.md:250:keys/         # vendored ublue cosign key, Terra RPM key
      +2 more in README.md
    just_scripts/verify-upstream-images:2:# Verify the cosign signature of every upstream input image and print the
    just_scripts/verify-upstream-images:6:# Usage: verify-upstream-images <fedora-version> <akmods-tag> [brew-ref]
    just_scripts/verify-upstream-images:22:if ! command -v cosign >/dev/null 2>&1; then
    just_scripts/verify-upstream-images:23:echo "ERROR: cosign is required to verify upstream images" >&2
    just_scripts/verify-upstream-images:30:if ! digests=$(cosign verify --key "${key}" "${ref}" 2>/dev/null |
    ✗ (2) • 0ms

## Assistant

I’m using Exa and Context7 to check the networking tradeoffs against upstream documentation. Two gaps stand out so far: the README says image signatures are not enforced by default, and the firewall allows SSH on every connection using the default zone. The image also blocks IPsec/L2TP modules, which limits VPN compatibility.

## Activity

    mcp tool: codex_apps/exa.web_search_exa({"query":"bootc official documentation signature verification containers policy sigstoreSigned ostree remote image updates Secure Boot","numResults":5,"objective":"Find primary bootc documentation for enforced signed image updates and distinguish image signatures from UEFI Secure Boot."}) · Completed
    Title: ostree_ext::container - Rust
    URL: https://bootc.dev/bootc/internals/ostree_ext/container/index.html
    Published: N/A
    Author: N/A
    Highlights:
    ## § APIs bridging OSTree and container images

    This module provides the core infrastructure for bidirectionally mapping between OCI/Docker container images and OSTree repositories. It enables bootable container images to be fetched from registries, stored efficiently, and deployed as ostree commits.

    ### § Overview

    Container images are fundamentally layers of tarballs. This module leverages the `crate::tar` module to import container layers as ostree content, and exports ostree commits back to container images. The key insight is that ostree’s content-addressed object storage maps naturally to OCI layer deduplication.

    When a container image is imported (“pulled”), each layer becomes an ostree commit. These layer commits are then merged into a single “merge commit” that represents the complete filesystem state. This merge commit is what gets deployed as a bootable system.

    ...

    The merge commit (`ostree/container/image/...`) combines all layers into a single filesystem tree. It contains critical metadata in its commit metadata:

    - `ostree.manifest-digest`: The OCI manifest digest (e.g., `sha256:...`)
    - `ostree.manifest`: The complete OCI manifest as JSON
    - `ostree.container.image-config`: The OCI image configuration as JSON

    This metadata enables round-tripping: an imported image can be re-exported with its original manifest structure preserved.

    ### § Import Flow

    The import process (implemented in `store::ImageImporter`) follows these steps:

    1. Manifest fetch: Contact the registry via containers-image-proxy (skopeo) to retrieve the image manifest and configuration.
    2. Layout parsing: Analyze the manifest to identify:

    - The base ostree layer (identified by the `ostree.final-diffid` label)
    - Component/chunk layers (split object sets)
    - Derived layers (non-ostree content)
    3. Layer caching check: For each layer, check if an ostree ref already exists for that digest. Cached layers are skipped, enabling efficient incremental updates.
    4. Layer import: For uncached layers:

    - Fetch the compressed tarball from the registry
    - Decompress and parse the tar stream
    - Import content into ostree (handling xattrs via `bare-split-xattrs` format)
    - Create an ostree commit and write the layer ref
    5. Merge commit creation: Overlay all layers (processing OCI whiteout files) to create a unified filesystem tree. Apply SELinux labeling if needed. Store manifest/config metadata and write the image ref.
    6. Garbage collection: Prune layer refs that are no longer referenced by any image or deployment.

    ...

    ### § Connection to Deployments

    When bootc deploys an image, it creates an ostree deployment whose “origin” file references the container image. The origin contains:

    - The `OstreeImageReference` specifying the image and signature verification method
    - The merge commit checksum

    On subsequent boots, bootc can compare the deployed commit against the registry manifest to detect available updates.

    ### § Signatures

    OSTree supports GPG and ed25519 signatures natively. When fetching container images, signature verification can be configured via `SignatureSource`:

    - `OstreeRemote(name)`: Verify using the named ostree remote’s keyring
    - `ContainerPolicy`: Defer to containers-policy.json (requires explicit allow)
    - `ContainerPolicyAllowInsecure`: Use containers-policy.json defaults (not recommended)

    This library defines a URL-like schema to combine signature verification with image references:

    - `ostree-remote-registry:: ` - Verify via ostree remote
    - `ostree-image-signed:: ` - Use container policy
    - `ostree-unverified-registry: ` - No verification (not recommended)

    Example: `ostree-remote-registry:fedora:quay.io/fedora/fedora-bootc:latest`

    See `OstreeImageReference` for parsing and generating these strings.

    ---

    Title: Security and threat model - bootc
    URL: https://bootc.dev/bootc/bootc-security.7.html
    Published: N/A
    Author: N/A
    Highlights:
    # Security and threat model

    This page describes bootc's trust boundaries and how to configure stronger guarantees than the defaults. If you believe you've found a valid vulnerability, see SECURITY.md for how to report it.

    ## Privileges

    bootc is a binary that is intended to be run with full privileges. It does not expose a service (socket, HTTP endpoint) by default; that's the role of higher level tooling.

    All inputs (CLI arguments, etc) are hence considered fully trusted by default.

    ## Container image verification

    bootc honors the default `/etc/containers/policy.json` when fetching images. The upstream default at the time of this writing does not require signatures for generic images.

    It is not a vulnerability in bootc that signatures are not required by default.

    It is however a very good idea for bootc users to enable signatures for their images.

    ## On-disk integrity vs. pull-time verification

    The default backend is ostree (with a composefs mount), but fsverity is not enabled by default.

    The composefs backend enables fsverity by default if available, but does not verify the composefs image (because there's nothing to verify it against by default).

    The composefs backend with sealed UKIs does verify the composefs mount. With composefs + sealed UKIs, it is a vulnerability if e.g. an attacker can mutate a file in the image store, have that persist across a re-mount without it resulting in an `EIO` error (default for Linux kernel fsverity).

    ---

    Title: Sealed images - bootc
    URL: https://bootc.dev/bootc/building/bootc-sealed-images.7.html
    Published: N/A
    Author: N/A
    Highlights:
    # Sealed images

    ## How Sealed Images Work

    A sealed image is a cryptographically signed and verified bootc image that provides end-to-end integrity protection. This is achieved through:

    - Unified Kernel Images (UKIs): Combining kernel, initramfs, and boot parameters into a single signed binary
    - Composefs integration: Using composefs with fs-verity for content-addressed filesystem verification
    - Secure Boot: Cryptographic signatures on both the UKI and systemd-boot loader

    A sealed image includes:

    1. composefs digest: A SHA-512 hash of the entire root filesystem, computed at build time
    2. Unified Kernel Image (UKI): A single EFI binary containing the kernel, initramfs, and kernel command line with the composefs digest embedded
    3. Secure Boot signature: The UKI is signed with your private key

    At boot time, the composefs digest in the kernel command line (e.g. `composefs.digest=v1-sha512-12: `) is verified against the mounted root filesystem. This creates a chain of trust from firmware to userspace, ensuring the system will only boot if the root filesystem matches exactly what was signed.

    ## Building Sealed Images

    ### Prerequisites

    For sealed images, the container must:

    - Include a kernel and initramfs in `/usr/lib/modules/ /`
    - Have systemd-boot available (and NOT have `bootupd`)
    - Not include a pre-built UKI (the build process generates one)

    Sealed images also require:

    - Secure Boot support in the target system firmware
    - A filesystem with fs-verity support (e.g., ext4, btrfs) for the root partition

    #### Using without Secure Boot

    You can use a sealed UKI without Secure Boot enabled. The composefs and mounting code is fully orthogonal to Secure Boot - the fs-verity digest of the root filesystem and all of its contents will still be validated at runtime, which does provide an increased level of integrity.

    However: nothing validates that root digest itself, meaning any locally running code can replace the UKI (e.g. after a container breakout) and fully control the next boot.

    It is intentional to support booting with Secure Boot disabled, because a valid use case is to temporarily disable it in order to test a change locally on e.g. one machine, then re-enable it later. However at the current time it is not yet streamlined to regenerate the UKI locally.

    This is independent of `--allow-missing-verity`, which instead makes fs-verity on the root filesystem optional.

    ### Build Pattern: Split the Kernel, Then Generate the UKI in a Separate Stage

    Building a sealed image involves three stages: build the rootfs, split the kernel and initramfs out of it, and generate the signed UKI from the split rootfs in a tools stage:

    ...

    # Generate the sealed UKI in a tools stage
    FROM <tools-image> as sealed-uki
    RUN --mount=type=bind,from=split,target=/target \
        --mount=type=bind,from=split,source=/kernel,target=/kernel \
        --mount=type=secret,id=secureboot_key \
        --mount=type=secret,id=secureboot_cert <<EORUN
    set -euo pipefail

    mkdir -p /out
    kver=$(ls /kernel)

    # `bootc container ukify` computes the composefs digest of /target, reads
    # extra kernel arguments from /target/usr/lib/bootc/kargs.d, and invokes the
    # real `ukify` binary with the digest embedded in the cmdline. Everything
    # after `--` is passed straight through to ukify.
    bootc container ukify \
      --rootfs /target \
      --kernel-dir "/kernel/${kver}" \
      -- \
      --output "/out/${kver}.efi" \
      --signtool sbsign \
      --secureboot-private-key /run/secrets/secureboot_key \
      --secureboot-certificate /run/secrets/secureboot_cert
    EORUN

    # Final image: the split rootfs (kernel/initramfs already removed) plus the signed UKI
    FROM split
    COPY --from=sealed-uki /out/*.efi /boot/EFI/Linux/

    ```

    ...

    2.

    ...

    T

    ...

    ### The `bootc container ukify` Command

    ...

    bootc container ukify --rootfs <PATH> [OPTIONS] -- [UKIFY_ARGS...]

    ```

    This is the recommended way to build a UKI for a bootc image. It computes the composefs digest of `--rootfs` (using the lower-level `compute-composefs-digest` primitive described below), reads extra kernel arguments from `/usr/lib/bootc/kargs.d`, and invokes the system `ukify` binary with the resulting cmdline. Anything after `--` is forwarded to `ukify` unchanged (e.g. `--output`, `--signtool`, signing key/cert options).

    ...

    ### Final Image Structure

    The sealed image should have:

    - The signed UKI at `/boot/EFI/Linux/.efi`
    - A signed systemd-boot at `/boot/EFI/BOOT/BOOTX64.EFI` and `/boot/EFI/systemd/systemd-bootx64.efi`
    - The raw `vmlinuz` and `initramfs.img` removed from `/usr/lib/modules/ /` (they're now embedded in the UKI)

    ### External Signing Workflow

    For production environments with dedicated signing infrastructure:

    1. Build unsigned UKI: Compute digest and create an unsigned UKI (omit `--signtool` from ukify)
    2. Sign externally: Take the unsigned UKI to your signing infrastructure
    3. Complete the seal: Inject the signed UKI into the final image

    This workflow is planned for streamlining in future releases (see #1498).

    ---

    Title: ImageSignature in bootc_lib::spec - Rust
    URL: https://bootc.dev/bootc/internals/bootc_lib/spec/enum.ImageSignature.html
    Published: N/A
    Author: N/A
    Highlights:
    ImageSignature in bootc_lib::spec - Rust

    Source

    ```
    pub enum ImageSignature {
        OstreeRemote(String),
        ContainerPolicy,
        Insecure,
    }
    ```

    ## Variants§

    ### OstreeRemote(String)

    Fetches will use the named ostree remote for signature verification of the ostree commit.

    ### ContainerPolicy

    Fetches will defer to the `containers-policy.json`, but we make a best effort to reject `default: insecureAcceptAnything` policy.

    ### Insecure

    No signature verification will be performed

    ---

    Title: man bootc-install-to-filesystem - bootc
    URL: https://bootc.dev/bootc/man/bootc-install-to-filesystem.8.html
    Published: N/A
    Author: N/A
    Highlights:
    # NAME

    bootc-install-to-filesystem - Install to an externally created filesystem structure

    # SYNOPSIS

    bootc install to-filesystem [OPTIONS...] < ROOT_PATH>

    # DESCRIPTION

    Install to an externally created filesystem structure.

    In this variant of installation, the root filesystem alongside any necessary platform partitions (such as the EFI system partition) are prepared and mounted by an external tool or script. The root filesystem is currently expected to be empty by default.

    ...

    --source-imgref= SOURCE_IMGREF

    ```
    Install the system from an explicitly given source

    ```

    --target-transport= TARGET_TRANSPORT

    ```
    The transport; e.g. oci, oci-archive, containers-storage.  Defaults to `registry`

    Default: registry

    ```

    --target-imgref= TARGET_IMGREF

    ```
    Specify the image to fetch for subsequent updates

    ```

    --enforce-container-sigpolicy

    ```
    This is the inverse of the previous `--target-no-signature-verification` (which is now a no-op).  Enabling this option enforces that `containers-policy.json` (see `man containers-policy.json` for the full search path) includes a default policy which requires signatures

    ```

    --run-fetch-check

    ```
    Verify the image can be fetched from the bootc image. Updates may fail when the installation host is authenticated with the registry but the pull secret is not in the bootc image

    ```

    --skip-fetch-check

    ```
    Verify the image can be fetched from the bootc image. Updates may fail when the installation host is authenticated with the registry but the pull secret is not in the bootc image

    ```

    ...

    --composefs-backend

    ```
    Use the composefs backend instead of ostree. This is the default for images with a UKI, and for images with /usr/lib/composefs/setup-root-conf.toml and no ostree prepare-root.conf

    Default: false

    ```

## Activity

    $ sed -n '1,95p' README.md; sed -n '210,226p' README.md; rtk rg -n 'privileged-user-setup|nix-daemon|trusted-users|allowed-users|autologin|sudo|SELINUX|Flatpak|flatpak|ssh|secureboot' build_files/system/configure-desktop-integration build_files/system/configure-system-policy system_files/desktop/etc/nix/nix.conf system_files/desktop/etc/uupd/config.json; rg --files system_files | rtk rg '(user-setup|sddm|selinux|registries|policy.json|cups)'; rtk read system_files/desktop/usr/lib/tuned/profiles/balanced-bazzite/script.sh system_files/desktop/usr/lib/tuned/profiles/throughput-performance-bazzite/script.sh; rtk read system_files/overrides/etc/chrony.conf
    # Halcyon — `alcyone`

    Signed, bootc-native Fedora Atomic image for an NVIDIA gaming workstation. Built from a single `Containerfile` on Universal Blue `base-main`, with the OGC gaming kernel, NVIDIA **open** kernel modules, and a Hyprland + Noctalia desktop.

    | | |
    |---|---|
    | **Image** | `ghcr.io/halcyon-linux/alcyone` (`stable`, `latest`, `YYYYMMDD` — same digest) |
    | **Base** | `ghcr.io/ublue-os/base-main:44` (Fedora 44, x86_64) |
    | **Kernel** | OGC from `ublue-os/akmods`, version-locked |
    | **GPU** | NVIDIA open modules (`akmods-nvidia-open`), multilib |
    | **Extra kmod** | `nct6687d` only (NCT6687 sensors, MSI Z790-P target) |
    | **Desktop** | SDDM + Hyprland + Noctalia |
    | **Updates** | bootc / rpm-ostree, `uupd`, greenboot |
    | **Signing** | cosign; public key [`cosign.pub`](cosign.pub) |
    | **Branch** | `containerfile` (default and release branch) |
    | **License** | Apache-2.0 |

    ## Contents

    1. [Before you switch](#before-you-switch)
    2. [Install: verify and switch](#install-verify-and-switch)
    3. [Using the system](#using-the-system)
    4. [Build locally](#build-locally)
    5. [CI/CD](#cicd)
    6. [Build-time verification gates](#build-time-verification-gates)
    7. [Security and supply-chain](#security-and-supply-chain)
    8. [Design decisions](#design-decisions)
    9. [Repository layout](#repository-layout)
    10. [Contributing](#contributing)
    11. [Upstream and license](#upstream-and-license)

    ## Before you switch

    Personal, opinionated image. Check first:

    - **NVIDIA GPU required.** Open modules support Turing (GTX 16 / RTX 20) and newer only.
    - **Dotfiles are opt-in.** Nothing touches `$HOME` unless you run `ujust dotfiles enable`.
    - **Signatures are not enforced by default.** Verify before installing; see [Install: verify and switch](#install-verify-and-switch).
    - **No installer.** No ISOs or disk images. Install any bootc-capable Fedora Atomic system (Silverblue, Kinoite, Bazzite, Bluefin, …) and switch, or build a disk image with `bootc-image-builder`.

    ## Install: verify and switch

    Run on the Atomic host you are converting. Verify the signature, then pin to the verified digest.

    ```bash
    # 1. Tools
    command -v cosign skopeo curl openssl jq
    cosign version   # v3.1.3+

    # 2. Public key and fingerprint
    curl -fsSLO https://raw.githubusercontent.com/halcyon-linux/base-image/containerfile/cosign.pub
    openssl pkey -pubin -in cosign.pub -outform DER | sha256sum
    # expected: 9410658270bd845ed529f5f2a2f6a1a62bc5c28a49456b6cc4d97d57b1dca240

    # 3. Resolve tag to digest
    IMAGE=ghcr.io/halcyon-linux/alcyone
    DIGEST=$(skopeo inspect --format '{{.Digest}}' docker://$IMAGE:stable)

    # 4. Verify signature
    cosign verify --key cosign.pub "$IMAGE@$DIGEST"

    # 5. Switch and reboot
    sudo bootc switch "$IMAGE@$DIGEST"
    sudo systemctl reboot
    ```

    You are now pinned to that digest. `bootc upgrade`, `ujust update`, and `uupd` do not move the image until you switch again. To track `:stable`, enforce signature checks first; otherwise re-run steps 3–4 before each switch.

    rpm-ostree without bootc: `sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/halcyon-linux/alcyone:stable` — tag-based, digest not enforced. Prefer bootc.

    ### Enforce signature checks

    `bootc`/`rpm-ostree` accept unsigned images by default. Install the key and add a signature requirement to `/etc/containers/policy.json`:

    ```bash
    sudo install -Dm0644 cosign.pub /etc/pki/containers/halcyon-linux.pub
    sudo tee /etc/containers/registries.d/halcyon-linux.yaml >/dev/null <<'EOF'
    docker:
      ghcr.io/halcyon-linux:
        use-sigstore-attachments: true
    EOF
    sudo jq '.transports.docker["ghcr.io/halcyon-linux/alcyone"] = [{
      "type": "sigstoreSigned",
      "keyPath": "/etc/pki/containers/halcyon-linux.pub",
      "signedIdentity": { "type": "matchRepository" }
    }]' /etc/containers/policy.json | sudo tee /etc/containers/policy.json >/dev/null
    ```

    ## Using the system

    Run `ujust` for the full recipe list. Common:

    | Recipe | Purpose |
    |---|---|
    | `update` / `upgrade` | Update OS image and apps via `uupd` |
    ```

    ## Build-time verification gates

    `build_files/finalization/verify <stage>` runs after each build stage; `bootc container lint` runs last. 31 stage groups plus `packages`. Asserts required RPMs present, forbidden RPMs absent (fish, greetd, auxiliary zsh plugins, handheld packages, `nerd-fonts`, `pinentry-qt`, `nvidia-gpu-firmware`, `amd-gpu-firmware`, `amd-ucode-firmware`), kernel matches `KERNEL_VERSION`, build COPRs disabled after use, Flatpak Flathub-only, baked TeX formats exist, `image-ref` starts with `ostree-image-signed:docker://ghcr.io/`.

    ## Security and supply-chain

    - Images signed by digest; publish/sign guarded to the `containerfile` branch; actions pinned to SHAs; `permissions: {}` at top level.
    - `cosign.key` / `*.key` git-ignored and excluded from build contexts; signing via Actions secret only.
    - Upstream images cosign-verified (`build_files/keys/ublue-os.pub`) and consumed by digest. External files pinned by tag/commit plus sha256 in `build_files/downloads/manifest.tsv`; vendor keys checked against pinned fingerprints; no `--nogpgcheck`.
    - `GITHUB_TOKEN` mounted only in the package-free `downloads` stage.
    - `auditd` on by default with Halcyon rules. Wazuh deliberately not shipped (installs under `/var/ossec`, wiped by `finalize`).

    Open items: `cosign.pub` vs CI `SIGNING_SECRET` unconfirmed (A-002); runtime ujust downloads still mutable (A-008); builds not bit-for-bit reproducible.

    ## Design decisions
    system_files/desktop/etc/nix/nix.conf:6:trusted-users = root @wheel
    system_files/desktop/usr/share/halcyon/selinux/secureblue_socket_utils.cil
    system_files/desktop/usr/share/halcyon/selinux/secureblue_deny_packet_radio_sockets.cil
    system_files/desktop/usr/share/halcyon/selinux/secureblue_deny_obscure_sockets.cil
    system_files/desktop/usr/share/halcyon/selinux/secureblue_deny_ipsec_sockets.cil
    system_files/desktop/usr/share/halcyon/selinux/secureblue_deny_alg_sockets.cil
    system_files/desktop/usr/share/halcyon/selinux/secureblue_audit_sockets.cil
    system_files/desktop/usr/share/halcyon/selinux/halcyon_nix_daemon_socket.cil
    system_files/desktop/usr/lib/systemd/user/user-setup.service
    #!/bin/bash

    . /usr/lib/tuned/functions

    start() {
        [ "$(/usr/bin/systemctl is-enabled scx_loader.service)" = "enabled" ] && /usr/bin/scxctl switch -m auto
        return 0
    }

    stop() {
        return 0
    }

    process $@
    #!/bin/bash

    . /usr/lib/tuned/functions

    start() {
        [ "$(/usr/bin/systemctl is-enabled scx_loader.service)" = "enabled" ] && /usr/bin/scxctl switch -m gaming
        return 0
    }

    stop() {
        [ "$(/usr/bin/systemctl is-enabled scx_loader.service 2>/dev/null)" = "enabled" ] && /usr/bin/scxctl switch -m auto
        return 0
    }

    process $@
    # Halcyon chrony configuration, from secureblue
    # files/system/etc/chrony.conf (Apache-2.0): Network Time Security sources
    # with a quorum of three, no command port, no client logging.
    server 129.6.15.27 iburst
    server time.cloudflare.com iburst nts
    server ntppool1.time.nl iburst nts
    server nts.netnod.se iburst nts
    server ptbtime1.ptb.de iburst nts
    server time.dfm.dk iburst nts
    server time.cifelli.xyz iburst nts
    minsources 3
    authselectmode prefer
    dscp 46
    driftfile /var/lib/chrony/drift
    dumpdir /var/lib/chrony
    ntsdumpdir /var/lib/chrony
    leapseclist /usr/share/zoneinfo/leap-seconds.list
    makestep 1.0 3
    rtconutc
    rtcsync
    cmdport 0
    noclientlog
    ✓ • 0ms

## Activity

    $ rtk read system_files/desktop/etc/nix/nix.conf; sed -n '1,75p' tests/test-security-hardening.sh; sed -n '1,100p' tests/test-audit-lint.sh; rtk rg -n 'curl|wget|https://|git clone' system_files/desktop/usr/share/ublue-os/just/90-security.just build_files/just/import-bazzite-justfiles; rtk read system_files/desktop/usr/share/halcyon/selinux/secureblue_deny_ipsec_sockets.cil; sed -n '1,95p' Containerfile; rtk rg -n 'bpftune|nix|ssh|trusted-users' tests/test-audit-lint.sh build_files/finalization/verify
    # Halcyon Nix daemon configuration
    build-users-group = nixbld
    auto-optimise-store = true
    experimental-features = nix-command flakes
    extra-nix-path = nixpkgs=flake:nixpkgs
    trusted-users = root @wheel
    max-jobs = 4
    cores = 6
    #!/usr/bin/env bash
    # Check authentication and permanent firewall configuration in an isolated Fedora 45 container.
    set -Eeuo pipefail

    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    # Disable container labeling, not host SELinux, to read mounts without relabeling the checkout.
    podman run --rm -i --pull=never --network=none --security-opt label=disable \
        --entrypoint /bin/bash \
        -v "$repo_root/build_files/system/configure-security-hardening:/review/script:ro" \
        -v "$repo_root/system_files/overrides/etc/firewalld/zones/FedoraWorkstation.xml:/etc/firewalld/zones/FedoraWorkstation.xml:ro" \
        -v "$repo_root/system_files/overrides/etc/audit/rules.d:/review/rules:ro" \
        ghcr.io/ublue-os/base-main:45 -Eeuo pipefail -s <<'BASH'
    rpm -q fedora-release authselect firewalld audit audit-rules
    # Run only the authentication/firewall block, not unrelated image installation steps.
    sed -n '/^authselect check/,/^# secureblue-derived/{ /^# secureblue-derived/d; p; }' \
        /review/script > /tmp/check
    test -s /tmp/check
    bash -Eeuo pipefail /tmp/check
    bash -Eeuo pipefail /tmp/check
    test "$(firewall-offline-cmd --get-default-zone)" = FedoraWorkstation
    test "$(firewall-offline-cmd --zone=FedoraWorkstation --list-services)" = dhcpv6-client
    test "$(firewall-offline-cmd --zone=FedoraWorkstation --list-ports)" = 47/tcp
    test "$(firewall-offline-cmd --zone=FedoraWorkstation --get-target)" = default
    test "$(systemctl is-enabled firewalld.service)" = enabled

    authselect() {
        if [[ "$1" == current ]]; then
            echo sssd
        else
            command authselect "$@"
        fi
    }
    export -f authselect
    if bash -Eeuo pipefail /tmp/check; then
        echo 'FAIL: accepted unexpected authentication profile' >&2
        exit 1
    fi
    unset -f authselect
    authselect opt-out
    if bash -Eeuo pipefail /tmp/check; then
        echo 'FAIL: accepted unmanaged PAM configuration' >&2
        exit 1
    fi

    for abi in b32 b64; do
        arch=i386
        [[ "$abi" == b32 ]] || arch=x86_64
        mapfile -t syscalls < <(grep -h "arch=$abi" /review/rules/*.rules |
            sed -n 's/.* -S \([^ ]*\).*/\1/p' | tr , '\n' | sort -u)
        ((${#syscalls[@]} > 0))
        for syscall in "${syscalls[@]}"; do
            ausyscall "$arch" "$syscall" --exact >/dev/null
        done
    done
    echo 'PASS: Fedora 45 authentication, firewall defaults, idempotency, rejection checks, and audit syscall names'
    BASH
    #!/usr/bin/env bash
    # Repo-wide audit and lint verification test.
    # Validates shell script syntax, permissions, JSON schemas, YAML files, and just syntax.

    set -euo pipefail

    failures=0
    not_ok() {
        printf 'FAIL: %s\n' "$*" >&2
        failures=$((failures + 1))
    }

    ok() {
        printf 'OK: %s\n' "$*"
    }

    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    # 1. Check bash syntax for all shell scripts
    while IFS= read -r script; do
        if head -n 1 "$script" | grep -qE '^#!.*(bash|sh)'; then
            if bash -n "$script"; then
                ok "syntax: $script"
            else
                not_ok "syntax error in: $script"
            fi
        fi
    done < <(find "$repo_root/build_files" "$repo_root/just_scripts" "$repo_root/tests" "$repo_root/system_files" -type f)

    # 2. Check executable permissions on build scripts and tooling
    while IFS= read -r script; do
        if [[ -x "$script" ]]; then
            ok "executable: $script"
        else
            not_ok "not executable: $script"
        fi
    done < <(find "$repo_root/build_files" "$repo_root/just_scripts" "$repo_root/tests" -type f -not -path '*/.*' \
        -not -name "*.md" -not -name "*.txt" -not -name "*.tsv" -not -path "$repo_root/build_files/keys/*")

    # Static data (download manifest, vendored keys) must not be executable.
    while IFS= read -r data; do
        not_ok "static data file is executable: $data"
    done < <(find "$repo_root/build_files/keys" "$repo_root/build_files/downloads" -type f \
        \( -name "*.tsv" -o -path "$repo_root/build_files/keys/*" \) -perm /111)

    # 3. Validate packages.json
    if jq . "$repo_root/packages.json" >/dev/null 2>&1; then
        ok "packages.json is valid JSON"
    else
        not_ok "packages.json syntax error"
    fi

    for section in applications base-pkgs cli-tools common-packages fonts gaming ghostty kernel nix noctalia security texlive-packages utils; do
        if jq -e --arg s "$section" 'has($s)' "$repo_root/packages.json" >/dev/null 2>&1; then
            ok "packages.json section exists: $section"
        else
            not_ok "packages.json missing section: $section"
        fi
    done

    if jq -e '."common-packages".packages | index("virtiofsd")' "$repo_root/packages.json" >/dev/null; then
        ok "virtiofsd is installed from common-packages"
    else
        not_ok "common-packages must install virtiofsd"
    fi

    if jq -e '
        .["common-packages"].packages as $common
        | .security.packages as $security
        | ($common | index("setools-console") | not)
          and ($common | index("setroubleshoot") | not)
          and ($common | index("lynis") | not)
          and ($security | index("setools-console") != null)
          and ($security | index("setroubleshoot") != null)
          and ($security | index("lynis") != null)
          and ($common | index("gdu") != null)
          and ($common | index("perl") != null)
          and ($common | index("nautilus") != null)
          and ($common | index("file-roller") != null)
          and ($common | index("ScopeBuddy") | not)
          and ($common | map(select(test("(?i)^thunar$|^thunar-"))) | length == 0)
          and ([.gaming.packages[] | select(. == "dmemcg-booster")] | length == 0)
          and ([.. | strings | select(test("bazzite-multilib|i686"))] | length == 0)
    ' "$repo_root/packages.json" >/dev/null; then
        ok "requested package metadata is consistent"
    else
        not_ok "requested package metadata is inconsistent"
    fi

    if grep -Fq 'reinstall --from-repo=fedora,updates bluez' \
        "$repo_root/build_files/packages/install-common-packages" \
        && grep -Fq "require_rpms_from_repo 'fedora,updates' bluez" \
            "$repo_root/build_files/finalization/verify"; then
        ok "BlueZ is installed and verified from Fedora repos"
    else
        not_ok "BlueZ must be installed and verified from Fedora repos"
    fi

    if ! grep -Eiq 'vscodium|codium' \
        "$repo_root/packages.json" \
    ; SPDX-FileCopyrightText: Copyright 2026 The Secureblue Authors
    ;
    ; SPDX-License-Identifier: Apache-2.0 OR MIT

    ; Denies all userspace processes access to IPSec-related sockets, the userspace
    ; interface to IPSec kernel functionality, which is not needed on most desktop
    ; systems and was recently responsible for several major privilege escalation
    ; exploits.
    ;
    ; See `secureblue_socket_utils.cil` for macro definitions.

    (in secureblue
        (call deny_userspace (key_socket))
        (call deny_userspace (netlink_xfrm_socket)))
    # Build the Hyprland/NVIDIA Fedora Atomic image as one bootable OCI image; bootc and rpm-ostree provide staged updates and rollback.
    # Keep this Containerfile build: multi-stage akmods inputs, bind mounts, and package swaps produce the published alcyone image.
    # Upstream Fedora release number
    ARG FEDORA_VERSION="${FEDORA_VERSION:-45}"

    # Full registry URL to the upstream Universal Blue base image
    ARG BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ublue-os/base-main:${FEDORA_VERSION}}"
    # Kernel modification flavor (ogc = Open Gaming Collective / fsync gaming kernel)
    ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-ogc}"
    # Exact kernel version matching the selected akmods images. Resolved by the
    # build tooling from the newest published tag; empty skips the version check.
    ARG KERNEL_VERSION=""
    # Combined akmods tag used across all akmods input stages. The local build
    # scripts and CI pass the exact newest complete tag; a bare podman build falls
    # back to the upstream floating tag so it still tracks the latest kernel.
    ARG AKMODS_TAG="${AKMODS_TAG:-${KERNEL_FLAVOR}-${FEDORA_VERSION}-x86_64}"
    # Homebrew standalone root image
    ARG BREW_IMAGE="${BREW_IMAGE:-ghcr.io/ublue-os/brew:latest}"
    # Full refs of the akmods inputs. just_scripts/verify-upstream-images checks
    # each upstream image's cosign signature; CI and `just build` pass the verified
    # repo@sha256 digests here (and in BASE_IMAGE/BREW_IMAGE). The tag defaults only
    # serve a bare, unverified podman build.
    ARG AKMODS_REF="${AKMODS_REF:-ghcr.io/ublue-os/akmods:${AKMODS_TAG}}"
    ARG AKMODS_EXTRA_REF="${AKMODS_EXTRA_REF:-ghcr.io/ublue-os/akmods-extra:${AKMODS_TAG}}"
    ARG AKMODS_NVIDIA_REF="${AKMODS_NVIDIA_REF:-ghcr.io/ublue-os/akmods-nvidia-open:${AKMODS_TAG}}"

    # Pull the pre-compiled kernel and akmods rpms for the selected akmods tag
    FROM ${AKMODS_REF} AS akmods
    # Pull the akmods-extra trees (device-specific kmods and their userspace parts;
    # only nct6687d is installed, see build_files/kernel/install-kernel-akmods)
    FROM ${AKMODS_EXTRA_REF} AS akmods-extra
    # Pull the NVIDIA open driver rpms matching the pinned kernel
    FROM ${AKMODS_NVIDIA_REF} AS akmods-nvidia
    # Pull the pre-packaged Homebrew standalone root
    FROM ${BREW_IMAGE} AS brew

    # Build context helper: isolates build scripts so they can be bind-mounted without polluting image layers
    FROM scratch AS ctx
    COPY build_files /
    COPY packages.json /

    # Pinned external downloads (build_files/downloads/manifest.tsv), sha256-checked.
    # This is the only stage that mounts GITHUB_TOKEN, and it installs no packages,
    # so no RPM scriptlet ever sees the token. Package stages bind-mount /out
    # read-only at /downloads.
    FROM ${BASE_IMAGE} AS downloads
    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        --mount=type=secret,id=GITHUB_TOKEN \
        /ctx/downloads/fetch-pinned /out

    ################
    # BAZZITE BASE
    ################

    FROM ${BASE_IMAGE} AS alcyone
    # hadolint shell=bash

    # Image name identifier
    ARG IMAGE_NAME="${IMAGE_NAME:-alcyone}"
    # Image vendor namespace
    ARG IMAGE_VENDOR="${IMAGE_VENDOR:-halcyon-linux}"
    # Image release branch (stable, testing, unstable)
    ARG IMAGE_BRANCH="${IMAGE_BRANCH:-stable}"
    # Fedora release number (redeclared in this stage so RUN instructions can use it)
    ARG FEDORA_VERSION="${FEDORA_VERSION:-45}"
    # Build version tag
    ARG VERSION_TAG="${VERSION_TAG}"
    # Formatted user-facing version string
    ARG VERSION_PRETTY="${VERSION_PRETTY}"
    # Kernel version (redeclared so RUN steps can verify against it; empty on local builds)
    ARG KERNEL_VERSION

    # Keep the shared Bazzite configuration in the image root.
    COPY system_files/desktop/ /

    # Install the dnf5 retry shim before the first dnf transaction. The kernel
    # install runs before repository setup, and upstream metadata can be stale
    # immediately after a repo republishes; without the shim that RUN gets no retries.
    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        usr_local=$(readlink -f /usr/local) && \
        mkdir -p "$usr_local/bin" && \
        install -m0755 /ctx/shared/dnf5 "$usr_local/bin/dnf5"

    # Use the standalone files exposed by the Homebrew image's /system_files tree.
    COPY --from=brew /system_files/ /tmp/brew_files/
    RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
        /ctx/packages/install-brew-files && \
        /ctx/finalization/verify brew

    # Install kernel
    RUN --mount=type=cache,dst=/var/cache \
        --mount=type=cache,dst=/var/log \
        --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/tmp/kernel-rpms \
        --mount=type=bind,from=akmods-extra,src=/rpms/extra,dst=/tmp/rpms/extra \
        --mount=type=bind,from=akmods-extra,src=/rpms/kmods,dst=/tmp/rpms/kmods-extra \
    92 matches in 2 files:

    build_files/finalization/verify:10:brew | kernel | repos | cli-tools | utils | removals | common-packages | gami...
    build_files/finalization/verify:720:verify_nix() {
    build_files/finalization/verify:721:require_rpms_from_json "nix" "packages"
    build_files/finalization/verify:725:for bin in /usr/bin/nix /usr/bin/nix-daemon /usr/bin/busybox; do
    build_files/finalization/verify:733:if [[ -d /nix ]]; then
    build_files/finalization/verify:734:pass "mountpoint directory exists: /nix"
    build_files/finalization/verify:736:fail "mountpoint directory missing: /nix"
    build_files/finalization/verify:741:/usr/lib/systemd/system/var-nix.service \
    build_files/finalization/verify:742:/usr/lib/systemd/system/nix.mount \
    build_files/finalization/verify:743:/usr/lib/tmpfiles.d/nix.conf \
    build_files/finalization/verify:744:/usr/lib/user-tmpfiles.d/halcyon-nix.conf \
    build_files/finalization/verify:745:/etc/profile.d/00-nix-resolve-home-env.sh \
    build_files/finalization/verify:746:/etc/nix/nix.conf; do
    build_files/finalization/verify:748:pass "nix file present: $f"
    build_files/finalization/verify:750:fail "nix file missing: $f"
    build_files/finalization/verify:755:if grep -qE '^d %S/nix/profiles ' /usr/lib/user-tmpfiles.d/halcyon-nix.conf 2...
    build_files/finalization/verify:756:pass "user tmpfiles creates \$XDG_STATE_HOME/nix/profiles for home-manager"
    build_files/finalization/verify:758:fail "/usr/lib/user-tmpfiles.d/halcyon-nix.conf must create %S/nix/profiles"
    build_files/finalization/verify:761:if grep -q "NIX_REMOTE=daemon" /etc/profile.d/00-nix-resolve-home-env.sh; then
    build_files/finalization/verify:764:fail "NIX_REMOTE=daemon missing from /etc/profile.d/00-nix-resolve-home-env.sh"
    build_files/finalization/verify:911:if grep -q '^nix-relabel-unit' /usr/share/ublue-os/just/90-security.just 2>/d...
    build_files/finalization/verify:912:pass "ujust nix-relabel-unit recipe present"
    build_files/finalization/verify:914:fail "ujust nix-relabel-unit recipe missing from 90-security.just"
    build_files/finalization/verify:926:sddm.service cups.service bpftune.service tuned.service fstrim.timer \
    build_files/finalization/verify:927:nix-daemon.socket nix-daemon.service auditd.service audit-rules.service; do
      +64 more in build_files/finalization/verify
    tests/test-audit-lint.sh:53:for section in applications base-pkgs cli-tools common-packages fonts gaming ...
    tests/test-audit-lint.sh:344:ssh = (root / 'system_files/overrides/etc/ssh/sshd_config.d/10-halcyon-harden...
    tests/test-audit-lint.sh:345:assert 'Port 47' in ssh.splitlines(), 'firewall must match SSH port'
    ✓ • 0ms

## Activity

    mcp tool: codex_apps/exa.web_search_exa({"query":"Nix manual trusted-users essentially equivalent root arbitrary derivations security","numResults":3,"objective":"Verify security implications of the repository setting trusted-users = root @wheel against the official Nix manual."}) · Completed
    Title: nix.conf - Nix Reference Manual
    URL: https://nix.dev/manual/nix/2.26/command-ref/conf-file.html?highlight=trusted-users
    Published: N/A
    Author: N/A
    Highlights:
    - `allowed-users`

    A list user names, separated by whitespace. These users are allowed to connect to the Nix daemon.

    You can specify groups by prefixing names with `@`. For instance, `@wheel` means all users in the `wheel` group. Also, you can allow all users by specifying `*`.

    > Note
    >
    > Trusted users (set in `trusted-users`) can always connect to the Nix daemon.

    Default: `*`

    ...

    - `build-users-group`

    This options specifies the Unix group containing the Nix build user accounts. In multi-user Nix installations, builds should not be performed by the Nix account since that would allow users to arbitrarily modify the Nix store and database by supplying specially crafted builders; and they cannot be performed by the calling user since that would allow him/her to influence the build result.

    Therefore, if this option is non-empty and specifies a valid group, builds will be performed under the user accounts that are a member of the group specified here (as listed in `/etc/group`). Those user accounts should not be used for any other purpose!

    Nix will never run two builds under the same user account at the same time. This is to prevent an obvious security hole: a malicious user writing a Nix expression that modifies the build result of a legitimate Nix expression being built by another user. Therefore it is good to have as many Nix build user accounts as you can spare. (Remember: uids are cheap.)

    The build users should have permission to create files in the Nix store, but not delete them. Therefore, `/nix/store` should be owned by the Nix account, its group should be the group specified here, and its mode should be `1775`.

    If the build users group is empty, builds will be performed under the uid of the Nix process (that is, the uid of the caller if `NIX_REMOTE` is empty, the uid under which the Nix daemon runs if `NIX_REMOTE` is `daemon`). Obviously, this should not be used with a nix daemon accessible to untrusted clients.

    Defaults to `nixbld` when running as root, empty otherwise.

    Default: machine-specific

    ...

    For Nix to use substituters, the calling user must be in the `trusted-users` list.

    ...

    Optional.

    ...

    This option is only settable in the global `nix.conf`, or on the command line by trusted users.

    ...

    - `sandbox`

    If set to `true`, builds will be performed in a sandboxed environment, i.e., they’re isolated from the normal file system hierarchy and will only see their dependencies in the Nix store, the temporary build directory, private versions of `/proc`, `/dev`, `/dev/shm` and `/dev/pts` (on Linux), and the paths configured with the `sandbox-paths` option. This is useful to prevent undeclared dependencies on files in directories such as `/usr/bin`. In addition, on Linux, builds run in private PID, mount, network, IPC and UTS namespaces to isolate them from other processes in the system (except that fixed-output derivations do not run in private network namespace to ensure they can access the network).

    Currently, sandboxing only work on Linux and macOS. The use of a sandbox requires that Nix is run as root (so you should use the “build users” feature to perform the actual builds under different users than root).

    If this option is set to `relaxed`, then fixed-output derivations and derivations that have the `__noChroot` attribute set to `true` do not run in sandboxes.

    The default is `true` on Linux and `false` on all other platforms.

    Default: `true`

    ...

    - `substituters`

    A list of URLs of Nix stores to be used as substituters, separated by whitespace. A substituter is an additional store from which Nix can obtain store objects instead of building them.

    Substituters are tried based on their priority value, which each substituter can set independently. Lower value means higher priority. The default is `https://cache.nixos.org`, which has a priority of 40.

    At least one of the following conditions must be met for Nix to use a substituter:

    - The substituter is in the `trusted-substituters` list
    - The user calling Nix is in the `trusted-users` list

    In addition, each store path should be trusted as described in `trusted-public-keys`

    ...

    - `trusted-substituters`

    A list of Nix store URLs, separated by whitespace. These are not used by default, but users of the Nix daemon can enable them by specifying `substituters`.

    Unprivileged users (those set in only `allowed-users` but not `trusted-users`) can pass as `substituters` only those URLs listed in `trusted-substituters`.

    Default: empty

    Deprecated alias: `trusted-binary-caches`
    - `trusted-users`

    A list of user names, separated by whitespace. These users will have additional rights when connecting to the Nix daemon, such as the ability to specify additional substituters, or to import unsigned realisations or unsigned input-addressed store objects.

    You can also specify groups by prefixing names with `@`. For instance, `@wheel` means all users in the `wheel` group.

    > Warning
    >
    > Adding a user to `trusted-users` is essentially equivalent to giving that user root access to the system. For example, the user can access or replace store path contents that are critical for system security.

    Default: `root`

    ---

    Title: Documentation: should nix.settings.trusted-users warn about root-equivalency?
    URL: https://github.com/NixOS/nixpkgs/issues/231408
    Published: N/A
    Author: N/A
    Highlights:
    # Documentation: should nix.settings.trusted-users warn about root-equivalency?

    - State: open
    - Author: cumber
    - Created: 2023-05-12T04:35:17Z
    - Updated: 2025-09-20T17:22:40Z
    - Repository: NixOS/nixpkgs
    - Number: #231408

    ## Labels

    - 9.needs: documentation
    - 2.status: stale

    ---

    ## Problem

    The Nix manual, when discussing the `trusted-users` setting, has a big warning:

    > **Warning**
    >
    > Adding a user to `trusted-users` is essentially equivalent to giving that user root access to the system. For example, the user can set `sandbox-paths` and thereby obtain read access to directories that are otherwise inacessible to them.

    Nothing about root-equivalency is mentioned in the documentation for the corresponding NixOS option.

    Is this because the way things work on NixOS being a trusted-user is **not** root-equivalent? Or does it provide the same level of access (this was my impression)?

    Either way, I feel like this should be called out explicitly. I see suggestions to make yourself a trusted-user fairly regularly (including automated suggestions from tools, e.g. Cachix does this).


    ## Proposal

    The documentation for `nix.settings.trusted.users` should either have the same warning, or a note that the vulnerability that would apply to user-installed Nix doesn't apply on NixOS.

    ...

    **lf-** commented on 2023-12-25T01:48:06Z:

    > If anything it's more obviously root equivalent on NixOS :)

    ...

    > On that note: nix-health checks if the user is in Trusted Users and complains if not. (Without explaining anything).

    ...

    > Managed to get that check in omnix-health disabled by default but it's still in there. It should check and complain for the opposite.

    ---

    Title: nix.conf - Nix Reference Manual
    URL: https://nix.dev/manual/nix/2.23/command-ref/conf-file
    Published: N/A
    Author: N/A
    Highlights:
    - `trusted-users`

    A list of user names, separated by whitespace. These users will have additional rights when connecting to the Nix daemon, such as the ability to specify additional substituters, or to import unsigned realisations or unsigned input-addressed store objects.

    You can also specify groups by prefixing names with `@`. For instance, `@wheel` means all users in the `wheel` group.

    > Warning
    >
    > Adding a user to `trusted-users` is essentially equivalent to giving that user root access to the system. For example, the user can access or replace store path contents that are critical for system security.

    Default: `root`

## Activity

    • Started `/root/assessment_review`

## Activity

    $ bash tests/test-audit-lint.sh
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/downloads/fetch-pinned
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/finalization/finalize
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/finalization/image-info
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/finalization/verify
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/just/import-bazzite-justfiles
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/kernel/build-initramfs
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/kernel/install-kernel-akmods
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/kernel/install-kmods
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/nvidia/configure-nvidia
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/nvidia/finalize-nvidia
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/nvidia/install-nvidia-driver
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/bake-texlive-formats
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-applications
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-base-pkgs
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-brew-files
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-cli-tools
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-common-packages
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-fonts
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-gaming-stack
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-media-automount
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-nix
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-security
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-system-integration-files
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-texlive-packages
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-ujust-picker
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-utils
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/setup-repositories
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/global-remove
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/shared/check-gpg-fingerprints
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/shared/cleanup
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/shared/dnf5
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/shared/ghcurl
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-desktop-integration
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-grub
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-security-hardening
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-system-policy
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/system/generate-audit-privileged-rules
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-system-services
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/just_scripts/build-image
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/just_scripts/bump-downloads
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/just_scripts/container_mgr
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/just_scripts/get-defaults
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/just_scripts/manage-images
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/just_scripts/resolve-akmods
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/just_scripts/run-image
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/just_scripts/verify-upstream-images
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/tests/test-audit-lint.sh
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/tests/test-dnf5-retry.sh
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/tests/test-security-hardening.sh
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/etc/profile.d/99-custom-env.sh
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/bin/apply-gtk-themes
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/bin/halcyon-hosts-entry
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/bin/halcyon-mor
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/bin/halcyon-security-posture
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/bin/halcyon-shadow-sync
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/lib/tuned/profiles/balanced-bazzite/script.sh
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/lib/tuned/profiles/powersave-bazzite/script.sh
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/lib/tuned/profiles/throughput-performance-bazzite/script.sh
    OK: syntax: /var/home/ahsan/Git/halcyon/base-image/system_files/overrides/usr/share/bazzite-cli/bling
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/downloads/fetch-pinned
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/finalization/finalize
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/finalization/image-info
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/finalization/verify
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/just/import-bazzite-justfiles
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/kernel/build-initramfs
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/kernel/install-kernel-akmods
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/kernel/install-kmods
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/nvidia/configure-nvidia
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/nvidia/finalize-nvidia
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/nvidia/install-nvidia-driver
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/bake-texlive-formats
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-applications
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-base-pkgs
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-brew-files
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-cli-tools
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-common-packages
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-fonts
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-gaming-stack
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-media-automount
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-nix
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-security
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-system-integration-files
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-texlive-packages
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-ujust-picker
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/install-utils
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/setup-repositories
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/packages/global-remove
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/shared/check-gpg-fingerprints
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/shared/cleanup
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/shared/dnf5
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/shared/ghcurl
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-desktop-integration
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-grub
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-security-hardening
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-system-policy
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/system/generate-audit-privileged-rules
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/build_files/system/configure-system-services
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/just_scripts/build-image
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/just_scripts/bump-downloads
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/just_scripts/container_mgr
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/just_scripts/get-defaults
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/just_scripts/manage-images
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/just_scripts/resolve-akmods
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/just_scripts/run-image
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/just_scripts/verify-upstream-images
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/tests/test-audit-lint.sh
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/tests/test-dnf5-retry.sh
    OK: executable: /var/home/ahsan/Git/halcyon/base-image/tests/test-security-hardening.sh
    OK: packages.json is valid JSON
    OK: packages.json section exists: applications
    OK: packages.json section exists: base-pkgs
    OK: packages.json section exists: cli-tools
    OK: packages.json section exists: common-packages
    OK: packages.json section exists: fonts
    OK: packages.json section exists: gaming
    OK: packages.json section exists: ghostty
    OK: packages.json section exists: kernel
    OK: packages.json section exists: nix
    OK: packages.json section exists: noctalia
    OK: packages.json section exists: security
    OK: packages.json section exists: texlive-packages
    OK: packages.json section exists: utils
    OK: virtiofsd is installed from common-packages
    OK: requested package metadata is consistent
    OK: BlueZ is installed and verified from Fedora repos
    OK: VSCodium remains absent from app metadata and integration
    OK: Ghostty is installed and verified from its own COPR
    OK: redundant Bazaar content file and reference absent
    OK: DRM verification requires only the native 64-bit development library
    OK: global-remove removes inherited fish configuration and files
    OK: Firefox remains installed and is not removed by global cleanup
    OK: global-remove deletes and verifies the fish shell registration
    OK: install-brew-files does not chmod the absent first-boot Brew tree
    OK: noctalia-git installs from lionheartp/Hyprland at lowest COPR priority
    OK: final verification does not require ProtonPlus or Winetricks
    OK: Winetricks download removed
    OK: Winetricks removed from package metadata
    OK: all YAML files valid
    OK: stock audit.rules absent
    OK: 99-zz-lock.rules not shipped
    OK: audit rules file exists: 10-base-config.rules
    OK: audit rules file exists: 12-cont-fail.rules
    OK: audit rules file exists: 20-dont-audit.rules
    OK: audit rules file exists: 30-identity.rules
    OK: audit rules file exists: 32-power-abuse.rules
    OK: audit rules file exists: 40-kernel.rules
    OK: audit rules file exists: 41-persistence.rules
    OK: audit rules file exists: 44-installers.rules
    OK: audit rules file exists: 50-security-config.rules
    OK: audit rules file exists: 60-access-denied.rules
    OK: audit rules file exists: 99-finalize.rules
    OK: no deprecated -w watch rules
    OK: no rule disables syscall auditing
    OK: no unsupported kexec syscall in b32 rules
    OK: no duplicate audit rules
    OK: exactly one -D rule
    OK: 10-base-config sets -b 8192 and --loginuid-immutable
    OK: audit rules continue on error with -c and never use -i
    OK: audit rules end enabled with -e 1
    OK: auditd.conf logs in ENRICHED format
    OK: auditd.conf has no SINGLE/HALT/EXEC action
    OK: Fedora desktop authentication, firewall and audit invariants
    OK: GITHUB_TOKEN mounted only in the downloads stage
    OK: Terra repositories are explicitly disabled
    OK: no mutable download refs in build_files
    OK: no --nogpgcheck or ignored rpm --import
    OK: download manifest rows are pinned (https URL, sha256, flat dest)
    OK: every external repo pins its GPG key fingerprints

    test-audit-lint: all checks passed
    ✓ • 363ms

## Activity

    mcp tool: codex_apps/exa.web_fetch_exa({"urls":["https://openwrt.org/docs/guide-user/network/traffic-shaping/sqm","https://bootc.dev/bootc/bootc-security.7.html"],"objective":"Verify primary guidance for router SQM and bootc trust boundaries; extract only recommendations relevant to balanced desktop hardening."}) · Completed
    # Making sure you're not a bot!
    URL: https://openwrt.org/docs/guide-user/network/traffic-shaping/sqm

    Making sure you're not a bot!

    This is a measure against bots and malicious requests similar to a CAPTCHA. However, instead of having to do work yourself, your browser is given a calculation task that it has to solve to ensure that it is a valid client. This concept is called Proof of Work. The task is calculated in a few seconds and you are granted access to the website. Thank you for your understanding and patience.

    Please note that Anubis requires the use of modern JavaScript features that plugins like JShelter will disable. Please disable JShelter or other such plugins for this domain.

    Sadly, you must enable JavaScript to get past this challenge. This is required because AI companies have changed the social contract around how website hosting works. A no-JS solution is a work-in-progress.

    # Security and threat model - bootc
    URL: https://bootc.dev/bootc/bootc-security.7.html

    Security and threat model - bootc

    # Security and threat model

    This page describes bootc's trust boundaries and how to configure stronger guarantees than the defaults. If you believe you've found a valid vulnerability, see SECURITY.md for how to report it.

    ## Privileges

    bootc is a binary that is intended to be run with full privileges. It does not expose a service (socket, HTTP endpoint) by default; that's the role of higher level tooling.

    All inputs (CLI arguments, etc) are hence considered fully trusted by default.

    ## Container image verification

    bootc honors the default `/etc/containers/policy.json` when fetching images. The upstream default at the time of this writing does not require signatures for generic images.

    It is not a vulnerability in bootc that signatures are not required by default.

    It is however a very good idea for bootc users to enable signatures for their images.

    ## On-disk integrity vs. pull-time verification

    The default backend is ostree (with a composefs mount), but fsverity is not enabled by default.

    The composefs backend enables fsverity by default if available, but does not verify the composefs image (because there's nothing to verify it against by default).

    The composefs backend with sealed UKIs does verify the composefs mount. With composefs + sealed UKIs, it is a vulnerability if e.g. an attacker can mutate a file in the image store, have that persist across a re-mount without it resulting in an `EIO` error (default for Linux kernel fsverity).

## Activity

    • Completed `/root/assessment_review`

## Activity

    $ bash tests/test-security-hardening.sh
    Error: ghcr.io/ublue-os/base-main:45: image not known
    ✗ (125) • 0ms

## Assistant

The highest-value changes appear to be enforcing signed OS updates, removing Nix’s root-equivalent trust for all wheel users, and narrowing service exposure. Further kernel restrictions would need more compatibility testing.

The repository audit/lint checks passed. The isolated authentication/firewall test hit a Podman sandbox restriction; I’ve requested permission to rerun it with access to Podman’s runtime directory. I haven’t checked the deployed host’s encryption, Secure Boot, listeners, or network performance.

## Activity

    mcp tool: codex_apps/exa.web_search_exa({"query":"site.github.com/tohojo/sqm-scripts README cake fq_codel latency traffic shaping","numResults":3,"objective":"Find primary SQM project documentation to verify router traffic shaping recommendations after OpenWrt wiki fetch was blocked."}) · Completed
    Title: README.md
    URL: https://github.com/tohojo/sqm-scripts/blob/main/README.md
    Published: N/A
    Author: N/A
    Highlights:
    This repository contains the sqm-scripts traffic shaper from the CeroWrt
    project. See:
    http://www.bufferbloat.net/projects/cerowrt/wiki/Smart_Queue_Management

    ## How does sqm-scripts set up traffic shaping?

    sqm-scripts uses the Linux qdisc mechanism to configure traffic shaping and
    scheduling. Either by a combination of the HTB qdisc (for shaping) and fq_codel
    (for packet scheduling), or using the CAKE integrated scheduler to do both at
    once.

    Because qdiscs only see traffic as it is *leaving* an interface, for ingress
    shaping sqm-scripts sets up an IFB device. Incoming packets are redirected to
    this device where a regular qdisc can handle them. The IFB device is named for
    the egress interface it is paired with, so the IFB for 'eth0' will be called
    'ifb4eth0'.

    This is all illustrated on the following diagram:

    qdisc diagram
    Diagram contributed by Matt Taggart (@taggart). Source in qdisc-diagram.dia.

    ## Requirements

    To run sqm-scripts you just need a Linux machine with a kernel from the last
    decade or so (any of the longterm releases on kernel.org should work - please
    don't run a kernel that is not a currently released version, longterm or
    current). The only exception is that if you want to use the `cake` qdisc, you
    either need kernel 4.19 or newer (with matching `iproute2` version), or you need
    to build CAKE yourself from the out-of-tree repository at
    https://github.com/dtaht/sch_cake.

    ---

    Title: ipq806x / Netgear R7800: difference in download speeds with cake and simple/fq_codel (possibly due to HTB )
    URL: https://github.com/tohojo/sqm-scripts/issues/48
    Published: N/A
    Author: N/A
    Highlights:
    # ipq806x / Netgear R7800: difference in download speeds with cake and simple/fq_codel (possibly due to HTB )

    - State: closed
    - Author: hnyman
    - Created: 2016-11-16T10:06:52Z
    - Updated: 2017-01-30T13:55:51Z
    - Repository: tohojo/sqm-scripts
    - Number: #48

    ---

    I have a new router Netgear R7800 that is an 1,7 GHz dual-core IPQ8065 device. I have been building and testing new LEDE builds on it and I have stumbled upon strange behaviour with SQM using simple/fq_codel:

    * There is a significant speed gap between the set download speed limit and the realised download speed, as measured by flent.
    * With cake the same speed limit produces significantly higher download speed.
    * My old WNDR3800 (ar71xx) produces the same speed with cake and simple as R7800 with only cake.
    * Increasing the download speed limit by 10 Mb increases the actual download speed by maybe 7 Mbit/s, so the router is not hitting any real CPU or I/O performance limit.

    Data with wired LAN connection:
    * Without any SQM, my connection with R7800 produces 100 Mbit/s down, 12 Mb/s up, 35 ms latency
    * With speed limit down 90, up 8, the results are:
     * strategy / down / up / latency
     * R7800 simple: 67 / 7 /20
     * R7800 cake: 84 / 7 / 19
     * WNDR3800 simple: 83 / 5 / 18
     * WNDR3800 cake: 83 / 5 / 19
    * With speed limit down 100, up 8:
     * R7800 simple: 73 / 7 / 20 , So a 6-7 Mbit/s speed increase without negative impact on upload speed or latency.
    * With R7800 there was no significant difference between wired / wifi
    * I tried bumping kernel HZ from default 100 to 250, but that had no effect.

    It is almost like the simple/fq_codel would produce in ipq806x a realised download speed of some 75% of the set limit. With the old trustry ar71xx/WNDR3800 the speed gets higher upto the hardware limits.

    This almost looks like there is some kind of calculation bug in the fq_codel code when compiled for IPQ806x (code base is arm_cortex-a15_neon-vfpv4 )

    Any clues to what could cause this? How to debug?

    *

    ...

    > The absolute speed difference between what you configure and what Flent
    > measures is not too worrisome. There's quite a bit of overhead
    > in-between there (Flent measures at the application level, and doesn't
    > include the overhead of the latency measurement flows).

    ...

    **hnyman** commented on 2016-11-16T15:54:34Z:

    > Great suggestion!!!!
    >
    > TBF is part of kmod_sched (like HTB), so I have it on my build.
    > I did a quick and dirty Ookla speedtest and the resulting change is impressive:
    > - simple with original HTB: 77 / 7 Mbit/s
    > - simple with TBF (your commands): 85 / 8 Mbit/s
    >
    > So, an immediate jump of 8 Mbit/s in the download speed and now the throughput is much closer to the set limit of 90 / 8.

    ...

    **hnyman** commented on 2017-01-03T17:16:16Z:

    > I built SQM from https://github.com/tohojo/sqm-scripts/commit/699f5d014b23790a3ac4e8280a14ac740cd5c3e4 and tested briefly.
    >
    > With Ookla speedtest the simplest_tbf performed ok and catched up cake pretty well:
    > ```
    > Ookla speedtest
    > LIMITS: 90 / 8
    >
    > simple 80.0 / 7.8
    > simplest 78.5 / 7.9
    > simplest_tbf 85.3 / 7.4
    > piece_cake 85.5 / 7.5
    > layer_cake 85.5 / 7.3
    > triple_llt_cake 85.4 / 7.5
    > default_cake 85.5 / 7.6
    > ```
    > (default_cake is cake with as much current cake defaults as possible)
    >
    > htb/fq_codel also also performs much better in the speedtest. The difference to cake is not that big any more. The htb patch discussed above has been integrated into LEDE and has improved htb performace somewhat. The build also includes several other scheduling performance backports from @nbd that are in his staging tree as https://git.lede-project.org/?p=lede/nbd/staging.git;a=commit;h=ded9d3dc303da8752eef0a4ae910f8a325dd21ec
    >
    > (One factor might also be musl-1.1.16 clib, which this current build is based on.)
    >
    > With flent I tested simple, simplest_tbf and triple_cake. There is still a clear performance hit for simple. Much more pronounced than in Ookla speedtest:
    > ```
    > flent
    > LIMITS: 90 / 8 / latency
    >
    > simple 70 / 7 / 20
    > simplest_tbf 84 / 6 / 18
    > triple_llt_cake 85 / 6 / 19
    > ```
    > Apparently something still makes it to calculate the correct throttling wrong when the traffic is more complex like with flent. But simplest_tbf performs well.
    >
    > Just to highlight that this phenomenom is not about the router's CPU power or line conditions, I tested also with download limit raised to 110 Mbit/s and decreased to 60 Mbit/s:
    > ```
    > flent
    > simple with 110/8 : 79 / 6 / 20
    > simple with 90/8 : 70 / 7 / 20
    > simple with 60/8 : 53 / 7 / 20
    > ```
    > The increase of the download speed limit by 20 Mbit/s increased the actual tested speed by 9 Mbit/s. And decrease by 30 decreased tested speed by 17. It almost looks like the system calculates the "true speed limit" like (LIMIT/2)+25 for the htb-based strategies. Strange. Hopefully things improve with newer kernels.

    ...

    **hnyman** commented on 2017-01-22T18:38:39Z:

    > I tested with flent the change from 5bc27cc758407b and things were improved also according to flent:
    >
    > ```
    > settings: download / upload / latency:
    >
    > htbburst1 simple 90/8 : 78 / 6.5 / 20
    > htbburst1 simple 110/8: 96 / 6.5 / 21
    >
    > simple 90/8 : 70 / 6.5 / 20
    > simple 110/8 : 78 / 6.5 / 20
    > ```
    >
    > Latency is roughly similar in all four cases.
    >
    > With the new htb_burst 1 option, the measured download speed is much closer to the set limit. Still not at cake's level, but much closer.
    >
    > And the increase of the speed limit by 20 Mbit/s increased the measured speed by 16 Mbit/s with htb burst 1, which is much more logical than the change of 8 Mbit/s without that option.
    >
    > so far the htb_burst 1 option looks good :-)

    ---

    Title: src/layer_cake.qos.help
    URL: https://github.com/tohojo/sqm-scripts/blob/main/src/layer_cake.qos.help
    Published: N/A
    Author: N/A
    Highlights:
    # src/layer_cake.qos.help

    - Branch: main
    - Repository: tohojo/sqm-scripts

    ---

    This uses the cake qdisc as a replacement for both htb as shaper and fq_codel as leaf qdisc.
    This exercises cake's diffserv profile(s) as different "layers" of priority.
    This script requires that cake is selected as qdisc, and forces its usage.
    See: http://www.bufferbloat.net/projects/codel/wiki/Cake for more information

## Activity

    $ nl -ba system_files/desktop/etc/nix/nix.conf; nl -ba system_files/desktop/usr/lib/sysctl.d/75-networking.conf; nl -ba system_files/overrides/etc/firewalld/zones/FedoraWorkstation.xml; nl -ba system_files/desktop/usr/lib/sysctl.d/60-kernel.conf; nl -ba system_files/desktop/usr/lib/systemd/system/halcyon-aide-check.service; rtk rg -n 'esp4|xfrm_user|l2tp_core' system_files/desktop/usr/lib/modprobe.d/halcyon-blocklist.conf; rtk rg -n 'arp_filter|arp_ignore|drop_gratuitous|rp_filter|io_uring' system_files/desktop/usr/lib/sysctl.d/55-halcyon-hardening.conf; rtk rg -n 'cups|bpftune|nix-daemon|podman.socket' build_files/system/configure-system-services
         1    # Halcyon Nix daemon configuration
         2    build-users-group = nixbld
         3    auto-optimise-store = true
         4    experimental-features = nix-command flakes
         5    extra-nix-path = nixpkgs=flake:nixpkgs
         6    trusted-users = root @wheel
         7    max-jobs = 4
         8    cores = 6
         1    net.core.default_qdisc=fq
         2    net.ipv4.tcp_congestion_control=bbr
         3    net.ipv4.tcp_mtu_probing=1
         4    net.ipv6.conf.all.use_tempaddr=2
         5    net.ipv6.conf.default.use_tempaddr=2
         1    <?xml version="1.0" encoding="utf-8"?>
         2    <!-- Halcyon override of the FedoraWorkstation firewalld zone, adapted from
         3         secureblue files/system/etc/firewalld/zones/FedoraWorkstation.xml:
         4         Fedora's default opens TCP/UDP 1025-65535 for local applications; this
         5         closes them. Unlike secureblue, ssh (port 47) and dhcpv6-client stay allowed:
         6         `ujust ssh` enables sshd, and without dhcpv6-client DHCPv6 replies from
         7         the router are dropped. Only effective while this zone is the active one
         8         (configure-security-hardening makes this the default; explicit
         9         NetworkManager connection zones remain administrator-controlled). -->
        10    <zone>
        11      <short>Fedora Workstation</short>
        12      <description>Unsolicited incoming network packets are rejected, except for select network services. Incoming packets that are related to outgoing network connections are accepted. Outgoing network connections are allowed.</description>
        13      <service name="dhcpv6-client"/>
        14      <port protocol="tcp" port="47"/>
        15      <forward/>
        16    </zone>
         1    kernel.split_lock_mitigate=0
         1    [Unit]
         2    Description=Halcyon: check file integrity against the AIDE baseline
         3    After=local-fs.target
         4    # Nothing to compare against until halcyon-aide-init.service has run.
         5    ConditionPathExists=/var/lib/aide/aide.db.gz
         6
         7    [Service]
         8    Type=oneshot
         9    Nice=19
        10    IOSchedulingClass=idle
        11    ExecStart=/usr/bin/aide --check
    136:# esp4 and esp6 provide support for Encapsulating Security Payload (IPSec)
    137:install esp4 /bin/false
    138:install esp4_offload /bin/false
    152:install xfrm_user /bin/false
    160:install l2tp_core /bin/false
    9:# - kernel.io_uring_disabled=1 instead of secureblue's 2: unprivileged io_uring
    11:#   escape hatch; value 2 permanently bricks io_uring for high-performance
    14:# - rp_filter stays in loose mode (2), as in systemd's 50-default.conf, instead
    37:net.ipv4.conf.all.rp_filter = 2
    38:net.ipv4.conf.default.rp_filter = 2
    50:net.ipv4.conf.*.arp_filter = 1
    51:net.ipv4.conf.*.arp_ignore = 2
    52:net.ipv4.conf.all.drop_gratuitous_arp = 1
    105:# io_uring: disabled for unprivileged users; administrators may revert at
    107:kernel.io_uring_disabled = 1
    15:    cups.service
    16:    bpftune.service
    21:    nix-daemon.socket
    22:    nix-daemon.service
    37:    podman.socket
    ✓ • 0ms

## Assistant

**You can harden this image substantially further while preserving gaming, NVIDIA, VPNs and containers.** The biggest remaining gains are in update trust, privilege boundaries, application isolation and network exposure—not adding more restrictive sysctls.

This assessment covers the repository’s configuration. I haven’t verified the deployed host’s effective settings, encryption, Secure Boot or network performance.

The existing baseline is already substantial: SELinux enforcement checks, restricted BPF/io_uring/ptrace access, module blocklists, key-only SSH, login lockouts, auditing, weekly AIDE checks, NetworkManager sandboxing and a restrictive firewall.

The following changes offer the most value for your balanced-desktop preference:

| Priority    | Finding                                                                                                                                         | Recommendation                                                                                                                                                                                                                                                                                                                                      |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Highest** | Image signing exists, but the README says signature enforcement is opt-in.                                                                      | Enforce verification for OS installation and subsequent updates. Test rejection of unsigned and incorrectly signed images, legitimate upgrades and recovery. Signing an image alone does not establish client enforcement. [bootc security model](https://bootc.dev/bootc/bootc-security.7.html)                                                    |
| **Highest** | [Nix configuration](/var/home/ahsan/Git/halcyon/base-image/system_files/desktop/etc/nix/nix.conf:6) grants `trusted-users` to every wheel user. | Restrict trusted users to root while retaining ordinary daemon access. Nix documents this trust as effectively root access; it introduces a route beyond interactive sudo authentication. Test flakes, Home Manager and required caches afterward. [Nix manual](https://nix.dev/manual/nix/2.26/command-ref/conf-file.html?highlight=trusted-users) |
| **High**    | Printing, Nix and other services are enabled; users receive a Podman socket.                                                                    | Check actual listeners, socket activation and consumers. Make unused services opt-in, and keep container management sockets local. An enabled service does not necessarily expose a network port.                                                                                                                                                   |
| **High**    | Auditing and integrity monitoring exist, but configuration checks cannot establish runtime protection.                                          | Add a read-only posture report covering SELinux domains, effective sysctls, listeners, firewall zones, update verification, failed security units and audit losses. Make AIDE failures visible and maintain a deliberate baseline-update procedure.                                                                                                 |
| **High**    | Browser/application compromise remains a separate boundary from image immutability.                                                             | Review application permissions, browser sandboxing and access to home directories, devices and container sockets. Use a separate daily account from administration where practical.                                                                                                                                                                 |
| **Medium**  | Normal builds verify upstream inputs, but the Containerfile retains floating defaults for direct builds.                                        | Make the verified build path explicit and prevent accidental publication from unverified inputs. Review runtime download pinning separately; the README identifies it as unfinished.                                                                                                                                                                |

Disk encryption, firmware configuration and boot trust need their own deployment work. The image can provide tooling and checks, but cannot establish those protections merely by layering files. Secure Boot with trusted kernel/modules—and potentially verified UKIs/root filesystem integrity—is a larger project with NVIDIA, key-enrollment and recovery requirements. Pull-time image signatures and boot-time integrity protect different boundaries. [bootc documentation](https://bootc.dev/bootc/bootc-security.7.html)

For network hardening, I would prioritize these changes:

| Area                  | Current finding                                                                                                                                                                       | Recommended direction                                                                                                                                                                                                                                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Firewall**          | The [default zone](/var/home/ahsan/Git/halcyon/base-image/system_files/overrides/etc/firewalld/zones/FedoraWorkstation.xml:13) permits DHCPv6 and TCP 47, with intra-zone forwarding. | Use an untrusted-network profile without inbound SSH. Allow SSH explicitly on trusted connections or VPN access. Review forwarding separately so Podman and VPN routing remain functional. Port 47 reduces scanning noise; authentication supplies the protection.                                                                                     |
| **DNS privacy**       | No explicit encrypted-DNS configuration was found in the inspected overlays; inherited/runtime behavior remains unknown.                                                              | Offer per-connection encrypted DNS and verify the active resolver integration. Strict DoT can fail on captive portals or incompatible networks, so make it a deliberate profile choice. NetworkManager’s setting requires a supporting DNS plugin. [NetworkManager documentation](https://networkmanager.dev/docs/api/latest/settings-connection.html) |
| **VPN DNS**           | DNS encryption alone does not establish leak prevention.                                                                                                                              | Test DNS routing and traffic during VPN connection, reconnection and failure, including IPv6. NetworkManager supports negative DNS priorities to exclude competing connections; split DNS requires deliberate domain routing. [DNS priorities](https://networkmanager.dev/docs/api/latest/nm-settings-dbus.html)                                       |
| **Wi-Fi identity**    | IPv6 temporary-address defaults are configured; effective MAC behavior is unverified.                                                                                                 | Check inherited settings before adding per-SSID stable MAC addresses. Preserve exceptions for networks requiring registered MACs. [NetworkManager settings](https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html)                                                                                                                         |
| **ARP restrictions**  | Blanket `arp_filter=1`, `arp_ignore=2` and gratuitous-ARP dropping are configured.                                                                                                    | Treat these as compatibility-review targets. Test Wi-Fi roaming, gateway failover and multiple interfaces before retaining them universally. Kernel documentation describes routing/subnet requirements; these settings are not general ARP-spoofing prevention. [Kernel documentation](https://docs.kernel.org/networking/ip-sysctl.html)             |
| **VPN compatibility** | Both kernel module blocks and SELinux policy restrict IPsec; L2TP modules are blocked too.                                                                                            | Document the supported VPN protocols. Supporting IPsec would require reviewing both layers.                                                                                                                                                                                                                                                            |
| **IPv6/ICMP**         | Ping replies are suppressed.                                                                                                                                                          | Preserve essential ICMPv6 and path-MTU traffic. Keep IPv6 working and validate exposure on both address families.                                                                                                                                                                                                                                      |

Network optimization should be measured on the actual connection:

- **Retain `fq` + BBR as a candidate baseline.** They are already [configured](/var/home/ahsan/Git/halcyon/base-image/system_files/desktop/usr/lib/sysctl.d/75-networking.conf:1). Compare throughput, loaded latency, jitter and loss; BBR controls TCP congestion and does not directly optimize UDP gaming traffic.
- **Inspect effective tuning under load.** Both `bpftune` and tuned are enabled. Establish whether they change overlapping settings before attributing problems or adding more tuning.
- **Address router bufferbloat where present.** SQM using CAKE or fq_codel at the bottleneck can improve latency across competing devices. Host tuning cannot control all queues elsewhere in the network. [SQM project documentation](https://github.com/tohojo/sqm-scripts/blob/main/README.md)
- **Keep hardware-specific adjustments optional.** Wi-Fi power saving, offloads, interrupt moderation and MTU need adapter- and workload-specific comparisons. Avoid universal buffer increases or offload disabling.

I would preserve loose reverse-path filtering, 32-bit gaming support and the existing recovery path. Stronger allocator protections, USB authorization, stricter debugging restrictions and tighter service sandboxes are reasonable optional hardening, with explicit compatibility testing.

Verification performed:

- `bash tests/test-audit-lint.sh` — **passed**.
- `bash tests/test-security-hardening.sh` — **could not run**: after resolving the sandbox restriction, Podman reported the required cached Fedora 45 image was unavailable.
- No image build, boot test, live exposure scan or performance benchmark was performed. No repository files were changed.
