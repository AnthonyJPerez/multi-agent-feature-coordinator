#!/usr/bin/env python3
"""Generate the README's "how it works" diagram in light and dark variants.

    python3 docs/images/how-it-works.py

Writes how-it-works-light.svg and how-it-works-dark.svg next to this file.
Edit the layout here, not in the SVGs, so both variants stay in sync.
"""
from pathlib import Path
from xml.sax.saxutils import escape

HERE = Path(__file__).resolve().parent
W, H = 1120, 740

SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace"

PALETTES = {
    "light": dict(
        text="#1f2328", muted="#59636e", line="#d1d9e0", panel="#f6f8fa", chip="#ffffff",
        arrow="#6e7781", boundary="#8c959f",
        human="#8250df", human_fill="#fbefff", human_line="#d8b9ff",
        lock="#0969da", lock_fill="#ddf4ff", lock_line="#54aeff",
    ),
    "dark": dict(
        text="#f0f6fc", muted="#9198a1", line="#3d444d", panel="#151b23", chip="#0d1117",
        arrow="#9198a1", boundary="#656c76",
        human="#ab7df8", human_fill="#1f1530", human_line="#6e40c9",
        lock="#4493f8", lock_fill="#0f1f37", lock_line="#1f6feb",
    ),
}

# Grid: a human lane on the left; "your machine" holds the coordinator, the
# shared files and one worker per repo; the code hosts sit outside it.
LANE_X, LANE_W = 24, 184
BOX_X, BOX_W = 240, 856                 # machine boundary
CX, CW = 260, 816                       # content area inside it
WORKER_W, GAP = 192, 16
WORKER_X = [CX + i * (WORKER_W + GAP) for i in range(4)]
CENTERS = [x + WORKER_W // 2 for x in WORKER_X]

COORD = dict(x=440, y=72, w=456, h=96)
BAND = dict(x=CX, y=216, w=CW, h=120)
WORKER_Y, WORKER_H = 384, 128
MACHINE_BOTTOM = 544
HOST_Y, HOST_H = 584, 72
BUS_Y = 700

REPOS = ["auth-service", "billing-service", "web-client", "pricing-engine"]
HOSTS = [
    ("GitHub", "draft PR \u2192 ready", False),
    ("Azure DevOps Server", "draft PR \u2192 active", False),
    ("GitLab", "draft MR \u2192 ready", False),
    ("No remote", "draft packet \u2192 ready", True),
]
CHIPS = [
    ("Plan & contracts", "locked by git blob id", True),
    ("Mailbox", "questions and ripples", False),
    ("Decision log", "choices agents made", False),
    ("Briefs & proof", "per-repo brief, test proof", False),
]


def svg(p):
    out = []
    add = out.append

    def text(x, y, s, size=15, weight=400, fill=p["text"], anchor="start", family=SANS, spacing=None, after=()):
        """One line of text; `after` holds (string, size, weight, fill) runs that follow inline."""
        ls = f' letter-spacing="{spacing}"' if spacing else ""
        runs = "".join(f'<tspan font-size="{rs}" font-weight="{rw}" fill="{rf}" letter-spacing="normal">'
                       f'{escape(rt)}</tspan>' for rt, rs, rw, rf in after)
        add(f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{ls}>{escape(s)}{runs}</text>')

    def caps(x, y, s, fill=p["muted"], anchor="start", after=()):
        text(x, y, s, size=12.5, weight=600, fill=fill, anchor=anchor, spacing="0.08em", after=after)

    def rect(x, y, w, h, fill, stroke, rx=10, dash=None, width=1.25):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{width}"{d}/>')

    def line(points, color, end=True, start=False, dash=None, width=1.75):
        pts = " ".join(f"{x},{y}" for x, y in points)
        name = "human" if color == p["human"] else "flow"
        m = ""
        if end:
            m += f' marker-end="url(#{name}-end)"'
        if start:
            m += f' marker-start="url(#{name}-start)"'
        d = f' stroke-dasharray="{dash}"' if dash else ""
        add(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{width}" '
            f'stroke-linejoin="round" stroke-linecap="round"{d}{m}/>')

    def pill(x, y, s, fill, stroke, color):
        w = 14 + len(s) * 7.6
        rect(x, y, w, 24, fill, stroke, rx=12, width=1)
        text(x + w / 2, y + 16.5, s, size=13, weight=500, fill=color, anchor="middle")
        return w

    label = ("Diagram: on your machine, a coordinator session in the anchor repo writes the plan and "
             "locked contracts into shared files; one worker session per repository, each in its own "
             "git worktree with a guard and a stop gate, reads them and works in parallel. Each worker "
             "opens a draft PR on its own repo's host - GitHub, Azure DevOps Server, GitLab, or a review "
             "packet for a local repo with no remote - as soon as it starts. The coordinator marks each "
             "PR ready when its merge step comes. You approve the spec and plan, answer the workers' "
             "questions, and merge the ready PRs in plan order.")
    add(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
        f'role="img" aria-labelledby="title desc">')
    add('<title id="title">How feature-coordinator runs one feature across many repositories</title>')
    add(f'<desc id="desc">{escape(label)}</desc>')
    add("<defs>")
    for name, color in (("flow", p["arrow"]), ("human", p["human"])):
        add(f'<marker id="{name}-end" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" '
            f'markerUnits="userSpaceOnUse" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="{color}"/></marker>')
        add(f'<marker id="{name}-start" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="9" markerHeight="9" '
            f'markerUnits="userSpaceOnUse" orient="auto"><path d="M10,0 L0,5 L10,10 z" fill="{color}"/></marker>')
    add("</defs>")

    # Human lane
    rect(LANE_X, 24, LANE_W, HOST_Y + HOST_H - 24, p["human_fill"], p["human_line"], rx=14)
    lx = LANE_X + LANE_W / 2
    text(lx, 62, "You", size=21, weight=700, fill=p["human"], anchor="middle")
    text(lx, 86, "the engineer who", size=14, fill=p["muted"], anchor="middle")
    text(lx, 104, "owns the feature", size=14, fill=p["muted"], anchor="middle")
    text(lx, 584, "Agents never merge,", size=14, weight=600, fill=p["human"], anchor="middle")
    text(lx, 603, "approve, unlock", size=14, weight=600, fill=p["human"], anchor="middle")
    text(lx, 622, "contracts or roll out", size=14, weight=600, fill=p["human"], anchor="middle")

    # Your machine
    rect(BOX_X, 24, BOX_W, MACHINE_BOTTOM - 24, "none", p["boundary"], rx=16, dash="6 5", width=1.5)
    caps(CX, 52, "YOUR MACHINE", after=[("\u2002 every session runs locally, in its own git worktree, as you",
                                          14, 400, p["muted"])])

    # Coordinator
    c = COORD
    rect(c["x"], c["y"], c["w"], c["h"], p["panel"], p["line"], width=1.5)
    caps(c["x"] + 18, c["y"] + 27, "COORDINATOR SESSION")
    text(c["x"] + 18, c["y"] + 54, "platform-specs", size=18, weight=700,
         after=[(" (anchor repo)", 15, 400, p["muted"])])
    text(c["x"] + 18, c["y"] + 79, "spec · plan · dispatch · marks PRs ready in order", size=14.5, fill=p["muted"])

    # You -> coordinator
    y = c["y"] + c["h"] // 2
    line([(LANE_X + LANE_W, y), (c["x"], y)], p["human"])
    text((BOX_X + c["x"]) / 2 - 8, y - 10, "approve spec & plan", size=14, weight=600,
         fill=p["human"], anchor="middle")

    # Coordinator <-> shared files
    mx = c["x"] + c["w"] // 2
    line([(mx, c["y"] + c["h"]), (mx, BAND["y"])], p["arrow"], start=True)
    text(mx + 14, (c["y"] + c["h"] + BAND["y"]) / 2 + 5, "writes the plan, reads mail", size=14, fill=p["muted"])

    # Shared files
    b = BAND
    rect(b["x"], b["y"], b["w"], b["h"], p["panel"], p["line"], width=1.5)
    caps(b["x"] + 16, b["y"] + 26, "SHARED FILES", after=[("\u2002 plain files in the workspace that every harness can read",
                                                          14, 400, p["muted"])])
    chip_w = (b["w"] - 32 - 3 * 12) / 4
    for i, (title, sub, lock) in enumerate(CHIPS):
        x = b["x"] + 16 + i * (chip_w + 12)
        fill, stroke, color = (p["lock_fill"], p["lock_line"], p["lock"]) if lock else (p["chip"], p["line"], p["text"])
        rect(x, b["y"] + 42, chip_w, 62, fill, stroke, rx=8, width=1.25)
        text(x + 14, b["y"] + 68, title, size=15.5, weight=700, fill=color)
        text(x + 14, b["y"] + 90, sub, size=13.5, fill=p["lock"] if lock else p["muted"])

    # Shared files <-> workers
    top, bottom = b["y"] + b["h"], WORKER_Y
    for x in CENTERS:
        line([(x, top), (x, bottom)], p["arrow"], start=True)
    mid = (top + bottom) / 2 + 5
    text((CENTERS[0] + CENTERS[1]) / 2, mid, "plan · contracts · mail", size=14, fill=p["muted"], anchor="middle")
    text((CENTERS[2] + CENTERS[3]) / 2, mid, "one per repo, in parallel", size=14, fill=p["muted"], anchor="middle")

    # Workers
    for x, repo in zip(WORKER_X, REPOS):
        rect(x, WORKER_Y, WORKER_W, WORKER_H, p["panel"], p["line"], width=1.5)
        caps(x + 16, WORKER_Y + 27, "WORKER SESSION")
        text(x + 16, WORKER_Y + 53, repo, size=17, weight=700)
        text(x + 16, WORKER_Y + 76, ".worktrees/PAY-42", size=13.5, fill=p["muted"], family=MONO)
        w = pill(x + 16, WORKER_Y + 90, "guard", p["chip"], p["line"], p["text"])
        pill(x + 16 + w + 8, WORKER_Y + 90, "stop gate", p["chip"], p["line"], p["text"])

    # Worker -> you: questions
    qy = WORKER_Y + 64
    line([(WORKER_X[0], qy), (LANE_X + LANE_W, qy)], p["human"], dash="5 4")
    text(LANE_X + LANE_W - 14, qy - 20, "answer questions", size=14, weight=600, fill=p["human"], anchor="end")
    text(LANE_X + LANE_W - 14, qy + 26, "workers ask you", size=13.5, fill=p["muted"], anchor="end")
    text(LANE_X + LANE_W - 14, qy + 44, "directly", size=13.5, fill=p["muted"], anchor="end")

    # Workers -> hosts
    for x in CENTERS:
        line([(x, WORKER_Y + WORKER_H), (x, HOST_Y)], p["arrow"])
    mid = (MACHINE_BOTTOM + HOST_Y) / 2 + 5
    text((CENTERS[0] + CENTERS[1]) / 2, mid, "push · draft PR from day one", size=14, fill=p["muted"], anchor="middle")
    text((CENTERS[2] + CENTERS[3]) / 2, mid, "each repo's own host", size=14, fill=p["muted"], anchor="middle")

    # Hosts
    for x, (host, what, local) in zip(WORKER_X, HOSTS):
        rect(x, HOST_Y, WORKER_W, HOST_H, p["panel"], p["boundary"] if local else p["line"],
             dash="5 4" if local else None, width=1.5)
        text(x + WORKER_W / 2, HOST_Y + 30, host, size=15, weight=700, anchor="middle")
        text(x + WORKER_W / 2, HOST_Y + 53, what, size=14, fill=p["muted"], anchor="middle")

    # You -> hosts: review and merge, in plan order
    lx_bus = LANE_X + 40
    line([(lx_bus, HOST_Y + HOST_H), (lx_bus, BUS_Y), (CENTERS[-1], BUS_Y)], p["human"], end=False)
    for x in CENTERS:
        line([(x, BUS_Y), (x, HOST_Y + HOST_H)], p["human"])
    text(CX, BUS_Y + 26, "PRs leave draft in merge order; you review and merge each one",
         size=14, weight=600, fill=p["human"])

    add("</svg>")
    return "\n".join(out) + "\n"


def main():
    for name, palette in PALETTES.items():
        (HERE / f"how-it-works-{name}.svg").write_text(svg(palette), encoding="utf-8")
        print(f"wrote docs/images/how-it-works-{name}.svg")


if __name__ == "__main__":
    main()
