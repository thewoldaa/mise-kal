#!/usr/bin/env python3
"""
Build the documentation site from the markdown sources.

Why this exists
---------------
The markdown in docs/ is the source of truth: it renders on GitHub, in an
editor, and in a diff. The site is a *view* of that content, not a second copy.
Generating it means the two can never drift, which is the failure mode of every
project that hand-maintains both.

What it produces
----------------
  docs/docs/index.html       hub listing every document
  docs/docs/<name>.html      one page per markdown file
  docs/docs/README.html      the repository README

Run from the repository root:

    python docs/build_site.py

Requires python-markdown (`pip install markdown`). The generated files are
committed so GitHub Pages serves them without a build step, and so a change to
a document shows up in review as a diff in both the source and the output.
"""

import html
import os
import re
import sys
from pathlib import Path

try:
    import markdown
except ImportError:
    sys.exit(
        "python-markdown is required.\n"
        "  pip install markdown\n"
    )

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
OUT = DOCS / "docs"

# The order documents appear in the hub. Anything not listed is appended
# alphabetically, so a new document cannot be silently omitted from the site.
ORDER = [
    "owner-guide",
    "developing",
    "architecture",
    "install-macos",
    "install-windows",
    "testing",
]

TITLES = {
    "owner-guide": "Owner guide",
    "developing": "Developer guide",
    "architecture": "Architecture",
    "install-macos": "Installing on macOS",
    "install-windows": "Installing on Windows",
    "testing": "Testing",
    "README": "Project overview",
    "CONTRIBUTING": "Contributing",
    "SECURITY": "Security",
    "CHANGELOG": "Changelog",
    "AGENTS": "Working in this repository",
}

BLURBS = {
    "owner-guide": "Running a service: taking orders, the kitchen display, closing a shift, and what to do when something goes wrong.",
    "developing": "Setting up a development machine, the four rules the code leans on, and the things that will bite you.",
    "architecture": "How the system is put together, where the seams are, and how each future phase attaches to them.",
    "install-macos": "Building and installing the DMG, and the Gatekeeper warning users will see.",
    "install-windows": "Building the Windows application, and the Developer Mode prerequisite.",
    "testing": "The seven suites, what each covers, and why the harness patches upstream's tests at run time.",
    "README": "What Mise-Kal is, what it does, and how to run it.",
    "CONTRIBUTING": "The workflow contract: branches, commits, tests, and what not to do.",
    "SECURITY": "The threat model, the guarantees the code keeps, and how to report a vulnerability.",
    "CHANGELOG": "What changed in each release.",
    "AGENTS": "How an AI agent works in this repository without breaking it.",
}

# Documents rendered from the repository root rather than docs/.
ROOT_DOCS = ["README", "CONTRIBUTING", "SECURITY", "CHANGELOG", "AGENTS"]

HEAD = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — Mise-Kal</title>
<meta name="description" content="{description}">
<meta name="theme-color" content="#0b0f10">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../assets/site.css">
<style>
  /* Documentation pages are a narrower measure than the landing page: body
     text reads badly past about 75 characters, and these pages are mostly
     prose. */
  .doc-layout {{
    display: grid;
    grid-template-columns: 220px minmax(0, 1fr);
    gap: var(--space-48);
    align-items: start;
    padding: var(--space-32) 0 var(--space-96);
  }}
  @media (max-width: 900px) {{
    .doc-layout {{ grid-template-columns: minmax(0, 1fr); gap: var(--space-24); }}
    .doc-nav {{ position: static !important; }}
  }}
  .doc-nav {{
    position: sticky;
    top: 84px;
    font-size: 13px;
  }}
  .doc-nav p {{
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--text-tertiary);
    margin: 0 0 var(--space-12);
  }}
  .doc-nav ul {{ list-style: none; margin: 0; padding: 0; }}
  .doc-nav li {{ margin: 0; }}
  .doc-nav a {{
    display: block;
    padding: 5px 0;
    color: var(--text-secondary);
    border-left: 2px solid transparent;
    padding-left: 10px;
    margin-left: -12px;
  }}
  .doc-nav a:hover {{ color: var(--text); text-decoration: none; }}
  .doc-nav a[aria-current='page'] {{
    color: var(--text);
    border-left-color: var(--ember);
  }}

  .doc {{
    max-width: 76ch;
    min-width: 0;
  }}
  .doc h1 {{
    font-size: clamp(1.7rem, 4vw, 2.3rem);
    margin-bottom: var(--space-24);
  }}
  .doc h2 {{
    margin-top: var(--space-48);
    padding-top: var(--space-24);
    border-top: 1px solid var(--border);
  }}
  .doc h3 {{ margin-top: var(--space-32); }}
  .doc ul, .doc ol {{ padding-left: 22px; }}
  .doc li {{ margin: var(--space-4) 0; }}
  .doc blockquote {{
    margin: var(--space-24) 0;
    padding: var(--space-4) 0 var(--space-4) var(--space-16);
    border-left: 3px solid var(--border-strong);
    color: var(--text-secondary);
  }}
  .doc blockquote p {{ margin: 0; }}
  .doc hr {{
    border: 0;
    border-top: 1px solid var(--border);
    margin: var(--space-48) 0;
  }}
  .doc table {{ margin: var(--space-24) 0; }}
  .doc img {{ margin: var(--space-16) 0; }}
  .doc-links {{
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-16);
    margin-top: var(--space-48);
    padding-top: var(--space-24);
    border-top: 1px solid var(--border);
    font-size: 13px;
  }}
</style>
</head>
<body>

<a class="skip-link" href="#main">Skip to content</a>

<header class="site-header">
  <div class="wrap">
    <a class="brand" href="../">
      <span class="brand-mark" aria-hidden="true">M</span>
      <span>Mise-Kal</span>
    </a>
    <nav class="site-nav" aria-label="Primary">
      <a href="../demo/">Demo</a>
      <a href="./" {docs_current}>Documentation</a>
      <a href="https://github.com/thewoldaa/mise-kal">GitHub</a>
    </nav>
  </div>
</header>

<main id="main">
<div class="wrap">
  <div class="doc-layout">
    <nav class="doc-nav" aria-label="Documentation">
      <p>Contents</p>
      <ul>
{nav}
      </ul>
    </nav>
    <article class="doc">
{body}
      <div class="doc-links">
        <a href="https://github.com/thewoldaa/mise-kal/blob/main/{source}">View source on GitHub</a>
        <a href="../demo/">Interactive demo</a>
        <a href="./">All documentation</a>
      </div>
    </article>
  </div>
</div>
</main>

<footer class="site-footer">
  <div class="wrap">
    <div>
      <p class="mb-0">
        Mise-Kal &middot; MIT licensed &middot; A derivative of
        <a href="https://github.com/devShakib015/mise">Mise</a>
      </p>
    </div>
    <nav class="footer-links" aria-label="Footer">
      <a href="../">Home</a>
      <a href="../demo/">Demo</a>
      <a href="https://github.com/thewoldaa/mise-kal">GitHub</a>
      <a href="https://github.com/thewoldaa/mise-kal/releases">Releases</a>
    </nav>
  </div>
</footer>

</body>
</html>
"""


def discover():
    """Every document to publish, in ORDER then alphabetical."""
    found = []

    for name in ROOT_DOCS:
        if (ROOT / f"{name}.md").exists():
            found.append((name, ROOT / f"{name}.md", f"{name}.md"))

    for path in sorted(DOCS.glob("*.md")):
        name = path.stem
        if name in ("README", "CONTRIBUTING", "SECURITY", "CHANGELOG"):
            continue
        found.append((name, path, f"docs/{path.name}"))

    ordered = []
    for name in ORDER:
        for item in found:
            if item[0] == name:
                ordered.append(item)
    for item in found:
        if item not in ordered:
            ordered.append(item)
    return ordered


def nav_html(docs, current):
    lines = []
    for name, _, _ in docs:
        title = TITLES.get(name, name.replace("-", " ").title())
        current_attr = " aria-current='page'" if name == current else ""
        lines.append(f'        <li><a href="{name}.html"{current_attr}>{html.escape(title)}</a></li>')
    return "\n".join(lines)


def rewrite_links(body, current):
    """
    Point markdown links at their generated pages.

    A README linking to `docs/architecture.md` must land on
    `architecture.html` when it is rendered into docs/docs/README.html, and the
    same link in the markdown has to keep working on GitHub. Rewriting at build
    time is what lets one source serve both.
    """
    root_docs = {name.lower() for name in ROOT_DOCS}

    def repl(match):
        target = match.group(1)
        anchor = match.group(2) or ""

        # docs/foo.md -> foo.html  (we are already inside docs/docs/)
        m = re.match(r"^\.?/?docs/([A-Za-z0-9_-]+)\.md$", target)
        if m:
            return f'href="{m.group(1)}.html{anchor}"'

        # Foo.md at the root -> Foo.html
        m = re.match(r"^([A-Za-z0-9_-]+)\.md$", target)
        if m and m.group(1).lower() in root_docs:
            return f'href="{m.group(1)}.html{anchor}"'

        # A relative link to a sibling doc from inside docs/
        m = re.match(r"^([A-Za-z0-9_-]+)\.md$", target)
        if m and (DOCS / f"{m.group(1)}.md").exists():
            return f'href="{m.group(1)}.html{anchor}"'

        # .harness/README.md and other markdown we do not publish: send the
        # reader to GitHub rather than to a page that does not exist.
        if target.endswith(".md"):
            return f'href="https://github.com/thewoldaa/mise-kal/blob/main/{target}{anchor}"'

        return match.group(0)

    return re.sub(r'href="([^"]+\.md)(#[^"]*)?"', repl, body)


def render(name, path, source, docs):
    text = path.read_text(encoding="utf-8")

    body = markdown.markdown(
        text,
        extensions=[
            "extra",          # tables, fenced code, attribute lists
            "sane_lists",
            "toc",
            "admonition",
        ],
        extension_configs={
            "toc": {"permalink": False},
        },
    )

    body = rewrite_links(body, name)

    # The first h1 becomes the page heading; strip it so the title is not
    # printed twice (once by the article, once by the markdown).
    body = re.sub(r"<h1[^>]*>.*?</h1>\s*", "", body, count=1, flags=re.S)

    title = TITLES.get(name, name.replace("-", " ").title())
    description = BLURBS.get(name, f"{title} for Mise-Kal.")

    return HEAD.format(
        title=html.escape(title),
        description=html.escape(description),
        docs_current="aria-current='page'",
        nav=nav_html(docs, name),
        body=body,
        source=source,
    )


def hub(docs):
    """The documentation index."""
    cards = []
    for name, _, _ in docs:
        title = TITLES.get(name, name.replace("-", " ").title())
        blurb = BLURBS.get(name, "")
        cards.append(f"""      <a class="card" href="{name}.html" style="display:block">
        <h3 class="mt-0">{html.escape(title)}</h3>
        <p class="mb-0">{html.escape(blurb)}</p>
      </a>""")

    body = f"""      <p class="eyebrow">Documentation</p>
      <h1>Everything about Mise-Kal</h1>
      <p class="lede">
        Written for two readers: the person running a restaurant, and the person
        working on the code. Both are kept honest by the same test suites.
      </p>

      <div class="grid grid-2" style="margin-top: var(--space-32)">
{chr(10).join(cards)}
      </div>

      <h2 style="margin-top: var(--space-64)">Elsewhere</h2>
      <div class="grid grid-3">
        <a class="card" href="../demo/" style="display:block">
          <h3 class="mt-0">Interactive demo</h3>
          <p class="mb-0">Take an order, fire it to the kitchen, and watch the
          server recompute a total a client tried to forge.</p>
        </a>
        <a class="card" href="https://github.com/thewoldaa/mise-kal" style="display:block">
          <h3 class="mt-0">Source code</h3>
          <p class="mb-0">The repository, the issue tracker, and the full commit
          history.</p>
        </a>
        <a class="card" href="https://github.com/thewoldaa/mise-kal/releases" style="display:block">
          <h3 class="mt-0">Releases</h3>
          <p class="mb-0">What changed in each version, and what is next.</p>
        </a>
      </div>"""

    return HEAD.format(
        title="Documentation",
        description="Guides for running and developing Mise-Kal.",
        docs_current="aria-current='page'",
        nav=nav_html(docs, ""),
        body=body,
        source="README.md",
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    docs = discover()

    if not docs:
        sys.exit("No documents found. Run this from the repository root.")

    for name, path, source in docs:
        page = render(name, path, source, docs)
        (OUT / f"{name}.html").write_text(page, encoding="utf-8")
        print(f"  {name}.html  <-  {source}")

    (OUT / "index.html").write_text(hub(docs), encoding="utf-8")
    print("  index.html  (hub)")

    print(f"\nBuilt {len(docs) + 1} pages into {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
