# Security policy

## Reporting a vulnerability

Found a security issue? Don't open a public issue. Email security@gremlin.group with:

- A description of the vulnerability
- Steps to reproduce
- The action version you're using

We'll get back to you as soon as we can.

## Scope

This action runs in GitHub Actions and copies files between repos. The attack surface is:

- Token handling (a GitHub token is passed as input)
- Cross-repo file reads
- PR creation from template content (could contain malicious workflow changes if the template is compromised)
