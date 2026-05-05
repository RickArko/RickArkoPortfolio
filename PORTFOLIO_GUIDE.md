# Building a Distinctive Portfolio with Claude

A working guide for using Claude — primarily Claude Code in the terminal for repo iteration, plus claude.ai for longer copy and design conversations — to build and maintain a portfolio site that actually does its job. This site (`rickarko.com`) is the working example.

The site has three jobs:

1. **Professional positioning** — what role-shape you want, grounded in real systems you have built.
2. **Project record** — a structured ledger of work that doubles as a scan-able project management view.
3. **Client acquisition** — qualified inbound from people who already know what they need.

A generic, templated portfolio fails all three.

---

## 1. Frame your positioning before you write a line

Clarity beats clever copy. Decide four things in plain text before you ask Claude for anything:

- **The audience.** Hiring leaders, technical peers, and prospective clients read very differently. Pick the primary reader; secondary readers should still be served, but not at the cost of the primary message.
- **The role-shape you are pursuing.** Be specific and accurate. Examples:
  - Senior IC / Builder
  - Hands-on Technical Lead
  - Staff-level applied ML
  - Selective Consulting / Advisory
- **The role-shapes you are not pursuing.** Just as important. Saying "no" to "Head of", "VP", "Director", or "Founder" labels you do not actually fit narrows the inbound and avoids time-wasting calls.
- **Three outcomes** you want a reader to walk away with — for example:
  - "They understand the kind of system I own end-to-end."
  - "They recognize a name from my track record."
  - "They know how to reach me and what is worth reaching me about."

If you cannot write these down without help, no amount of copy iteration will fix the site.

## 2. Content as structured records, not freeform prose

This site keeps copy in `src/db/*.json`. That is the pattern: pin every block to a small, fixed schema. The home JSON has, for example:

```json
"engagements": [
  {
    "title": "Senior Builder / IC",
    "description": "..."
  }
]
```

Why this matters when working with Claude:

- A request like "rewrite engagement #2 to lean Builder/IC, not Management" hits one record without touching the whole file.
- Templates stay stable, so a copy iteration never breaks layout.
- You can ask Claude to look *across* records: "Find every place that signals availability. Reduce to one."
- Diffs are small and reviewable.

If your site stores copy directly in templates, the first move is to lift it into structured records.

## 3. A typical iteration loop with Claude

A short pattern that works:

1. Read the relevant content and template files (`@src/db/home.json`, `@src/templates/home.html`).
2. Flag any phrasing that reads as job-begging, redundant, or grandiose.
3. Propose specific before-and-after rewrites in a table.
4. Wait for sign-off before applying.

Concrete prompts that earn their keep:

- *"Read `@src/db/home.json`. List every line that signals availability. Highlight redundancy."*
- *"The engagements block currently lists role types. Reframe titles to be IC/Builder, Technical Leadership, and Consulting. Avoid Management or Head-of language."*
- *"Find any 'Founder' framing in the repo. Flag it for me — I am not a founder."*
- *"Propose three replacements for this hero eyebrow. Keep each under 50 characters."*

The win is that Claude becomes a fast, opinionated copy editor that respects your schema.

## 4. Copy review — what to ask Claude to flag

When auditing existing copy, ask Claude to surface:

- **Redundancy.** The same signal repeated more than twice. (Especially "open to opportunities" stacking — easy to accidentally have it five times on one page.)
- **Job-begging tone.** "Looking to...", "Hoping for...", "Available for..." stacked through a single page. One controlled availability line is fine; five is desperation.
- **Self-grandiose labels.** "Founder" when you did not found anything. "Head of X" when you want IC roles. "10x engineer", "AI rockstar", and other empty signal.
- **Empty buzzword stacks.** Long lists of frameworks or tools with no claim about depth or recency.
- **Generic phrasing.** Any sentence that could appear unchanged on someone else's portfolio.
- **Tense drift.** Mixing past and present in a single paragraph or bullet group.
- **Vague impact claims.** "Scaled forecasting" with no numbers; "improved performance" with no baseline.

Save these as a recurring review prompt so you do not have to remember them every quarter.

## 5. Design distinctiveness without redesigning the world

Most portfolios fail visually because they are stock. You do not need a custom design system — you need three or four small, deliberate decisions:

- **One distinctive typography pairing.** Pick specific fonts, not "modern sans". This site uses Fraunces for display and Space Grotesk for body — the contrast is the design.
- **One color decision that is yours.** Build a palette around one anchor hue. Avoid default dark mode and the bootstrap blue.
- **One motion detail that signals craft.** A scroll-reveal or focus-state animation, hand-tuned. Not a library of stock motions.
- **Custom project marks.** Even a 3-letter mark with an accent color (`logo_text` plus `accent` in `projects.json`) beats a stock icon.
- **One unexpected page.** A project log, a structured "things I changed my mind about" page, a public reading list. Something that signals you spend time on the site.

Ask Claude to propose three options for each, then pick one and commit. Do not let it generate "modern, clean, professional" — push back on every generic word.

## 6. Three views, three jobs

Map every page to exactly one of the three jobs, and avoid letting them blur.

### Professional positioning (Home, Experience)

- State the role-shape clearly in the hero, **once**. Do not restate it in every section.
- Ground every claim in a specific system you built. Replace "scaled forecasting" with "improved site-level forecast error from 30%+ to under 15%".
- Avoid title inflation. If you were a Senior Data Scientist, write that — not "AI Strategy Lead".
- Lean into Builder / IC / Technical Leadership framing if that is your target. Do not borrow Management language to sound more senior.

### Project record (Projects)

- Every project is a structured card: title, role/category, description, impact, technologies, links.
- Treat this as your own project management view. You should be able to scan what you have shipped, the shape of the decisions, and the constraints.
- Mark private case studies as such. Do not fake screenshots; use a 3-letter logo with an accent color (the pattern in `projects.json`).
- Keep impact lines factual and measurable. If a number is not available, describe the constraint that was solved.

### Client acquisition (Contact)

- Open with the role-shape, not "open to opportunities".
- Use a "good fit conversations" panel to qualify inbound — what you take, what you do not.
- Make the response path obvious: one primary email link, then secondary channels (LinkedIn, GitHub).
- Do not pretend to be open to everything. Specificity attracts qualified leads. Vagueness attracts recruiters fishing.

## 7. Anti-patterns to avoid

- **Calling yourself a "Founder"** if you did not found a company.
- **"Head of" / "VP" / "Director"** when the role you want is IC / Builder / Technical Lead.
- **Vague availability** ("open to opportunities", "looking for the next thing") repeated more than once on a page.
- **"Looking to..." / "Hoping to..."** as openers — replace with the verb of what you actually do.
- **Listing every framework you have ever touched** as if all are equally true. Pick the ones you would happily own in production.
- **Borrowing other portfolios' positioning wholesale.** Generic copy attracts generic outreach.
- **Stock photography for case studies** when a 3-letter mark and an accent color would honor the constraint better.
- **Burying contact details** under a contact form when an email link would do.

## 8. A quarterly maintenance loop

Once every three months — put it on the calendar:

1. **Audit copy with Claude.** *"Read `@src/db/*.json`. Anything that no longer reflects my current focus?"*
2. **Add and retire projects.** Move stale work to a "past work" archive; promote recent work into the main set.
3. **Rewrite the availability line.** Say exactly what you want this quarter — not what you wanted six months ago.
4. **Re-run the gates.** `make test` for correctness, `make deploy-check` for the deploy preflight.
5. **Regenerate the AI context.** If you keep an AI-condensed snapshot (e.g. `AI-CONTEXT.md`), regenerate it after copy changes so it does not drift.

## 9. Working with Claude effectively

A few small habits that pay off:

- **Hand it the source.** `@src/db/home.json @src/templates/home.html @README.md` beats general questions.
- **State the audience and role-shape in the prompt.** Otherwise it will default to generic positioning copy.
- **Ask for diffs, not full rewrites.** "Propose specific before-and-after pairs in a table" gets you reviewable changes.
- **Push back when it sounds generic.** Generic copy is the failure mode of LLM editing — name the failure and ask again.
- **Keep the schema stable.** Once a content block has a shape (`title`, `description`, `impact`), do not let copy iteration drift it.
- **Use the tool that fits.** Claude Code is best for in-repo edits with diffs; claude.ai is better for longer "what should I even say here" conversations and design ideation.

---

This guide grows with the site. When a pattern stops working — or a new one earns its keep — update it here.
