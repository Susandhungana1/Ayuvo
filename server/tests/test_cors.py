"""CORS origin-regex tests.

The frontend was renamed to medistore-health.vercel.app. The backend accepts its
own Vercel project's domains via a regex (in addition to the CORS_ORIGINS env
allowlist), so a rename/redeploy never silently breaks API calls — while still
rejecting arbitrary third-party origins.
"""

import re

from main import VERCEL_ORIGIN_REGEX

_pat = re.compile(VERCEL_ORIGIN_REGEX)


def test_regex_allows_this_projects_vercel_domains():
    assert _pat.match("https://medistore-health.vercel.app")
    assert _pat.match("https://front-medistore-app.vercel.app")
    assert _pat.match("https://front-five-woad-12.vercel.app")
    assert _pat.match("https://front-git-main-susan-dhunganas-projects.vercel.app")
    # The Share reader lives on its own Vercel project/app.
    assert _pat.match("https://medistore-share-beige.vercel.app")
    assert _pat.match("https://medistore-share.vercel.app")


def test_regex_rejects_foreign_and_malformed_origins():
    # A different project's Vercel app must NOT be allowed.
    assert not _pat.match("https://evil.vercel.app")
    assert not _pat.match("https://front-evil.vercel.app")
    assert not _pat.match("https://front-git-main-attacker-other-org.vercel.app")
    # Look-alike / suffix attacks.
    assert not _pat.match("https://medistore-health.vercel.app.evil.com")
    assert not _pat.match("https://medistore-share-beige.vercel.app.evil.com")
    assert not _pat.match("https://medistore-share-other.com")  # not vercel.app
    assert not _pat.match("http://medistore-health.vercel.app")  # not https
    assert not _pat.match("https://medistore-health.vercel.app/")  # trailing slash
