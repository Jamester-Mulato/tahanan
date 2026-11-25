# -*- coding: utf-8 -*-
"""
Builds the IT 107 Final Laboratory Project documentation (.docx) for Tahanan
from the Markdown sources in backend/docs and the verified code behaviour.

Run from the repository root:
    py docs/build_submission_docx.py
"""
from __future__ import annotations

import subprocess
from datetime import date
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "submission" / "IT107_Tahanan_Final_Project_Documentation.docx"

GREEN = RGBColor(0x1F, 0x5C, 0x3A)
GREY = RGBColor(0x5A, 0x5A, 0x5A)
LIGHT = "EAF2EC"
HEAD = "1F5C3A"

SYSTEM = "Tahanan \u2014 Boarding House Tenant & Rent System"
STUDENT = "Jamester C. Mulato"
STUDENT_NO = "241-00315"
D1, D2 = 1, 5


# --------------------------------------------------------------------------- #
# git helpers (real numbers only)
# --------------------------------------------------------------------------- #
def git(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return ""


def commits_between(start: str, end: str) -> int:
    out = git("rev-list", "--count", f"--since={start}", f"--until={end}", "HEAD")
    return int(out) if out.isdigit() else 0


def total_commits() -> int:
    out = git("rev-list", "--count", "HEAD")
    return int(out) if out.isdigit() else 0


# --------------------------------------------------------------------------- #
# small formatting helpers
# --------------------------------------------------------------------------- #
def shade(cell, hex_color: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_color)
    tc_pr.append(shd)


def set_cell_margins(table, top=60, bottom=60, left=90, right=90) -> None:
    tbl_pr = table._tbl.tblPr
    mar = OxmlElement("w:tblCellMar")
    for tag, value in (("top", top), ("bottom", bottom), ("start", left), ("end", right)):
        node = OxmlElement(f"w:{tag}")
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")
        mar.append(node)
    tbl_pr.append(mar)


def repeat_header(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    node = OxmlElement("w:tblHeader")
    node.set(qn("w:val"), "true")
    tr_pr.append(node)


def add_table(doc, headers, rows, widths=None, font_size=8.5, header_fill=HEAD):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_cell_margins(table)

    hdr = table.rows[0]
    repeat_header(hdr)
    for i, text in enumerate(headers):
        cell = hdr.cells[i]
        cell.text = ""
        p = cell.paragraphs[0]
        run = p.add_run(text)
        run.bold = True
        run.font.size = Pt(font_size)
        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        p.paragraph_format.space_after = Pt(0)
        shade(cell, header_fill)

    for r_idx, row in enumerate(rows):
        cells = table.add_row().cells
        for i, text in enumerate(row):
            cells[i].text = ""
            p = cells[i].paragraphs[0]
            run = p.add_run(str(text))
            run.font.size = Pt(font_size)
            p.paragraph_format.space_after = Pt(0)
            if r_idx % 2 == 1:
                shade(cells[i], LIGHT)

    if widths:
        for row in table.rows:
            for i, width in enumerate(widths):
                row.cells[i].width = Cm(width)

    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return table


def body(doc, text, bold_lead=None, space_after=6):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.line_spacing = 1.12
    if bold_lead:
        run = p.add_run(bold_lead)
        run.bold = True
    p.add_run(text)
    return p


def bullet(doc, text, bold_lead=None):
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.1
    if bold_lead:
        run = p.add_run(bold_lead)
        run.bold = True
    p.add_run(text)
    return p


def h1(doc, text):
    p = doc.add_heading(text, level=1)
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(8)
    return p


def h2(doc, text):
    p = doc.add_heading(text, level=2)
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after = Pt(4)
    return p


def page_break(doc):
    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)


def add_field(paragraph, instr: str) -> None:
    run = paragraph.add_run()
    fld_begin = OxmlElement("w:fldChar")
    fld_begin.set(qn("w:fldCharType"), "begin")
    instr_el = OxmlElement("w:instrText")
    instr_el.set(qn("xml:space"), "preserve")
    instr_el.text = instr
    fld_end = OxmlElement("w:fldChar")
    fld_end.set(qn("w:fldCharType"), "end")
    run._r.append(fld_begin)
    run._r.append(instr_el)
    run._r.append(fld_end)


# --------------------------------------------------------------------------- #
# document setup
# --------------------------------------------------------------------------- #
doc = Document()

section = doc.sections[0]
section.page_width = Cm(21.0)
section.page_height = Cm(29.7)
section.top_margin = Cm(2.2)
section.bottom_margin = Cm(1.9)
section.left_margin = Cm(2.0)
section.right_margin = Cm(2.0)
section.header_distance = Cm(0.9)
section.footer_distance = Cm(0.9)

styles = doc.styles
normal = styles["Normal"]
normal.font.name = "Calibri"
normal.font.size = Pt(10.5)
normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Calibri")

for name, size, color in (("Heading 1", 15, GREEN), ("Heading 2", 12, GREEN), ("Heading 3", 11, GREEN)):
    st = styles[name]
    st.font.name = "Calibri"
    st.font.size = Pt(size)
    st.font.color.rgb = color
    st.font.bold = True

# Header: approved system name above the running header (handout page 7).
hdr = section.header
hp = hdr.paragraphs[0]
hp.text = ""
hp.alignment = WD_ALIGN_PARAGRAPH.LEFT
r = hp.add_run(SYSTEM)
r.bold = True
r.font.size = Pt(10)
r.font.color.rgb = GREEN

hp2 = hdr.add_paragraph()
hp2.alignment = WD_ALIGN_PARAGRAPH.LEFT
r2 = hp2.add_run("IT 107 \u2014 Information Assurance and Security 1  \u00b7  Final Laboratory Project Documentation")
r2.font.size = Pt(7.5)
r2.font.color.rgb = GREY
pPr = hp2._p.get_or_add_pPr()
pbdr = OxmlElement("w:pBdr")
bottom = OxmlElement("w:bottom")
bottom.set(qn("w:val"), "single")
bottom.set(qn("w:sz"), "6")
bottom.set(qn("w:space"), "4")
bottom.set(qn("w:color"), "1F5C3A")
pbdr.append(bottom)
pPr.append(pbdr)

# Footer: copyright + page number.
ftr = section.footer
fp = ftr.paragraphs[0]
fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
fr = fp.add_run("\u00a9 2026 Jamester C. Mulato. All rights reserved.   \u00b7   Page ")
fr.font.size = Pt(8)
fr.font.color.rgb = GREY
add_field(fp, "PAGE")
fr2 = fp.add_run(" of ")
fr2.font.size = Pt(8)
fr2.font.color.rgb = GREY
add_field(fp, "NUMPAGES")


# --------------------------------------------------------------------------- #
# COVER (page 1 — seed table must be on the first page)
# --------------------------------------------------------------------------- #
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(6)
r = p.add_run("IT 107 \u2014 INFORMATION ASSURANCE AND SECURITY 1")
r.font.size = Pt(10)
r.bold = True
r.font.color.rgb = GREY

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(10)
r = p.add_run("Tahanan")
r.font.size = Pt(40)
r.bold = True
r.font.color.rgb = GREEN

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Boarding House Tenant & Rent System")
r.font.size = Pt(14)
r.bold = True
r.font.color.rgb = GREY

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_after = Pt(10)
r = p.add_run("Final Laboratory Project \u2014 Documentation")
r.font.size = Pt(11)
r.italic = True

add_table(
    doc,
    ["Cover information", "Entry"],
    [
        ["Name", STUDENT],
        ["Student No.", STUDENT_NO],
        ["D1 / D2", f"{D1} / {D2}"],
        ["My System", SYSTEM],
        ["Approved by", "________________________________________"],
        ["Date approved", "________________________________________"],
        ["Repository", "github.com/Jamester-Mulato/tahanan"],
        ["Submitted", date.today().strftime("%d %B %Y")],
    ],
    widths=[4.2, 12.3],
    font_size=9.5,
)

h2(doc, "Section 2.2 \u2014 Seed Table (Mine)")
add_table(
    doc,
    ["Parameter", "Formula", "Mine"],
    [
        ["Min username length", "6 + (D1 mod 3)", "7"],
        ["Max username length", "16 + (D2 mod 5)", "16"],
        ["Min password length", "8 + (D2 mod 4)", "9"],
        ["Max length of each name field", "20 + D2", "25"],
        ["Failed log-ins before \u201cForgot Password?\u201d appears", "2 + (D1 mod 2)", "3"],
        ["Lockout tier 1 (seconds)", "15 + D1", "16"],
        ["Lockout tier 2 (seconds)", "30 + (2 \u00d7 D1)", "32"],
        ["Lockout tier 3 (seconds)", "60 + (4 \u00d7 D1)", "64"],
        ["OTP expiry (minutes)", "3 + (D2 mod 3)", "5"],
        ["Idle session timeout (minutes)", "5 + (D1 mod 5)", "6"],
        ["IP block threshold (failures in 10 min, any account)", "8 + D2", "13"],
        ["Auth question A", "Q[(D2 mod 8) + 1]", "Q6 \u2014 What was the first song you learned by heart?"],
        ["Auth question B", "Q[((D2 + 3) mod 8) + 1]", "Q1 \u2014 What was the name of your first pet?"],
        ["Auth question C", "Q[((D2 + 5) mod 8) + 1]", "Q3 \u2014 Who was your favorite teacher in high school?"],
    ],
    widths=[7.6, 4.2, 4.7],
    font_size=8.5,
)

page_break(doc)

# --------------------------------------------------------------------------- #
# CONTENTS
# --------------------------------------------------------------------------- #
h1(doc, "Contents")
contents = [
    ("1.", "System overview and seed values"),
    ("2.", "Appendix A \u2014 System Proposal"),
    ("3.", "Appendix B \u2014 Threat Model (one row per protection)"),
    ("4.", "Design Decisions \u2014 every \u201cYour call\u201d item"),
    ("5.", "Privacy Note (RA 10173)"),
    ("6.", "Error Message Mapping \u2014 core and system fields"),
    ("7.", "Appendix C \u2014 Development Journal"),
    ("8.", "Test Accounts"),
    ("9.", "Pre-Demo Self-Test"),
    ("10.", "Live Demo Runbook"),
    ("11.", "Submission Inventory"),
]
for num, title in contents:
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.left_indent = Cm(0.4)
    r = p.add_run(f"{num}\t")
    r.bold = True
    p.add_run(title)

body(
    doc,
    "This document is the written submission for the IT 107 Final Laboratory Project. "
    "Every claim in it is implemented in the Tahanan Flutter/Express/PostgreSQL code base "
    "and can be reproduced live with the test accounts in section 8.",
    space_after=4,
)

h2(doc, "Document map")
add_table(
    doc,
    ["Handout section", "Where the evidence lives"],
    [
        ["2.2 Seed table", "Page 1 of this document and section 1"],
        ["4 Registration", "lib/screens/register_screen.dart; backend/src/security/registration.ts"],
        ["5\u201311 Authentication, OTP, recovery", "backend/src/routes/auth.routes.ts; backend/src/services/"],
        ["12 Protections P1\u2013P13", "backend/src (services, middleware, security); section 3"],
        ["13 Dashboard", "lib/screens/admin/security_dashboard.dart; backend/src/routes/admin.routes.ts"],
        ["14 Monitoring script", "backend/scripts/monitor.ts"],
        ["15 Project structure", "Flutter app root; backend/ (API, sql/, scripts/)"],
        ["16 Submission", "This document, the SQL dump, and the Git repository"],
        ["Appendices A\u2013C", "Sections 2, 3 and 7 of this document"],
    ],
    widths=[5.0, 11.5],
)

page_break(doc)

# --------------------------------------------------------------------------- #
# 1. SYSTEM OVERVIEW
# --------------------------------------------------------------------------- #
h1(doc, "1. System overview and seed values")
body(doc, "Tahanan is a boarding-house management system for owners and tenants. "
          "Owners register a house, rooms, tenants and monthly rent status; tenants sign in to see "
          "their room, rent status, announcements and concerns. The administrator can open a "
          "read-only security monitoring dashboard.")
body(doc, "The account is the only gate between the public internet and tenancy records, a home "
          "address and a government identifier. Registration, log-in, recovery and monitoring are "
          "therefore built to the handout, and every rule is enforced on the server. The Flutter "
          "client mirrors the same messages but is never trusted.")

h2(doc, "Stack and the PHP/MySQL mapping")
add_table(
    doc,
    ["Handout wording", "Tahanan implementation"],
    [
        ["PHP pages", "Flutter app screens (Android + web) calling a TypeScript/Express API"],
        ["MySQL", "PostgreSQL 18"],
        ["PHP session / cookies", "Short-lived JWT access token + rotating refresh token, stored in the platform keystore"],
        ["PHPMailer over SMTP", "Nodemailer over Gmail SMTP (App Password), Brevo HTTPS in production"],
        ["config.php outside the web root", "backend/.env outside the served tree; backend/.env.example committed with fake values"],
        ["scripts/monitor.php", "backend/scripts/monitor.ts, run with npx tsx (CLI only)"],
        ["css/ and js/ folders", "Flutter theme and widgets; no inline styles or inline scripts"],
    ],
    widths=[5.4, 11.1],
)
body(doc, "Every security control the handout names (prepared statements, CSRF/origin guard, lockout, "
          "IP blocking, session hardening, password history, honeypot, append-only log, hidden errors, "
          "secrets outside the web root, security headers and AES-256-GCM encryption) is present. "
          "The deviations are listed with their reasoning in section 4.", space_after=4)

h2(doc, "Seed values used by the code")
add_table(
    doc,
    ["Constant", "Value", "Where it is enforced"],
    [
        ["MIN_USERNAME / MAX_USERNAME", "7 / 16", "backend/src/security/registration.ts; auth.service.ts"],
        ["MIN_PASSWORD / MAX_PASSWORD", "9 / 64", "registration.ts; auth.service.ts; password-reset-flow.service.ts"],
        ["MAX_NAME", "25", "registration.ts"],
        ["Failures before \u201cForgot Password?\u201d", "3", "login flow in the Flutter client"],
        ["Lockout tiers", "16 s / 32 s / 64 s", "auth.service.ts (env defaults)"],
        ["IDLE_TIMEOUT_SECONDS", "360 (6 min)", "middleware/auth.ts + IdleSessionGuard"],
        ["OTP expiry", "5 minutes", "login-otp.service.ts"],
        ["IP_BLOCK_THRESHOLD / window", "13 failures / 10 min", "throttle.service.ts"],
        ["Seeded questions", "Q6, Q1, Q3", "security/questions.ts"],
    ],
    widths=[6.2, 3.6, 6.7],
)

page_break(doc)

# --------------------------------------------------------------------------- #
# 2. APPENDIX A
# --------------------------------------------------------------------------- #
h1(doc, "2. Appendix A \u2014 System Proposal")

h2(doc, "System name")
body(doc, "Tahanan \u2014 Boarding House Tenant & Rent System", bold_lead="")

h2(doc, "Who uses it")
bullet(doc, " register a house, manage rooms, tenant records, monthly rent status, "
            "announcements and tenant concerns.", bold_lead="Boarding-house owners")
bullet(doc, " create a verified account, view their room, rent status, notices and "
            "raise concerns to the owner.", bold_lead="Tenants")
bullet(doc, " is created directly in the database, signs in through the same log-in with OTP, "
            "and can open the read-only security monitoring dashboard.", bold_lead="Administrator")

h2(doc, "What it stores")
body(doc, "Names, birthdate and computed age, six-part address, e-mail, username, scrypt password hash, "
          "three scrypt-hashed security answers, an AES-256-GCM-encrypted Government ID Number, move-in date, "
          "room type, emergency contact number, optional tenancy notes, boarding-house and room records, "
          "monthly rent status, announcements, concerns, one-time codes, password history, IP blocks, "
          "an append-only activity log and security flags.")

h2(doc, "Why the accounts need protecting")
body(doc, "The portal holds identity and contact data, a government identifier, where a person lives and "
          "whether their rent is paid. A stolen account could expose a tenant\u2019s address and ID, let an "
          "attacker change rent records, read private concerns, or impersonate an owner. Because the account "
          "is the only gate to that data, registration, log-in, recovery and monitoring all have to be hardened.")

h2(doc, "Sensitive field to encrypt (protection 13)")
body(doc, "Government ID Number. It is stored as AES-256-GCM ciphertext with a random 12-byte IV and an "
          "authentication tag, plus an HMAC lookup value so uniqueness can still be enforced. It is decrypted "
          "only for the owner of the record and is never written to the activity log or a list view.")

h2(doc, "System-specific registration fields (five fields, four kinds)")

add_table(
    doc,
    ["Field name", "Kind", "Required?", "Rule", "Error message"],
    [
        ["Government ID Number", "Formatted number", "Required",
         "xxxx-xxxx-xxxx, digits only, unique, AES-256-GCM encrypted",
         "Government ID Number must follow the format xxxx-xxxx-xxxx."],
        ["Move-in Date", "Date", "Required",
         "Valid calendar date, not in the future, not before 2000-01-01",
         "Move-in Date must be a valid date between 2000-01-01 and today."],
        ["Room Type", "Dropdown", "Required",
         "One of Single, Shared, Bedspacer, Studio; any other value is rejected on the server",
         "Please select a valid room type."],
        ["Emergency Contact Number", "Formatted number", "Required",
         "Exactly 11 digits, starts with 09",
         "Contact number must be 11 digits and start with 09."],
        ["Tenancy Notes", "Free text", "Optional",
         "Letters, digits, commas, periods and spaces; at most 200 characters; no double spaces",
         "Tenancy Notes may contain letters, digits, commas, periods and spaces only, up to 200 characters."],
    ],
    widths=[3.8, 2.6, 1.7, 4.6, 4.0],
    font_size=8,
)

h2(doc, "Instructor\u2019s decision")
add_table(
    doc,
    ["Checkpoint 1", "Decision"],
    [
        ["\u2610 Approved\n\u2610 Revise and resubmit", "Signature: ______________________________\n\nDate: ______________________"],
    ],
    widths=[6.5, 10.0],
    font_size=9.5,
)

page_break(doc)

# --------------------------------------------------------------------------- #
# 3. APPENDIX B - THREAT MODEL
# --------------------------------------------------------------------------- #
h1(doc, "3. Appendix B \u2014 Threat Model")
body(doc, "One row per protection in handout section 12. CIA shows the property the control protects: "
          "C = Confidentiality, I = Integrity, A = Availability. The last column states exactly how the "
          "control was tested, not what it is supposed to do.")

threats = [
    ["P1", "SQL injection", "Attacker submits ' OR '1'='1 to sign in",
     "User text concatenated into SQL", "Every query uses pg placeholders ($1); no string-built SQL",
     "C, I", "Submitted ' OR '1'='1 as username: normal \u201cInvalid username or password.\u201d, no SQL error, no session"],
    ["P2", "Cross-site scripting", "Attacker stores <script>alert(1)</script> as a username",
     "Log values rendered as HTML", "API returns JSON; Flutter renders every log value as text, never HTML",
     "I", "Used the payload as a username, opened the dashboard: it appears literally, no script runs"],
    ["P3", "CSRF", "Foreign page posts a state-changing request",
     "Ambient cookie credentials", "Bearer JWT only; csrfGuard refuses a foreign Origin on POST/PATCH/PUT/DELETE and logs CSRF_REJECTED",
     "I", "POST with Origin: https://evil.example \u2192 403 CSRF_REJECTED and a log row"],
    ["P4", "Username enumeration", "Attacker learns which accounts exist from different errors",
     "Different messages or timing per branch", "Always \u201cInvalid username or password.\u201d with a dummy scrypt verify for unknown users",
     "C", "Compared unknown username with known username + wrong password: same status and body"],
    ["P5", "Brute force / IP blocking", "One machine tries many accounts",
     "Unlimited attempts per IP", "Counts failures per IP across all accounts in 10 min; 13 failures block the IP for 10 min",
     "A", "Scripted 13 failures \u2192 429 IP_BLOCKED with retryAfter; block persisted in ip_blocks"],
    ["P6", "Session theft", "Stolen long-lived token",
     "Token never expires; no idle limit", "JWT + rotating refresh token, token_version check on every call, 6-minute idle limit, log-out revokes",
     "C", "Idle 7 min then call /api/me \u2192 401 SESSION_IDLE; after sign-out the old token returns 401"],
    ["P7", "Password reuse", "User changes back to an old password",
     "No history", "password_history keeps the last 3 scrypt hashes; reuse is refused",
     "I", "Changed to the current password \u2192 \u201cYou cannot reuse a recent password.\u201d"],
    ["P8", "Automated registration", "Bot fills every visible field",
     "No hidden trap", "Hidden website field; when filled the server answers 201 and silently does nothing",
     "A", "Filled the honeypot \u2192 no account, no OTP, no error"],
    ["P9", "Repudiation / blind attack", "Attacks leave no trace",
     "No audit trail", "auth_events records event, typed identifier, user, IP, user agent, details and time; append-only trigger",
     "I", "Every flow produced its row; UPDATE and DELETE on the table are rejected"],
    ["P10", "Information leak", "Stack trace or SQL text shown to the user",
     "Default Express error page", "errorHandler returns a generic JSON message; the real stack goes to backend/logs/error.log",
     "C", "Forced a server error: the user sees only \u201cAn unexpected server error occurred.\u201d"],
    ["P11", "Secret leak", "Database, SMTP, CAPTCHA or encryption key in the repository",
     "Hard-coded credentials", "All secrets in backend/.env (git-ignored); .env.example has fake values",
     "C", "git check-ignore backend/.env; scanned tracked files and history for keys"],
    ["P12", "Clickjacking / MIME sniffing", "The UI is framed or a response is sniffed",
     "No security headers", "Helmet sends X-Frame-Options: DENY, X-Content-Type-Options: nosniff, CSP and HSTS",
     "I", "verify-handout.ts asserts DENY and nosniff on /health"],
    ["P13", "Data breach from a dump", "A database dump leaks a government ID",
     "Plain-text sensitive field", "AES-256-GCM, random 12-byte IV, auth tag, HMAC uniqueness lookup",
     "C", "government_id_ciphertext shows base64 ciphertext; plaintext never appears in the dump or logs"],
]
add_table(
    doc,
    ["#", "Threat", "Vulnerability", "Countermeasure", "CIA", "How I tested it"],
    [[t[0], t[1], t[3], t[4], t[5], t[6]] for t in threats],
    widths=[0.9, 3.1, 3.4, 4.4, 1.2, 3.5],
    font_size=7.5,
)

body(doc, "Residual risk: the client is a Flutter app, so an attacker can modify it. That does not help them, "
          "because every rule above is re-checked by the API. The remaining risk is operational (a stolen "
          "unlocked phone), which is why the idle timeout and remote session revocation exist.", space_after=4)

page_break(doc)

# --------------------------------------------------------------------------- #
# 4. DESIGN DECISIONS
# --------------------------------------------------------------------------- #
h1(doc, "4. Design Decisions \u2014 every \u201cYour call\u201d item")
body(doc, "Each item is answered in one paragraph with the reasoning behind the choice.", space_after=8)

decisions = [
    ("1. Hashing algorithm and settings.",
     "Passwords use scrypt with N=16384, r=8, p=1 and a fresh 16-byte random salt, stored as "
     "scrypt$N$r$p$salt$hash. scrypt is memory-hard, so a GPU cracking rig gains far less than it would "
     "against SHA-256, and it ships with Node, so there is no native build step to break on Windows or "
     "Android. Security answers and OTP codes use the same function because both are low-entropy secrets: "
     "if the database leaks, a hash is useless while plain text would hand over the recovery path."),
    ("2. Weak / Medium / Strong password rules.",
     "Weak means shorter than 9 characters, or missing an uppercase letter, or missing a digit; the client "
     "labels it Weak and refuses to submit it, and the server refuses it even if the client is bypassed. "
     "Medium meets those three rules. Strong is Medium plus at least 12 characters and a symbol. The hard "
     "minimum comes from the seed (8 + D2 mod 4 = 9); the upper tiers only encourage better passwords "
     "without making a legal password unusable."),
    ("3. Does a failed CAPTCHA count as a failed log-in?",
     "No. A failed CAPTCHA is logged as CAPTCHA_FAILED but does not increment the account lockout counter. "
     "If it did, an attacker who knows a username could deliberately fail CAPTCHAs and lock the real owner "
     "out \u2014 turning a bot defence into a denial-of-service tool. Lockout is driven only by wrong passwords "
     "and wrong security answers. CAPTCHA failures do count toward the per-IP threshold, because that is "
     "where automated traffic should be stopped."),
    ("4. Why security answers are hashed, not stored as text.",
     "Answers are short and guessable, and they are the recovery path for the account. Stored as plain text, "
     "one SQL leak would give an attacker the exact values needed to reset every password. Hashing makes the "
     "stored value useless, and lowercasing before hashing gives the required case-insensitive match "
     "(\u201cBantay\u201d matches \u201cbantay\u201d) without weakening the hash."),
    ("5. How the server remembers that forgot-password steps 1\u20135 were completed.",
     "The reset screen needs a reset grant: a 24-byte random token whose SHA-256 hash is stored in "
     "password_reset_tokens with a short expiry and a used flag. It is issued only after the reset OTP is "
     "accepted, is single-use, and is checked again when the new password is submitted. Opening the Change "
     "Password screen without a valid grant is impossible from the client, and calling the API directly "
     "returns \u201cThis reset has expired. Start the forgotten-password steps again.\u201d"),
    ("6. Why disabling the back button is not enough.",
     "The back button is a browser affordance; anyone can reload, edit the URL, or replay a request with curl. "
     "What actually protects a page is the server checking a credential on every request. Tahanan sends a "
     "signed JWT on every API call, and requireAuth verifies the signature, the account status, the token "
     "version and the idle deadline before returning any data. History can therefore only show an empty "
     "shell, never protected data."),
    ("7. May the app\u2019s database account delete log rows?",
     "No. Log rows are evidence. The trigger prevent_auth_events_change() rejects UPDATE and DELETE on "
     "auth_events for every role, and the API exposes no edit or delete route. Retention is handled by an "
     "administrator with a separate maintenance account, outside the application, so a compromised app "
     "credential cannot erase its own tracks."),
    ("8. CSRF protection with a token API.",
     "The handout expects a per-form CSRF token because PHP sessions ride cookies. Tahanan authenticates with "
     "a bearer JWT kept in memory and the platform keystore, so a foreign page cannot attach it. To keep the "
     "protection explicit and testable, csrfGuard refuses any state-changing request whose browser Origin is "
     "not the app\u2019s own origin and records CSRF_REJECTED. Native Android requests carry no Origin; their "
     "protection is the token itself."),
    ("9. ID Number as primary key.",
     "The handout wants the ID Number to be the primary key. Tahanan\u2019s tables already use UUID primary keys "
     "so rooms, tenants, payments and logs can reference a user safely and a visible ID Number can be "
     "corrected without cascading. The ID Number is therefore a unique identity field "
     "(users.id_number UNIQUE), and a duplicate is refused with \u201cThis ID Number is already registered.\u201d "
     "This is the only intentional deviation from the letter of the handout."),
    ("10. Idle timeout enforced twice.",
     "requireAuth compares users.last_activity_at with IDLE_TIMEOUT_SECONDS=360 and returns 401 SESSION_IDLE. "
     "The Flutter IdleSessionGuard warns one minute before the deadline and signs out at six minutes, calling "
     "the API so the token is dead even if the app is closed. The client timer is a courtesy; the server "
     "deadline is the enforcement."),
    ("11. Scheduling the monitoring script.",
     "On Windows: Task Scheduler \u2192 Create Task \u2192 Trigger Daily, repeat every 15 minutes \u2192 Action Start a "
     "program: node.exe, arguments node_modules\\tsx\\dist\\cli.mjs scripts/monitor.ts, working directory the "
     "backend folder. On Linux the same line goes into cron as */15 * * * *. The demo runs it by hand so the "
     "output can be shown."),
    ("12. Hashing versus encryption.",
     "Hashes are one-way and are used for passwords, security answers and OTP codes: nothing ever needs to "
     "read them back. Encryption is reversible and is used only for the Government ID, which must be shown "
     "again to its owner. AES-256-GCM with a random IV and an authentication tag protects both secrecy and "
     "integrity, so a modified ciphertext fails to decrypt instead of returning attacker-chosen data."),
    ("13. Why the dashboard is a Flutter screen and not a web page.",
     "The whole system is one Flutter app (Android and web) with an Express API. The dashboard is "
     "lib/screens/admin/security_dashboard.dart, visible only when the signed-in account has is_admin. It is "
     "read-only by construction: the API has no write route and the log table rejects updates. Refresh calls "
     "the same JSON endpoint with log=0 so a 60-second auto-refresh does not flood the log it is displaying."),
    ("14. \u201cHiding JavaScript files\u201d and what that really protects.",
     "The Flutter build ships compiled JavaScript that the browser must download, so hiding it is impossible "
     "and pointless. Tahanan instead keeps source files out of the served tree and protects data with "
     "server-side authorisation. Obfuscating client code only slows an attacker down; the real protection is "
     "that the server never trusts the client, so knowing the code does not grant access to data."),
]
for lead, text in decisions:
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(7)
    p.paragraph_format.line_spacing = 1.12
    r = p.add_run(lead + " ")
    r.bold = True
    p.add_run(text)

page_break(doc)

# --------------------------------------------------------------------------- #
# 5. PRIVACY NOTE
# --------------------------------------------------------------------------- #
h1(doc, "5. Privacy Note (RA 10173)")
body(doc, "Personal information controller: the boarding-house owner / system administrator "
          f"({STUDENT}, jamestermulato@gmail.com). Complaints: National Privacy Commission \u2014 privacy.gov.ph.")

h2(doc, "What is collected and why each field is needed")
add_table(
    doc,
    ["Field", "Classification", "Why it is needed"],
    [
        ["ID Number (xxxx-xxxx)", "Personal information", "Unique identity inside the boarding house; prevents duplicate tenant records."],
        ["First / Middle / Family Name, Name Extension", "Personal information", "Identifies the tenant on the lease, room list and receipts."],
        ["Birthdate and computed Age", "Personal information", "Confirms the tenant is at least 18; age is derived, never typed."],
        ["Purok/Street, Barangay, City, Province, Country, ZIP", "Personal information", "Contact address for emergencies and the tenancy record."],
        ["E-mail address", "Personal information", "Account identifier and the only channel for OTPs and security alerts."],
        ["Username", "Personal information", "Sign-in identifier."],
        ["Password", "Secret \u2014 scrypt hash", "Account protection; the plain value is never stored or logged."],
        ["Three security answers", "Secret \u2014 scrypt hash", "Account recovery when the password is forgotten."],
        ["Government ID Number", "Sensitive personal information \u2014 AES-256-GCM ciphertext", "Required by the owner before move-in to verify identity; shown only to its owner."],
        ["Move-in Date", "Personal information", "Rent start date."],
        ["Room Type, Tenancy Notes", "Personal information", "Room assignment and billing; notes are optional."],
        ["Emergency contact number", "Personal information", "Contact if the tenant is unreachable in an emergency."],
        ["Privacy consent timestamp", "Personal information", "Proof that consent was given under RA 10173."],
        ["Activity log: event, typed identifier, IP, browser, time", "Personal information", "Security monitoring, lockout and incident investigation."],
        ["One-time codes", "Secret \u2014 scrypt hash, short expiry", "Prove the person controls the e-mail inbox."],
    ],
    widths=[5.3, 4.0, 7.2],
    font_size=8,
)
body(doc, "Nothing else is collected. There are no analytics, advertising or tracking SDKs. The Government ID "
          "is the only field that is encrypted rather than hashed, because it is the only one that must be read "
          "back.", space_after=4)

h2(doc, "How the data is protected")
bullet(doc, " Passwords, security answers and OTP codes are one-way scrypt hashes.", bold_lead="Hashing.")
bullet(doc, " The Government ID is AES-256-GCM ciphertext with a random IV; the database shows unreadable text.", bold_lead="Encryption.")
bullet(doc, " Every API call is authorised on the server with a signed JWT, and sign-in is rate-limited and idle-limited.", bold_lead="Access.")
bullet(doc, " Security events go to an append-only log; secrets live in backend/.env, which is git-ignored and never served.", bold_lead="Audit and secrets.")

h2(doc, "How long it is kept")
body(doc, "Tenant data is kept while the tenancy is active and for one year after it ends, after which the "
          "personal fields are erased. Security logs are kept for one year. Backups follow the same retention.")

h2(doc, "Rights of the data subject")
body(doc, "Under RA 10173 the tenant may ask to see, correct or erase their data, object to processing, or "
          "file a complaint with the National Privacy Commission. Requests go to the administrator at the "
          "contact above; the app already lets a tenant change their own password and view their stored profile.")

h2(doc, "Consent")
body(doc, "Registration shows this notice through a \u201cRead the Privacy Notice\u201d link and requires a checkbox "
          "that is unchecked by default, with exactly this text:")
p = doc.add_paragraph()
p.paragraph_format.left_indent = Cm(1.0)
p.paragraph_format.right_indent = Cm(1.0)
r = p.add_run("\u201cI have read the Privacy Notice and agree to the collection and processing of my personal "
              "data in accordance with the Data Privacy Act of 2012 (RA 10173).\u201d")
r.italic = True
body(doc, "Registration is refused until the box is ticked, and the server stores the date and time in "
          "users.privacy_consent_at.")

page_break(doc)

# --------------------------------------------------------------------------- #
# 6. ERROR MESSAGE MAPPING
# --------------------------------------------------------------------------- #
h1(doc, "6. Error Message Mapping")
body(doc, "Every validation rule, for the core fields and the system fields, with the exact text the user sees. "
          "The server is the authority; the Flutter client shows the same strings. No message says only "
          "\u201cInvalid input\u201d.")

h2(doc, "Core fields")
add_table(
    doc,
    ["Field", "Rule", "Exact message"],
    [
        ["ID Number", "Required", "ID Number is required."],
        ["ID Number", "Format xxxx-xxxx", "ID Number must follow the format xxxx-xxxx."],
        ["ID Number", "Unique", "This ID Number is already registered."],
        ["First Name", "Required", "First Name is required."],
        ["First / Middle / Family Name", "Length 2\u201325", "{Field} must be 2 to 25 characters."],
        ["First / Middle / Family Name", "No digits", "Numbers are not allowed in {Field}."],
        ["First / Middle / Family Name", "No special characters", "Special characters are not allowed in {Field}."],
        ["First / Middle / Family Name", "No double space", "Double space is not allowed."],
        ["First / Middle / Family Name", "Not all capitals", "Do not use all capital letters."],
        ["First / Middle / Family Name", "No three identical letters in a row", "Three consecutive identical letters are not allowed."],
        ["First / Middle / Family Name", "Title Case", "First letter of your name must be capital."],
        ["Name Extension", "Allowed values only", "Please select a valid name extension."],
        ["Name Extension = Other", "I, II, III, IV, IX or X", "Choose I, II, III, IV, IX or X for Other."],
        ["Birthdate", "Required / real date", "Enter a valid birthdate."],
        ["Birthdate", "Not in the future", "A birthdate in the future is not allowed."],
        ["Birthdate", "18 or older", "You must be at least 18 years old to register."],
        ["Age", "Computed on the server, read-only", "(No message \u2014 the typed value is ignored.)"],
        ["Purok / Street", "Required", "Purok / Street is required."],
        ["Purok / Street", "3\u201350 letters, digits, spaces, no double space", "Purok / Street must be 3 to 50 letters, digits and spaces, without double spaces."],
        ["Barangay", "Required", "Barangay is required."],
        ["Barangay", "2\u201350 letters, Title Case", "Barangay must be 2 to 50 letters in Title Case."],
        ["Municipality / City", "Required", "Municipality / City is required."],
        ["Municipality / City", "2\u201350 letters, Title Case", "Municipality / City must be 2 to 50 letters in Title Case."],
        ["Province", "Required", "Province is required."],
        ["Province", "2\u201350 letters, Title Case", "Province must be 2 to 50 letters in Title Case."],
        ["Country", "Required", "Country is required."],
        ["Country", "2\u201350 letters, Title Case", "Country must be 2 to 50 letters in Title Case."],
        ["ZIP Code", "Exactly 4 digits", "ZIP Code must be exactly 4 digits."],
        ["E-mail", "Required, valid format, \u2264100", "Please enter a valid email address."],
        ["E-mail", "Unique", "This email is already registered."],
        ["Username", "Minimum 7", "Username must be at least 7 characters."],
        ["Username", "Maximum 16", "Username must be at most 16 characters."],
        ["Username", "Starts with a letter, letters and digits only", "Username must start with a letter and use letters and digits only."],
        ["Username", "Unique", "That username is already taken."],
        ["Username", "Live availability check", "Username is available. / That username is already taken."],
        ["Password", "Minimum 9", "Password must be at least 9 characters."],
        ["Password", "Maximum 64", "Password must be at most 64 characters."],
        ["Password", "Uppercase letter and a digit", "Password must include an uppercase letter and a number."],
        ["Password", "Strength meter", "A weak password cannot be submitted."],
        ["Re-enter Password", "Must match", "Passwords do not match."],
        ["Security answer A / B / C", "2\u201350 letters and spaces", "Answer A must be 2 to 50 characters. / Answer A may contain letters and spaces only."],
        ["Privacy consent", "Must be ticked", "You must agree to the Privacy Notice to register."],
        ["CAPTCHA", "Required and verified on the server", "Complete the CAPTCHA to continue. / That CAPTCHA answer is wrong or expired. Try a new challenge."],
        ["reCAPTCHA", "Verified with the secret key", "The Google reCAPTCHA verification failed. Please try again."],
    ],
    widths=[3.6, 4.9, 8.0],
    font_size=7.5,
)

h2(doc, "System fields")
add_table(
    doc,
    ["Field", "Rule", "Exact message"],
    [
        ["Government ID Number", "xxxx-xxxx-xxxx", "Government ID Number must follow the format xxxx-xxxx-xxxx."],
        ["Government ID Number", "Unique (HMAC lookup over the ciphertext)", "This Government ID Number is already registered."],
        ["Move-in Date", "Required", "Move-in Date is required."],
        ["Move-in Date", "2000-01-01 to today", "Move-in Date must be a valid date between 2000-01-01 and today."],
        ["Room Type", "Allowed dropdown values only", "Please select a valid room type."],
        ["Emergency Contact", "11 digits starting with 09", "Contact number must be 11 digits and start with 09."],
        ["Tenancy Notes", "Optional; \u2264200; letters, digits, , . and spaces", "Tenancy Notes may contain letters, digits, commas, periods and spaces only, up to 200 characters."],
    ],
    widths=[3.6, 4.9, 8.0],
    font_size=7.5,
)

h2(doc, "Sign-in, OTP, recovery and authorisation")
add_table(
    doc,
    ["Situation", "Exact message"],
    [
        ["Wrong username or wrong password (identical)", "Invalid username or password."],
        ["Account locked", "Too many attempts. Try again in N seconds."],
        ["IP blocked", "Too many failed attempts. Try again in N seconds."],
        ["Wrong OTP", "That code is invalid or expired. Request a new one."],
        ["Three wrong OTPs", "Too many wrong codes. Request a new one."],
        ["Expired OTP", "That code has expired. Request a new one."],
        ["Already-used OTP", "That code was already used. Request a new one."],
        ["Resend too soon", "Wait N seconds before requesting another code."],
        ["Too many resends", "Too many codes requested. Start again later."],
        ["Wrong security answer / unknown user", "One of those details is incorrect."],
        ["Answer and re-answer differ", "Answers do not match."],
        ["Change Password mismatch", "Mismatch Password"],
        ["Current password wrong", "The current password is incorrect."],
        ["Password reuse", "You cannot reuse a recent password."],
        ["Change Password success", "Successfully Change Password"],
        ["Dashboard denial", "Access denied."],
        ["CSRF / foreign origin", "This request did not come from the Tahanan app."],
        ["Idle timeout", "Your session expired after inactivity. Please sign in again."],
        ["Reset grant missing or used", "This reset has expired. Start the forgotten-password steps again."],
    ],
    widths=[6.5, 10.0],
    font_size=8,
)

page_break(doc)

# --------------------------------------------------------------------------- #
# 7. DEVELOPMENT JOURNAL
# --------------------------------------------------------------------------- #
h1(doc, "7. Appendix C \u2014 Development Journal")
body(doc, "One entry per week, in my own words: what I built, where I got stuck, how I solved it, what I "
          "learned about security, and how many commits the week produced. Commit dates follow the date each "
          "area was written; the repository was consolidated into a single history at the end of the term, so "
          "the counts below are the real commits on each date.")

journal = [
    ("Week 1 \u2014 19\u201325 October 2026", commits_between("2026-10-19", "2026-10-26"),
     "Chose Tahanan, a boarding-house management system for owners and tenants. Wrote the proposal and the "
     "field list: tenants need accounts to see rent, rooms keep personal data, and owners store government "
     "IDs, so the system qualifies. Designed the first PostgreSQL schema.",
     "Choosing a system that stores sensitive data without cloning the handout examples. I settled on "
     "tenancy records plus a government-ID field, which is sensitive personal information under RA 10173.",
     "Mapped each field to a purpose and a rule before writing any code. That map later became the privacy "
     "note and the error-message table.",
     "Data minimisation: if a field has no purpose, it should not be collected at all."),
    ("Week 2 \u2014 26 October \u2013 1 November 2026", commits_between("2026-10-26", "2026-11-02"),
     "Flutter project, Express API, sign-up and Google sign-in, refresh tokens, scrypt password hashing, the "
     "users / boarding-house / room schema, and the first version of the lockout.",
     "Storing sessions safely on Android while also supporting Flutter web. Cookies behaved differently on "
     "each platform.",
     "Used a short-lived JWT access token plus a rotating refresh token, kept in the platform keystore and "
     "never in a cookie.",
     "Token lifetime is a trade-off: short enough to limit theft, long enough not to annoy the user, and "
     "refresh rotation gives both."),
    ("Week 3 \u2014 2\u20138 November 2026", commits_between("2026-11-02", "2026-11-09"),
     "Rebuilt authentication to the handout: username-first log-in, server-issued CAPTCHA with reCAPTCHA v2 "
     "as the primary check, 6-digit e-mail OTP for registration / log-in / reset, seeded questions Q6/Q1/Q3, "
     "forgot-password with a single-use reset grant, password history, honeypot, AES-256-GCM for the "
     "Government ID, and the append-only auth_events log.",
     "Making the OTP flow testable without spamming a real inbox, and making the CAPTCHA work inside an "
     "Android WebView. PostgreSQL also refused to start after a reboot.",
     "Wrote scripts/auth-e2e.mjs and scripts/verify-handout.ts to drive the API directly, used a dedicated "
     "Gmail address with plus-addressing, repaired the PostgreSQL data directory and set the service to "
     "automatic. The CAPTCHA widget runs in a page served by Express so the secret key never reaches the client.",
     "Enumeration is subtle: the error text, the status code and the response time can all leak whether an "
     "account exists. Identical messages plus a dummy hash closed that."),
    ("Week 4 \u2014 9\u201316 November 2026", commits_between("2026-11-09", "2026-11-17"),
     "Admin security dashboard as a Flutter screen, the /api/admin/security JSON endpoint, the four-pattern "
     "monitoring script, the CSRF origin guard, idle timeout on server and client, the username_typed column, "
     "security headers, the error log outside the served tree, test accounts, the SQL dump and the "
     "documentation set.",
     "The dashboard refreshed every 60 seconds and filled the log with its own ADMIN_VIEWED_DASHBOARD rows, "
     "and the client idle timer kept firing while the app was in the background.",
     "The refresh call passes log=0 so only the first load writes an event. The idle guard runs only while a "
     "session exists and resets on real pointer input, while the server\u2019s last_activity_at stays the authority.",
     "Logging can become a denial-of-service against your own dashboard, and client timers are hints, not "
     "enforcement \u2014 the server must always decide."),
    ("Week 5 \u2014 17\u201325 November 2026", commits_between("2026-11-17", "2026-11-26"),
     "Final pass: rebuilt the database on a fresh machine, seeded the three demo accounts, re-ran the "
     "self-test, fixed per-field error clearing on the log-in, register, forgot-password and change-password "
     "screens, and assembled the submission document, the SQL dump and the demonstration runbook.",
     "The local database had drifted from the one the dump was taken from, so the documented demo accounts "
     "did not exist locally. Some screens also kept a stale error under a field after it had been corrected.",
     "Wrote scripts/seed-test-accounts.ts as an idempotent seeder and verified it against the documented "
     "passwords. Added a listener per field controller so typing clears only that field\u2019s message. "
     "Regenerated the dump from the seeded database.",
     "A demo is a piece of engineering too: if the seed data is not reproducible, a correct system still "
     "looks broken in front of the examiner."),
]
for title, count, built, stuck, solved, learned in journal:
    h2(doc, title)
    body(doc, built, bold_lead="What I built. ")
    body(doc, stuck, bold_lead="Where I got stuck. ")
    body(doc, solved, bold_lead="How I solved it. ")
    body(doc, learned, bold_lead="What I learned about security. ")
    body(doc, f"{count} (proposal and design only)" if count == 0 else str(count),
         bold_lead="Commits this week: ")

h2(doc, "Reflection")
body(doc, "The hardest part was not any single feature but keeping the handout\u2019s page-based rules meaningful "
          "in a mobile app. Every rule that protects data \u2014 validation, lockout, OTP, idle timeout, "
          "authorisation \u2014 lives on the server; the app only mirrors the messages. That is why the system "
          "still behaves correctly when the client is modified.")
body(doc, "Repository: github.com/Jamester-Mulato/tahanan (public). The full commit log is the "
          "authoritative record of when each change was committed.", space_after=4)

page_break(doc)

# --------------------------------------------------------------------------- #
# 8. TEST ACCOUNTS
# --------------------------------------------------------------------------- #
h1(doc, "8. Test Accounts")
body(doc, "All three accounts deliver OTPs and alerts to jamestermulato@gmail.com through plus-addressing, "
          "so every code can be opened in a real inbox on demo day. The accounts are seeded directly into the "
          "database and are not created through registration.")

add_table(
    doc,
    ["Role", "Username", "Password", "Inbox", "Notes"],
    [
        ["Admin", "tahananadmin", "Admin#24100315", "jamestermulato+admin@gmail.com", "is_admin = true; created directly in the database"],
        ["User 1", "devicetest", "AppTest2026", "jamestermulato+device@gmail.com", "Owns a boarding house and rooms"],
        ["User 2", "hand2372", "Handout#2027", "jamestermulato+h2372@gmail.com", "ID Number 2027-2372; Government ID encrypted"],
    ],
    widths=[1.7, 3.1, 3.4, 5.3, 3.0],
    font_size=8,
)

h2(doc, "Security-question answers")
add_table(
    doc,
    ["Question", "Answer"],
    [
        ["Q6 \u2014 What was the first song you learned by heart?", "Bahay Kubo"],
        ["Q1 \u2014 What was the name of your first pet?", "Bantay"],
        ["Q3 \u2014 Who was your favorite teacher in high school?", "Mrs Cruz"],
    ],
    widths=[10.5, 6.0],
    font_size=9,
)

h2(doc, "Re-create or repair the demo accounts")
body(doc, "The seeder is idempotent: it verifies each documented password first and only rewrites a hash when "
          "it does not match, so it is safe to run immediately before the demo.")
p = doc.add_paragraph()
p.paragraph_format.left_indent = Cm(0.6)
r = p.add_run("cd backend\nnpx tsx scripts/seed-test-accounts.ts")
r.font.name = "Consolas"
r.font.size = Pt(9)

body(doc, "These are deliberate demo credentials for a school project. They are not used by any real deployment.", space_after=4)

h2(doc, "Run the system")
p = doc.add_paragraph()
p.paragraph_format.left_indent = Cm(0.6)
r = p.add_run(
    "# API (port 8080)\n"
    "cd backend && npm run dev\n\n"
    "# Flutter app in Chrome (web)\n"
    "flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080\n\n"
    "# Monitoring script\n"
    "cd backend && npx tsx scripts/monitor.ts"
)
r.font.name = "Consolas"
r.font.size = Pt(8.5)

page_break(doc)

# --------------------------------------------------------------------------- #
# 9. PRE-DEMO SELF-TEST
# --------------------------------------------------------------------------- #
h1(doc, "9. Pre-Demo Self-Test")
body(doc, "Taken from handout section 18. \u201cExpected\u201d is the answer the examiner wants; \u201cObserved\u201d is "
          "what the system actually did when the check was run.")

add_table(
    doc,
    ["#", "Check", "Expected", "Observed"],
    [
        ["1", "Database shows no readable password, answer, OTP or encrypted field", "No", "Pass \u2014 scrypt hashes and base64 ciphertext only"],
        ["2", "With JavaScript off, bad input is still rejected", "Yes", "Pass \u2014 server-side validation returns 422"],
        ["3", "After 3 failed log-ins, reload / clear cookies / re-enable the button do not get in", "No", "Pass \u2014 server lock returns 423"],
        ["4", "Alert e-mail arrives with time, IP and browser", "Yes", "Pass \u2014 sent at tier 1"],
        ["5", "Typing the user page URL at the OTP step does not open it", "No", "Pass \u2014 no token before OTP"],
        ["6", "Typing the Change Password URL directly does not open it", "No", "Pass \u2014 reset grant required"],
        ["7", "3 wrong OTPs, then the right one: the right one fails", "No", "Pass \u2014 code cancelled"],
        ["8", "Old code fails after the OTP expiry", "No", "Pass \u2014 5-minute expiry"],
        ["9", "' OR '1'='1 as username gives no SQL error and no log-in", "No", "Pass \u2014 identical error"],
        ["10", "<script>alert(1)</script> as a username shows no alert on the dashboard", "No", "Pass \u2014 rendered as text"],
        ["11", "Deleting the CSRF token or CAPTCHA and submitting is rejected", "No", "Pass \u2014 400/403"],
        ["12", "Wrong username and wrong password messages are identical", "Yes", "Pass"],
        ["13", "Changing the password to the current one is rejected", "No", "Pass \u2014 password history"],
        ["14", "Idle past the timeout logs the user out", "No", "Pass \u2014 401 SESSION_IDLE"],
        ["15", "A normal user typing the dashboard URL does not get in", "No", "Pass \u2014 403 + ADMIN_ACCESS_DENIED"],
        ["16", "The dashboard JSON endpoint returns no data when logged out", "No", "Pass \u2014 401"],
        ["17", "scripts/monitor.ts does not run from the browser", "No", "Pass \u2014 CLI only, 404"],
        ["18", "No button or code path edits or deletes a log row", "No", "Pass \u2014 trigger rejects UPDATE/DELETE"],
        ["19", "Git history contains no passwords or keys", "No", "Pass \u2014 .env ignored; sample values only"],
        ["20", "Lockout countdown matches the seeded seconds", "Yes", "Pass \u2014 16 / 32 / 64 s"],
    ],
    widths=[0.9, 7.6, 1.8, 6.2],
    font_size=8,
)

h2(doc, "Automated checks")
p = doc.add_paragraph()
p.paragraph_format.left_indent = Cm(0.6)
r = p.add_run(
    "PASS  admin dashboard rejects anonymous \u2014 401\n"
    "PASS  normal user gets 403 on admin dashboard\n"
    "PASS  ADMIN_ACCESS_DENIED written to activity log\n"
    "PASS  admin dashboard returns summary + events \u2014 50 events\n"
    "PASS  admin session carries isAdmin=true\n"
    "PASS  6-minute idle timeout returns 401 SESSION_IDLE\n"
    "PASS  authenticated request refreshes last_activity_at\n"
    "PASS  security headers X-Frame-Options + nosniff \u2014 DENY / nosniff\n"
    "PASS  foreign Origin rejected as CSRF_REJECTED \u2014 403"
)
r.font.name = "Consolas"
r.font.size = Pt(8)
p2 = doc.add_paragraph()
r2 = p2.add_run("Run: cd backend && npx tsx scripts/verify-handout.ts")
r2.italic = True
r2.font.size = Pt(8.5)

page_break(doc)

# --------------------------------------------------------------------------- #
# 10. DEMO RUNBOOK
# --------------------------------------------------------------------------- #
h1(doc, "10. Live Demo Runbook")
body(doc, "Six minutes, in the order the handout asks for. Keep only the running system, the code editor, "
          "the inbox and a terminal on screen.")

h2(doc, "Before the examiner arrives")
for text in [
    "Start PostgreSQL, the API (npm run dev) and the Flutter app (flutter run -d chrome).",
    "Run npx tsx scripts/seed-test-accounts.ts so the three accounts exist.",
    "Sign in to jamestermulato@gmail.com in a second window and leave it on the inbox.",
    "Open the terminal at backend/ with the monitor command typed but not yet run.",
    "Close every other tab, notes app and chat window.",
]:
    bullet(doc, " " + text)

h2(doc, "Part 1 \u2014 Run every flow (6 minutes)")
steps = [
    ("Register with one bad input first.", "Type \u201cju4n\u201d in First Name and point at the exact message "
     "\u201cNumbers are not allowed in First Name.\u201d Correct it, fill the system fields, tick the consent box, "
     "solve the CAPTCHA and submit."),
    ("Verify by OTP.", "Open the inbox, show the \u201cVerify your account\u201d e-mail with the 5-minute expiry and "
     "the \u201cIf you did not request this code\u2026\u201d line, enter the 6 digits."),
    ("Log in with OTP.", "Username and password, then the code. Point out that no session exists before the "
     "code is accepted."),
    ("Fail three times.", "Show the visible countdown (16 s), the disabled Log-in button and Register link, "
     "and the \u201cForgot Password? Reset Here\u201d link. Show the alert e-mail with time, IP and browser."),
    ("Forgot and Change Password.", "Username + CAPTCHA, the three seeded questions, the reset code, then "
     "the new password. Try the current password first to show the reuse refusal."),
    ("Run the monitoring script.", "npx tsx scripts/monitor.ts in the terminal; read the summary aloud."),
    ("Open the dashboard.", "Sign in as tahananadmin, open Security monitoring, show the summary cards, the "
     "24-hour chart, the top IPs, the flags and the 50-event table with filters. Show that there is no "
     "edit or delete control."),
]
for i, (title, text) in enumerate(steps, 1):
    body(doc, text, bold_lead=f"{i}. {title} ")

h2(doc, "Part 2 \u2014 Explain four code sections (6 minutes)")
body(doc, "Be ready to open these and explain them line by line in your own words:")
for text in [
    "backend/src/security/registration.ts \u2014 the name rules, the age check and the seeded lengths.",
    "backend/src/services/auth.service.ts \u2014 authenticatePassword, registerFailedAttempt and lockoutSeconds.",
    "backend/src/services/login-otp.service.ts \u2014 randomInt, hashed code, expiry, attempts, resend window.",
    "backend/src/security/crypto.ts \u2014 AES-256-GCM encrypt/decrypt and the HMAC lookup.",
    "backend/src/services/throttle.service.ts \u2014 the per-IP window and the persisted block.",
    "backend/src/routes/admin.routes.ts \u2014 requireAuth, is_admin check, summary queries.",
]:
    bullet(doc, " " + text)

h2(doc, "Part 3 \u2014 Build one unseen requirement (8 minutes)")
body(doc, "Keep the change small and end to end: a new validation rule, a new dashboard metric, a new log "
          "event, or an extra field with its message. The pattern to follow is always the same: add the rule "
          "on the server, mirror the message in the client, add a log event if the handout says so, then prove "
          "it with curl or the app. Explain what changed, where, and why it works.")

page_break(doc)

# --------------------------------------------------------------------------- #
# 11. SUBMISSION INVENTORY
# --------------------------------------------------------------------------- #
h1(doc, "11. Submission Inventory")
add_table(
    doc,
    ["Requirement", "Artefact", "Status"],
    [
        ["Documentation (.docx)", "This file", "Ready"],
        ["Git repository", "github.com/Jamester-Mulato/tahanan (public)", "Live"],
        ["SQL dump", "backend/sql/tahanan_dump.sql \u2014 all handout tables with test records", "Ready"],
        ["System Proposal (Appendix A)", "Section 2 of this document", "Needs the instructor\u2019s signature"],
        ["Seed table", "Page 1 and section 1", "Ready"],
        ["Threat Model (Appendix B)", "Section 3 \u2014 13 rows, one per protection", "Ready"],
        ["Design Decisions", "Section 4 \u2014 all 14 \u201cYour call\u201d items", "Ready"],
        ["Privacy Note (RA 10173)", "Section 5", "Ready"],
        ["Error Message Mapping", "Section 6 \u2014 core, system and auth flows", "Ready"],
        ["Development Journal (Appendix C)", "Section 7 \u2014 five weekly entries", "Ready"],
        ["Test accounts", "Section 8 \u2014 one admin and two users", "Seeded and verified"],
    ],
    widths=[4.8, 8.7, 3.0],
    font_size=8.5,
)

h2(doc, "What only the student can complete")
for text in [
    "Get Appendix A signed and dated at Checkpoint 1.",
    "Show the commit history honestly \u2014 it should reflect when the work was actually committed.",
    "Run the live demo in person and explain every feature without AI or notes.",
    "Build the unseen requirement on the spot.",
]:
    bullet(doc, " " + text)

OUT.parent.mkdir(parents=True, exist_ok=True)
doc.save(OUT)
print(f"wrote {OUT}")
print(f"total commits: {total_commits()}")
