# Security policy

Please report suspected malicious behavior, unsafe native-client interaction, unwanted data transmission, installer path traversal, or release tampering through a private GitHub security advisory when possible. Do not post account credentials, tokens, private server addresses, or personal information in a public issue.

Supported security fixes target the newest published release. The installer is intentionally offline and checks a complete SHA-256 payload manifest before staging and after installation. Release checksums are published with each GitHub release.

No software can guarantee compatibility with every future Emberveil build. If the client API changes, stop using the affected release and report the exact client build and `/qev` diagnostics.
